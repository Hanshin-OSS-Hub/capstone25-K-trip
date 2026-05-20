import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ItineraryApi {

  // AI 일정 생성
  static Future<Map<String, dynamic>> generatePlan({
    required String region,
    required String startDate,
    required String endDate,
    required String companion,
    required List<String> themes,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/travel/plan');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'region': region,
        'start_date': startDate,
        'end_date': endDate,
        'companion': companion,
        'themes': themes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('일정 생성 실패: ${response.statusCode}');
    }
  }

  // 숙박 추천
  static Future<Map<String, dynamic>> getAccommodations({
    required String region,
    required String startDate,
    required String endDate,
    required String companion,
    required List<String> themes,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/travel/accommodations');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'region': region,
        'start_date': startDate,
        'end_date': endDate,
        'companion': companion,
        'themes': themes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('숙박 추천 조회 실패: ${response.statusCode}');
    }
  }
}