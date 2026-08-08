import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// Context handed to the coach so its answers reference the user's actual day.
///
/// Every field is optional: a guest with an empty profile still gets a useful
/// coach, just a more generic one.
class CoachContext {
  final String? name;
  final int? todayKcal;
  final int? targetKcal;
  final int? toBurn;
  final int? streakDays;
  final String? activeProgram;

  const CoachContext({
    this.name,
    this.todayKcal,
    this.targetKcal,
    this.toBurn,
    this.streakDays,
    this.activeProgram,
  });

  Map<String, dynamic> toJson() => {
    if (name != null && name!.isNotEmpty) 'name': name,
    if (todayKcal != null) 'todayKcal': todayKcal,
    if (targetKcal != null) 'targetKcal': targetKcal,
    if (toBurn != null) 'toBurn': toBurn,
    if (streakDays != null) 'streakDays': streakDays,
    if (activeProgram != null) 'activeProgram': activeProgram,
  };
}

/// Talks to the coach endpoint on the FitPilot proxy.
///
/// Mirrors [AiFoodService]'s transport exactly: same base url, the same
/// cold-start warm-up (Render's free tier sleeps), the same timeout and the
/// same error mapping. The Gemini key lives only on the server.
class CoachService {
  final http.Client Function() _clientFactory;

  CoachService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? (() => http.Client());

  static const _networkError =
      'Could not reach the coach. Check your internet - or the free server may still be waking up; try again in a minute.';

  String get _baseUrl {
    if (!Env.hasProxy) {
      throw Exception('Server not configured: PROXY_URL missing from env.json');
    }
    return Env.proxyUrl;
  }

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

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// Sends [history] (oldest first, including the new user message) and returns
  /// the coach's reply.
  ///
  /// Throws an [Exception] carrying a user-ready message on failure.
  Future<String> send({
    required List<ChatMessage> history,
    CoachContext? context,
  }) async {
    final client = _clientFactory();
    try {
      final deviceId = await _deviceId();

      // A sleeping server would otherwise burn the whole timeout on the first
      // message of a session.
      var isWarm = await warmUp();
      if (!isWarm) {
        for (var i = 0; i < 12; i++) {
          await Future.delayed(const Duration(seconds: 5));
          if (await warmUp()) {
            isWarm = true;
            break;
          }
        }
      }

      final response = await client
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
            body: jsonEncode({
              'messages': [
                for (final m in history)
                  {'role': m.role.name, 'text': m.content},
              ],
              if (context != null) 'context': context.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final reply = decoded['reply'];
          if (reply is String && reply.trim().isNotEmpty) return reply.trim();
        }
        throw Exception('The coach sent an empty reply. Try again.');
      }

      if (response.statusCode == 429 || response.statusCode == 503) {
        throw Exception(
          _serverMessage(response.body, 'The coach is unavailable right now.'),
        );
      }

      if (kDebugMode) {
        debugPrint('Coach error: ${response.statusCode} - ${response.body}');
      }
      throw Exception(
        _serverMessage(response.body, "The coach couldn't answer. Try again."),
      );
    } on TimeoutException {
      throw Exception(_networkError);
    } on SocketException {
      throw Exception(_networkError);
    } on http.ClientException {
      throw Exception(_networkError);
    } finally {
      client.close();
    }
  }

  /// Unwraps `{"error": "..."}` and `{"error": {"message": "..."}}` so a
  /// server-authored message reaches the user instead of raw JSON.
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
      }
    } catch (_) {
      // Not JSON — fall through.
    }
    return fallback;
  }
}
