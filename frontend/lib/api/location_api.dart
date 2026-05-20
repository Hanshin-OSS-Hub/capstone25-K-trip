import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class LocationApi {

  // 관광지 목록
  static Future<Map<String, dynamic>> getLocations({
    int page = 1,
    int limit = 20,
    String language = 'en',
    int? categoryId,
    String? keyword,
    String? city,
  }) async {
    final params = {
      'page': '$page',
      'limit': '$limit',
      'language': language,
      if (categoryId != null) 'category_id': '$categoryId',
      if (keyword != null) 'keyword': keyword,
      if (city != null) 'city': city,
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/location/locations')
        .replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('관광지 목록 조회 실패: ${response.statusCode}');
    }
  }

  // 관광지 상세
  static Future<Map<String, dynamic>> getLocationDetail(int locationId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/location/locations/$locationId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('관광지 상세 조회 실패: ${response.statusCode}');
    }
  }

  // 카테고리 목록
  static Future<List<dynamic>> getCategories({String language = 'en'}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/location/location-categories')
        .replace(queryParameters: {'language': language});
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('카테고리 조회 실패: ${response.statusCode}');
    }
  }
}