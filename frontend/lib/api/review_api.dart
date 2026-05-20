import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ReviewApi {
  static Future<List<dynamic>> getReviewsByUser(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/users/$userId/reviews");
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final data = jsonDecode(res.body);
    return data["reviews"] as List<dynamic>;
  }

  static Future<void> createReview({
    required int userId,
    required int locationId,
    required int rating,
    String? title,
    String? comment,
    String? visitDate,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/reviews");
    final body = jsonEncode({
      "user_id": userId,
      "location_id": locationId,
      "rating": rating,
      "review_title": title,
      "review_comment": comment,
      "visit_date": visitDate,
    });

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }
  }

  static Future<void> likeReview({
    required int reviewId,
    required int userId,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/reviews/$reviewId/like?user_id=$userId");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }
  }

  static Future<void> unlikeReview({
    required int reviewId,
    required int userId,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/reviews/$reviewId/like?user_id=$userId");
    final res = await http.delete(
      url,
      headers: {"Content-Type": "application/json"},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }
  }
}
