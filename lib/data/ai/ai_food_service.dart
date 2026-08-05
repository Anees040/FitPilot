import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/core/config/env.dart';

class AiFoodService {
  String get _baseUrl {
    if (!Env.hasProxy) {
      throw Exception('Server not configured: PROXY_URL missing from env.json');
    }
    return Env.proxyUrl;
  }

  Future<bool> warmUp() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/health')).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> estimateFood(String base64Image, {void Function(String)? onPhase}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }

      onPhase?.call('waking');
      bool isWarm = await warmUp();
      if (!isWarm) {
        // Poll every 5s up to 75s
        for (int i = 0; i < 15; i++) {
          await Future.delayed(const Duration(seconds: 5));
          if (await warmUp()) {
            isWarm = true;
            break;
          }
        }
      }
      
      onPhase?.call('analyzing');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/estimate-food'),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Id': deviceId,
        },
        body: jsonEncode({
          'image': base64Image,
          'mimeType': 'image/jpeg',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        try {
          final body = jsonDecode(response.body);
          final msg = body['error']?['message'] ?? body['message'] ?? 'Daily limit reached.';
          throw Exception(msg);
        } catch (_) {
          throw Exception(response.body);
        }
      } else {
        debugPrint('AI Service Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException {
      throw Exception("Could not reach the server. Check your internet - or the free server may still be waking up; try again in a minute.");
    } on SocketException {
      throw Exception("Could not reach the server. Check your internet - or the free server may still be waking up; try again in a minute.");
    } on http.ClientException {
      throw Exception("Could not reach the server. Check your internet - or the free server may still be waking up; try again in a minute.");
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      debugPrint('AI Service Exception: $e');
      return null;
    }
  }
}
