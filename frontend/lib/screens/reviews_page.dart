import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../api/review_api.dart';
import 'review_write_page.dart';


class Place {
  final String id;
  final String name;

  Place({
    required this.id,
    required this.name,
  });
}

class Review {
  final String id;
  final String placeId;
  final String placeName;
  final String region;
  final int rating;
  final String content;
  final String author;
  final DateTime createdAt;
  final XFile? image;
  final int likeCount;
  final int dislikeCount;
  final int userVote;

  Review({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.region,
    required this.rating,
    required this.content,
    required this.author,
    required this.createdAt,
    this.image,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.userVote = 0,
  });

  Review copyWith({
    String? id,
    String? placeId,
    String? placeName,
    String? region,
    int? rating,
    String? content,
    String? author,
    DateTime? createdAt,
    XFile? image,
    int? likeCount,
    int? dislikeCount,
    int? userVote,
  }) {
    return Review(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      region: region ?? this.region,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      image: image ?? this.image,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      userVote: userVote ?? this.userVote,
    );
  }
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final ImagePicker _picker = ImagePicker();
  static const int _currentUserId = 1;
  static const int _defaultLocationId = 1;
  bool _isLoading = false;
  String? _loadError;

  // 선택 가능한 지역 목록
  static const List<String> _availableRegions = [
    '전체',
    '서울',
    '부산',
    '제주',
    '경기',
    '인천',
    '강원',
    '경주',
    '대구',
    '대전',
    '광주',
    '울산',
    '전북',
    '전남',
    '경북',
    '경남',
    '충북',
    '충남',
  ];

  String? _selectedRegion;
  String? _selectedTheme;
  String? _selectedSubRegion;

  final TextEditingController _searchController = TextEditingController();

  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviewsFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewsFromApi() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final rawReviews = await ReviewApi.getAllReviews();
      final parsed = rawReviews
          .whereType<Map>()
          .map((item) => _reviewFromApi(Map<String, dynamic>.from(item)))
          .toList();

