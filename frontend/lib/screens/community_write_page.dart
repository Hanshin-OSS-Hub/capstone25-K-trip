// 이 파일은 게시글 작성 페이지입니다.
// 등록 시 POST /posts로 서버에 저장합니다.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'community_page.dart';

// 플랫폼별 API Base URL (Android 에뮬: 10.0.2.2, iOS 시뮬: 127.0.0.1)
const String _kBoardBaseUrl = 'http://10.0.2.2:8000/board';

/// 로그인 연동 전 테스트용 임시 사용자 ID (1 또는 5 등으로 변경 가능. 추후 로그인 연동 시 교체)
const int _kTempUserId = 1;

/// API 실패/빈 응답 시 사용할 지역 목록 및 카테고리 목록(community_page와 동일 순서로 id 매핑)
const List<String> _kFallbackRegionNames = [
  '서울', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남',
  '부산', '대구', '대전', '울산', '광주', '제주',
];
const List<String> _kFallbackCategoryNames = ['날씨', '양도', '동행', '후기', 'Q&A'];

class CommunityWritePage extends StatefulWidget {
  const CommunityWritePage({super.key});

  @override
  State<CommunityWritePage> createState() => _CommunityWritePageState();
}

class _CommunityWritePageState extends State<CommunityWritePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  // 지역 선택 (작성 시에는 '전체' 제외) — API에서 오면 API 기준으로 채움, 없으면 기본값
  List<String> _writeRegions = ['서울', '부산', '제주'];
  List<String> _writeCategories = ['날씨', '양도', '동행', '후기', 'Q&A'];
  Map<String, int> _regionNameToId = {};
  Map<String, int> _categoryNameToId = {};
  bool _mapsLoaded = false;

  String _selectedRegion = '서울';
  String _selectedCategory = '후기';

  @override
  void initState() {
    super.initState();
    _loadRegionAndCategoryMaps();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// GET /regions, GET /categories로 이름→id 매핑 저장. 비었거나 실패 시 폴백 매핑 사용해 등록 오류 방지
  Future<void> _loadRegionAndCategoryMaps() async {
    final rNames = <String>[];
    final rnameToId = <String, int>{};
    final cnameToId = <String, int>{};
    int firstCategoryId = 1;

    try {
      final resRegions = await http.get(Uri.parse('$_kBoardBaseUrl/regions'));
      final resCategories = await http.get(Uri.parse('$_kBoardBaseUrl/categories'));
      if (!mounted) return;

      if (resRegions.statusCode == 200) {
        try {
          final data = jsonDecode(resRegions.body);
          final regionList = (data is Map ? (data['regions'] as List?) : null) ?? [];
          for (final r in regionList) {
            final id = (r as Map)['region_id'] as int?;
            final name = r['region_name'] as String? ?? '';
            if (id != null && name.isNotEmpty) {
              rnameToId[name] = id;
              rNames.add(name);
            }
          }
        } catch (_) {}
      }
      if (resCategories.statusCode == 200) {
        try {
          final data = jsonDecode(resCategories.body);
          final categoryList = (data is Map ? (data['categories'] as List?) : null) ?? [];
          for (final c in categoryList) {
            final id = (c as Map)['category_id'] as int?;
            final name = c['category_name'] as String? ?? '';
            if (id != null && name.isNotEmpty) {
              cnameToId[name] = id;
              if (firstCategoryId == 1) firstCategoryId = id;
            }
          }
        } catch (_) {}
      }

      // API에서 지역이 비었으면 폴백 목록으로 채워 등록 시 region_id 항상 존재하도록
      if (rNames.isEmpty) {
        rNames.addAll(_kFallbackRegionNames);
        for (var i = 0; i < _kFallbackRegionNames.length; i++) {
          rnameToId[_kFallbackRegionNames[i]] = i + 1;
        }
      }
      // 카테고리도 비었으면 폴백. '선택 안 함'은 서버에 없을 수 있으므로 firstCategoryId 또는 1 사용
      if (cnameToId.isEmpty) {
        for (var i = 0; i < _kFallbackCategoryNames.length; i++) {
          cnameToId[_kFallbackCategoryNames[i]] = i + 1;
        }
        firstCategoryId = 1;
      }
      cnameToId['선택 안 함'] = firstCategoryId;

      if (mounted) {
        setState(() {
          _regionNameToId = rnameToId;
          _categoryNameToId = cnameToId;
          _writeRegions = rNames.isNotEmpty ? rNames : _kFallbackRegionNames;
          _mapsLoaded = true;
          if (!_writeRegions.contains(_selectedRegion)) {
            _selectedRegion = _writeRegions.isNotEmpty ? _writeRegions.first : '서울';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        // 네트워크 오류 시 폴백 매핑으로 채워 "지역/카테고리 정보를 불러오지 못했습니다" 방지
        final rname = <String, int>{};
        final cname = <String, int>{};
        for (var i = 0; i < _kFallbackRegionNames.length; i++) {
          rname[_kFallbackRegionNames[i]] = i + 1;
        }
        for (var i = 0; i < _kFallbackCategoryNames.length; i++) {
          cname[_kFallbackCategoryNames[i]] = i + 1;
        }
        cname['선택 안 함'] = 1;
        setState(() {
          _regionNameToId = rname;
          _categoryNameToId = cname;
          _writeRegions = List.from(_kFallbackRegionNames);
          _mapsLoaded = true;
          if (!_writeRegions.contains(_selectedRegion)) {
            _selectedRegion = _writeRegions.isNotEmpty ? _writeRegions.first : '서울';
          }
        });
      }
    }
  }

  // 카테고리별 색상 반환 (화이트&블루 톤 통일)
  Color _getCategoryColor(String category) {
    switch (category) {
      case '날씨': return const Color(0xFF29B6F6);
      case '양도': return const Color(0xFF0288D1);
      case '동행': return const Color(0xFF0277BD);
      case '후기': return const Color(0xFF378ADD);
      case 'Q&A': return const Color(0xFF185FA5);
      default:     return const Color(0xFF29B6F6);
    }
  }

  InputDecoration _fieldDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[400], size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF29B6F6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '게시글 작성',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _submitPost,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('등록', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(hint: '제목을 입력하세요', icon: Icons.title),
            ),
            const SizedBox(height: 20),

            // 제목 아래 구분선
            const SizedBox(height: 4),
            // 지역 선택
            const Text('지역',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: _mapsLoaded
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _writeRegions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final region = _writeRegions[i];
                        final isSelected = _selectedRegion == region;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRegion = region),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(region,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                )),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF29B6F6)),
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // 카테고리
            const Text('카테고리',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _writeCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final color = _getCategoryColor(category);
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 본문
            const Text('내용',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: _fieldDecoration(hint: '내용을 입력하세요').copyWith(
                contentPadding: const EdgeInsets.all(16),
                alignLabelWithHint: true,
              ),
              maxLines: 12,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // === 게시글 등록 (POST /posts 호출) ===
  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본문을 입력해주세요.')),
      );
      return;
    }

    final regionId = _regionNameToId[_selectedRegion];
    final categoryId = _categoryNameToId[_selectedCategory];
    if (regionId == null || categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지역/카테고리 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    try {
      final body = jsonEncode({
        'user_id': _kTempUserId,
        'region_id': regionId,
        'category_id': categoryId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'is_public': true,
      });
      final res = await http.post(
        Uri.parse('$_kBoardBaseUrl/posts'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map;
        final postId = (data['post_id'] ?? data['id']) as int? ?? 0;
        final newPost = Post(
          id: postId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          region: _selectedRegion,
          category: _selectedCategory,
          author: 'User$_kTempUserId',
          createdAt: DateTime.now(),
          comments: [],
        );
        Navigator.pop(context, newPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 중 오류가 발생했습니다. $e')),
        );
      }
    }
  }
}



