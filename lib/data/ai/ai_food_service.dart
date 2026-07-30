import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiFoodService {
  // Use localhost for Android emulator (10.0.2.2) or normal localhost
  // Note: if you are running on real device via USB, you may need the IP of the machine.
  // For web, localhost works if the browser runs on the same machine.
  static const String _baseUrl = 'http://127.0.0.1:3000';

  Future<Map<String, dynamic>?> estimateFood(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/estimate-food'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'mimeType': 'image/jpeg',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('AI Service Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AI Service Exception: $e');
      return null;
    }
  }
}