      setState(() {
        _reviews = parsed;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Review _reviewFromApi(Map<String, dynamic> data) {
      String readAny(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = data[key];
        if (value != null) {
          final s = value.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return fallback;
    }

    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = data[key];
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    final createdAtRaw = readAny(['created_at', 'createdAt'], fallback: '');
    final parsedDate = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    final userId = readInt(['user_id', 'userId'], fallback: 0);

    return Review(
      id: readAny(['review_id', 'id'], fallback: DateTime.now().millisecondsSinceEpoch.toString()),
      placeId: readAny(['location_id', 'place_id', 'placeId'], fallback: 'unknown'),
      placeName: readAny(['review_title', 'place_name', 'placeName', 'spot_name'], fallback: '리뷰'),
      region: readAny(['region', 'area'], fallback: '전체'),
      rating: readInt(['rating', 'score'], fallback: 5),
      content: readAny(['review_comment', 'content', 'review'], fallback: ''),
      author: userId > 0 ? 'User$userId' : readAny(['author', 'user_name', 'nickname'], fallback: 'Unknown'),
      createdAt: parsedDate,
      likeCount: readInt(['total_likes', 'like_count', 'likes'], fallback: 0),
      dislikeCount: readInt(['dislike_count', 'dislikes'], fallback: 0),
      userVote: readInt(['user_vote', 'userVote', 'vote'], fallback: 0),
      image: null,
    );
  }

  List<Review> get _filteredReviews {
    final searchQuery = _searchController.text.trim().toLowerCase();

    if (searchQuery.isNotEmpty) {
      return _reviews.where((r) {
        return r.placeName.toLowerCase().contains(searchQuery) ||
            r.content.toLowerCase().contains(searchQuery) ||
            r.region.toLowerCase().contains(searchQuery);
      }).toList();
    }

    if (_selectedTheme != null) {
      final themeRegions = _themeInfo(_selectedTheme!)['regions'] as List<String>;
      if (_selectedSubRegion != null) {
        return _reviews.where((r) => r.region == _selectedSubRegion).toList();
      } else {
        return _reviews.where((r) => themeRegions.contains(r.region)).toList();
      }
    }

    return _reviews;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSection(),
            _buildReviewList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReviewWritePage()),
          );
          if (result == true) _loadReviewsFromApi();
        },
        backgroundColor: const Color(0xFF29B6F6),
        foregroundColor: Colors.white,
        elevation: 2,
        tooltip: '리뷰 작성',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  // === 상단 섹션 ===
  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSearchBar(),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            '어떤 여행을 찾고 있어요?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888888),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildThemeGrid(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSubRegionSection(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // === 테마 카드 2열 그리드 ===
  Widget _buildThemeGrid() {
    const themes = ['자연·힐링', '도심·쇼핑', '역사·문화', '바다·해변'];
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildThemeCard(themes[0])),
          const SizedBox(width: 8),
          Expanded(child: _buildThemeCard(themes[1])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildThemeCard(themes[2])),
          const SizedBox(width: 8),
          Expanded(child: _buildThemeCard(themes[3])),
        ]),
      ],
    );
  }

  // === 개별 테마 카드 ===
  Widget _buildThemeCard(String theme) {
    final info = _themeInfo(theme);
    final isSelected = _selectedTheme == theme;
    final reviewCount = _reviews
        .where((r) => (info['regions'] as List<String>).contains(r.region))
        .length;

    return GestureDetector(
      onTap: () => setState(() {
        if (_selectedTheme == theme) {
          _selectedTheme = null;
          _selectedSubRegion = null;
        } else {
          _selectedTheme = theme;
          _selectedSubRegion = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: isSelected ? info['cardSelBg'] as Color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF378ADD) : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFB5D4F4) : info['iconBg'] as Color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  info['icon'] as IconData,
                  color: info['iconColor'] as Color,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              theme,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF0C447C) : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (info['regions'] as List<String>).join(', '),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF185FA5) : const Color(0xFF888888),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Text(
                '리뷰 $reviewCount개',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF378ADD),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === 세부 지역 칩 섹션 (테마 선택 시 펼쳐짐) ===
  Widget _buildSubRegionSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: _selectedTheme == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '세부 지역 선택 (선택 안 하면 전체)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildSubChip('전체'),
                      ...(_themeInfo(_selectedTheme!)['regions'] as List<String>)
                          .map((r) => _buildSubChip(r)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // === 세부 지역 개별 칩 ===
  Widget _buildSubChip(String region) {
    final isSelected =
        region == '전체' ? _selectedSubRegion == null : _selectedSubRegion == region;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSubRegion = region == '전체' ? null : region;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF378ADD) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? const Color(0xFF378ADD) : const Color(0xFFD0D0D0),
            width: 1.5,
          ),
        ),
        child: Text(
          region,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF888888),
          ),
        ),
      ),
    );
  }

  // === 검색어가 지역명이면 해당 테마+칩 자동 선택 ===
  void _tryAutoSelectRegion(String query) {
    if (query.isEmpty) return;
    const themeRegions = {
      '자연·힐링': ['강원', '제주', '전남', '경남'],
      '도심·쇼핑': ['서울', '부산', '대구', '인천'],
      '역사·문화': ['경주', '경북', '전북', '충남'],
      '바다·해변': ['부산', '제주', '강원', '전남'],
    };
    for (final entry in themeRegions.entries) {
      for (final region in entry.value) {
        if (region == query || region.contains(query) && query.length >= 2) {
          if (_selectedTheme != entry.key || _selectedSubRegion != region) {
            _selectedTheme = entry.key;
            _selectedSubRegion = region;
          }
          return;
        }
      }
    }
  }

  // === 테마별 설정 정보 ===
  Map<String, dynamic> _themeInfo(String theme) {
    switch (theme) {
      case '자연·힐링':
        return {
          'icon': Icons.forest,
          'regions': const ['강원', '제주', '전남', '경남'],
          'iconBg': const Color(0xFFC0DD97),
          'iconColor': const Color(0xFF27500A),
          'cardSelBg': const Color(0xFFEAF3DE),
          'badgeBg': const Color(0xFFC0DD97),
          'badgeColor': const Color(0xFF27500A),
        };
      case '도심·쇼핑':
        return {
          'icon': Icons.location_city,
          'regions': const ['서울', '부산', '대구', '인천'],
          'iconBg': const Color(0xFFE6F1FB),
          'iconColor': const Color(0xFF185FA5),
          'cardSelBg': const Color(0xFFE6F1FB),
          'badgeBg': const Color(0xFFB5D4F4),
          'badgeColor': const Color(0xFF0C447C),
        };
      case '역사·문화':
        return {
          'icon': Icons.account_balance,
          'regions': const ['경주', '경북', '전북', '충남'],
          'iconBg': const Color(0xFFFAEEDA),
          'iconColor': const Color(0xFF633806),
          'cardSelBg': const Color(0xFFFFF8EE),
          'badgeBg': const Color(0xFFFAC775),
          'badgeColor': const Color(0xFF633806),
        };
      case '바다·해변':
        return {
          'icon': Icons.waves,
          'regions': const ['부산', '제주', '강원', '전남'],
          'iconBg': const Color(0xFFE1F5EE),
          'iconColor': const Color(0xFF085041),
          'cardSelBg': const Color(0xFFECFBF5),
          'badgeBg': const Color(0xFF9FE1CB),
          'badgeColor': const Color(0xFF085041),
        };
      default:
        return {
          'icon': Icons.place,
          'regions': const <String>[],
          'iconBg': const Color(0xFFEEEEEE),
          'iconColor': const Color(0xFF888888),
          'cardSelBg': const Color(0xFFEEEEEE),
          'badgeBg': const Color(0xFFE3F6FD),
          'badgeColor': const Color(0xFF0288D1),
        };
    }
  }


  // === 검색 입력 필드 ===
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '장소명 또는 내용 검색',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                  onPressed: () => setState(() => _searchController.clear()),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF29B6F6), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          final trimmed = value.trim();
          _tryAutoSelectRegion(trimmed);
          setState(() {});
        },
      ),
    );
  }

  // === 리뷰 목록 ===
  Widget _buildReviewList() {
    final filteredReviews = _filteredReviews;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '리뷰 ${filteredReviews.length}개',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF29B6F6)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.tune, size: 13, color: Color(0xFF378ADD)),
                    const SizedBox(width: 3),
                    const Text(
                      '최신순',
                      style: TextStyle(fontSize: 12, color: Color(0xFF378ADD)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (filteredReviews.isEmpty)
            Container(
              height: 160,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    _selectedRegion == null && _searchController.text.isEmpty
                        ? '아직 리뷰가 없어요\n첫 리뷰를 남겨보세요!'
                        : '검색 결과가 없어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400], height: 1.6),
                  ),
                ],
              ),
            )
          else
            ...filteredReviews.asMap().entries.map((entry) {
              final review = entry.value;
              final originalIndex = _reviews.indexWhere((r) => r.id == review.id);
              return _buildReviewCard(review, originalIndex >= 0 ? originalIndex : entry.key);
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === 리뷰 카드 ===
  Widget _buildReviewCard(Review review, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.image != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.file(
                File(review.image!.path),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 테마/지역 뱃지
                    Builder(builder: (_) {
                      final badgeText = _selectedTheme ?? review.region;
                      final info = _selectedTheme != null
                          ? _themeInfo(_selectedTheme!)
                          : _themeInfo('');
                      final badgeBg = _selectedTheme != null
                          ? info['badgeBg'] as Color
                          : const Color(0xFFE3F6FD);
                      final badgeColor = _selectedTheme != null
                          ? info['badgeColor'] as Color
                          : const Color(0xFF0288D1);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.placeName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 별점
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 18,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  review.content,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(review.author,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    Text('  ·  ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    Text(_formatDate(review.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    Text('  ·  ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    Text(review.region,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF378ADD))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildVoteButton(
                        icon: Icons.thumb_up_outlined,
                        label: '추천',
                        count: review.likeCount,
                        isSelected: review.userVote == 1,
                        onTap: () => _toggleLike(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildVoteButton(
                        icon: Icons.thumb_down_outlined,
                        label: '비추천',
                        count: review.dislikeCount,
                        isSelected: review.userVote == -1,
                        onTap: () => _toggleDislike(index),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === 추천/비추천 버튼 위젯 ===
  Widget _buildVoteButton({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 추천 버튼 토글 처리 ===
  Future<void> _toggleLike(int reviewIndex) async {
    final review = _reviews[reviewIndex];
    int newLikeCount = review.likeCount;
    int newDislikeCount = review.dislikeCount;
    int newUserVote = review.userVote;

    if (review.userVote == 0) {
      newLikeCount = review.likeCount + 1;
      newUserVote = 1;
    } else if (review.userVote == 1) {
      newLikeCount = (review.likeCount - 1).clamp(0, double.infinity).toInt();
      newUserVote = 0;
    } else if (review.userVote == -1) {
      newDislikeCount = (review.dislikeCount - 1).clamp(0, double.infinity).toInt();
      newLikeCount = review.likeCount + 1;
      newUserVote = 1;
    }

    // 먼저 UI 반영 (낙관적 업데이트)
    setState(() {
      _reviews[reviewIndex] = review.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        userVote: newUserVote,
      );
    });

    // 서버 동기화 (실패해도 UI는 유지)
    final reviewId = int.tryParse(review.id);
    if (reviewId != null) {
      try {
        if (newUserVote == 1) {
          await ReviewApi.likeReview(reviewId: reviewId, userId: _currentUserId);
        } else if (newUserVote == 0 && review.userVote == 1) {
          await ReviewApi.unlikeReview(reviewId: reviewId, userId: _currentUserId);
        }
      } catch (_) {
        // 서버 오류는 무시 — UI 상태는 유지
      }
    }
  }

  // === 비추천 버튼 토글 처리 (로컬 전용) ===
  void _toggleDislike(int reviewIndex) {
    final review = _reviews[reviewIndex];
    int newLikeCount = review.likeCount;
    int newDislikeCount = review.dislikeCount;
    int newUserVote = review.userVote;

    if (review.userVote == 0) {
      newDislikeCount = review.dislikeCount + 1;
      newUserVote = -1;
    } else if (review.userVote == -1) {
      newDislikeCount = (review.dislikeCount - 1).clamp(0, double.infinity).toInt();
      newUserVote = 0;
    } else if (review.userVote == 1) {
      newLikeCount = (review.likeCount - 1).clamp(0, double.infinity).toInt();
      newDislikeCount = review.dislikeCount + 1;
      newUserVote = -1;
    }

    setState(() {
      _reviews[reviewIndex] = review.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        userVote: newUserVote,
      );
    });
  }

  // === 날짜 포맷팅 ===
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

}
