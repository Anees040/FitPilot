import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// Calls the FitPilot proxy to identify a gym machine from a photo.
///
/// Deliberately mirrors [AiFoodService]: same proxy base url, the same
/// cold-start warm-up poll (Render's free tier sleeps), the same 60 s request
/// timeout, the same `X-Device-Id` quota header and the same error mapping.
/// The Gemini key lives only on the server — never in this app.
class MachineAiService {
  /// Injectable so tests can drive the service without a real socket.
  final http.Client Function() _clientFactory;

  MachineAiService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? (() => http.Client());

  static const _networkError =
      'Could not reach the server. Check your internet - or the free server may still be waking up; try again in a minute.';

  String get _baseUrl {
    if (!Env.hasProxy) {
      throw Exception('Server not configured: PROXY_URL missing from env.json');
    }
    return Env.proxyUrl;
  }

  /// Pings /api/health. Returns false instead of throwing so the caller can
  /// decide whether to keep waiting on a sleeping server.
  Future<bool> warmUp() async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Stable per-install id used for the server's daily quota.
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// Identifies the machine in [base64Image].
  ///
  /// [onPhase] reports `waking` then `analyzing` so the overlay can explain a
  /// cold start. Returns null when the server answered but the body was not
  /// usable; throws an [Exception] carrying a user-ready message otherwise.
  Future<MachineAnalysis?> analyzeMachine(
    String base64Image, {
    String mimeType = 'image/jpeg',
    void Function(String)? onPhase,
  }) async {
    final client = _clientFactory();
    try {
      final deviceId = await _deviceId();

      onPhase?.call('waking');
      var isWarm = await warmUp();
      if (!isWarm) {
        // Render free tier: cold boot can take the better part of a minute.
        for (var i = 0; i < 15; i++) {
          await Future.delayed(const Duration(seconds: 5));
          if (await warmUp()) {
            isWarm = true;
            break;
          }
        }
      }

      onPhase?.call('analyzing');
      final response = await client
          .post(
            Uri.parse('$_baseUrl/api/analyze-machine'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
            body: jsonEncode({
              'imageBase64': base64Image,
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return null;
        return MachineAnalysis.fromJson(decoded);
      }

      if (response.statusCode == 429) {
        throw Exception(_serverMessage(response.body, 'Daily limit reached.'));
      }

      if (response.statusCode == 503) {
        throw Exception(
          _serverMessage(response.body, 'The scanner is not available right now.'),
        );
      }

      if (kDebugMode) {
        debugPrint('Machine AI error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } on TimeoutException {
      throw Exception(_networkError);
    } on SocketException {
      throw Exception(_networkError);
    } on http.ClientException {
      throw Exception(_networkError);
    } catch (e) {
      if (e is Exception) rethrow;
      if (kDebugMode) debugPrint('Machine AI exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Pulls the human-readable message out of an error body.
  ///
  /// The proxy answers `{"error": "..."}` but may also nest it as
  /// `{"error": {"message": "..."}}`, so both shapes are unwrapped instead of
  /// leaking raw JSON into a snackbar.
  String _serverMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) return error.trim();
        if (error is Map) {
          final nested = error['message'];
          if (nested is String && nested.trim().isNotEmpty) return nested.trim();
        }
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) return message.trim();
      }
    } catch (_) {
      // Not JSON — fall through to the caller's default.
    }
    return fallback;
  }
}
