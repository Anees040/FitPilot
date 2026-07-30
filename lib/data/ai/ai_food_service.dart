import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AiFoodService {
  static const String _baseUrl = String.fromEnvironment('PROXY_URL', defaultValue: 'http://127.0.0.1:3000');

  Future<Map<String, dynamic>?> estimateFood(String base64Image) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }

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
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        throw Exception('Daily photo limit reached (3/day)');
      } else {
        debugPrint('AI Service Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on SocketException {
      throw Exception("Couldn't reach the server");
    } on http.ClientException {
      throw Exception("Couldn't reach the server");
    } catch (e) {
      if (e is Exception && (e.toString().contains('Daily photo limit') || e.toString().contains("Couldn't reach"))) {
        rethrow;
      }
      debugPrint('AI Service Exception: $e');
      return null;
    }
  }
}
