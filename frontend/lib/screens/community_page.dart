import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'community_detail_page.dart';
import 'community_write_page.dart';

const String _kBoardBaseUrl = 'http://10.0.2.2:8000/board';

const List<String> _kFallbackRegionNames = [
  '서울', '부산', '제주', '경기', '인천', '강원', '경주',
  '대구', '대전', '광주', '울산', '전북', '전남', '경북', '경남', '충북', '충남',
];
const List<String> _kFallbackCategoryNames = ['날씨', '양도', '동행', '후기', 'Q&A'];

class Post {
  final int id;
  final String title;
  final String content;
  final String region;
  final String category;
  final String author;
  final DateTime createdAt;
  final List<Comment> comments;
  final int? commentCount;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.region,
    required this.category,
    required this.author,
    required this.createdAt,
    List<Comment>? comments,
    this.commentCount,
  }) : comments = comments ?? [];
}

class Comment {
  final String author;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.author,
    required this.content,
    required this.createdAt,
  });
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  // API에서 불러온 지역/카테고리 목록 (캐싱)
  List<String> _availableRegions = ['전체'];
  List<String> _filterCategories = ['전체'];
  Map<int, String> _regionIdToName = {};
  Map<int, String> _categoryIdToName = {};
  Map<String, int> _regionNameToId = {};
  Map<String, int> _categoryNameToId = {};

  // API에서 불러온 게시글 목록 (필터/검색은 서버 쿼리로 적용)
  List<Post> _allPosts = [];
  bool _isLoading = true;
  String? _loadError;

  // 필터 상태
  String _selectedRegion = '전체';
  String _selectedCategory = '전체';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegionsAndCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 지역·카테고리 목록을 API(GET /regions, GET /categories)에서 불러와 매핑 캐싱. 비었거나 실패 시 폴백 목록 사용.
  Future<void> _loadRegionsAndCategories() async {
    List<String> regionNames = ['전체'];
    List<String> categoryNames = ['전체'];
    final ridToName = <int, String>{};
    final cidToName = <int, String>{};
    final rnameToId = <String, int>{};
    final cnameToId = <String, int>{};

    try {
      final resRegions = await http.get(Uri.parse('$_kBoardBaseUrl/regions'));
      final resCategories = await http.get(Uri.parse('$_kBoardBaseUrl/categories'));
      if (!mounted) return;

      // API 응답이 200이고 body가 예상 구조일 때만 파싱
      if (resRegions.statusCode == 200) {
        try {
          final data = jsonDecode(resRegions.body);
          final regionList = (data is Map ? (data['regions'] as List?) : null) ?? [];
          for (final r in regionList) {
            final id = (r as Map)['region_id'] as int?;
            final name = r['region_name'] as String? ?? '';
            if (id != null && name.isNotEmpty) {
              ridToName[id] = name;
              rnameToId[name] = id;
              regionNames.add(name);
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
              cidToName[id] = name;
              cnameToId[name] = id;
              categoryNames.add(name);
            }
          }
        } catch (_) {}
      }

      // API에서 항목이 하나도 없으면 폴백 목록으로 채워 드롭다운이 항상 선택지 표시되도록 함
      if (regionNames.length <= 1) {
        for (var i = 0; i < _kFallbackRegionNames.length; i++) {
          final name = _kFallbackRegionNames[i];
          final id = i + 1;
          ridToName[id] = name;
          rnameToId[name] = id;
          regionNames.add(name);
        }
      }
      if (categoryNames.length <= 1) {
        for (var i = 0; i < _kFallbackCategoryNames.length; i++) {
          final name = _kFallbackCategoryNames[i];
          final id = i + 1;
          cidToName[id] = name;
          cnameToId[name] = id;
          categoryNames.add(name);
        }
      }

      if (mounted) {
        setState(() {
          _regionIdToName = ridToName;
          _categoryIdToName = cidToName;
          _regionNameToId = rnameToId;
          _categoryNameToId = cnameToId;
          _availableRegions = regionNames;
          _filterCategories = categoryNames;
        });
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        // 네트워크/파싱 오류 시에도 폴백으로 목록 채워서 화면은 사용 가능하게
        final fallbackRegions = <String>['전체', ..._kFallbackRegionNames];
        final fallbackCategories = <String>['전체', ..._kFallbackCategoryNames];
        final rid = <int, String>{};
        final cid = <int, String>{};
        final rname = <String, int>{};
        final cname = <String, int>{};
        for (var i = 0; i < _kFallbackRegionNames.length; i++) {
          final name = _kFallbackRegionNames[i];
          final id = i + 1;
          rid[id] = name;
          rname[name] = id;
        }
        for (var i = 0; i < _kFallbackCategoryNames.length; i++) {
          final name = _kFallbackCategoryNames[i];
          final id = i + 1;
          cid[id] = name;
          cname[name] = id;
        }
        setState(() {
          _regionIdToName = rid;
          _categoryIdToName = cid;
          _regionNameToId = rname;
          _categoryNameToId = cname;
          _availableRegions = fallbackRegions;
          _filterCategories = fallbackCategories;
          _loadError = null;
        });
        _loadPosts();
      }
    }
  }

  /// 게시글 목록을 서버 쿼리(필터/검색/정렬)로 요청
  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final query = <String, String>{
        'page': '1',
        'limit': '20',
        'sort_by': 'latest',
      };
      if (_selectedRegion != '전체') {
        final id = _regionNameToId[_selectedRegion];
        if (id != null) query['region_id'] = id.toString();
      }
      if (_selectedCategory != '전체') {
        final id = _categoryNameToId[_selectedCategory];
        if (id != null) query['category_id'] = id.toString();
      }
      final search = _searchController.text.trim();
      if (search.isNotEmpty) query['search'] = search;

      final uri = Uri.parse('$_kBoardBaseUrl/posts').replace(queryParameters: query);
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _allPosts = [];
          _loadError = '게시글 목록을 불러오지 못했습니다.';
          _isLoading = false;
        });
        return;
      }
      final data = jsonDecode(res.body) as Map;
      final list = (data['posts'] as List? ?? []) as List;
      final posts = <Post>[];
      for (final p in list) {
        final map = p as Map;
        final postId = (map['post_id'] ?? map['id']) as int?;
        if (postId == null) continue;
        final title = (map['title'] as String?) ?? '';
        final content = (map['content'] as String?) ?? '';
        final userId = map['user_id'] as int?;
        final regionId = map['region_id'] as int?;
        final categoryId = map['category_id'] as int?;
        final createdAt = map['created_at'];
        DateTime dt = DateTime.now();
        if (createdAt != null) {
          try {
            dt = DateTime.parse(createdAt.toString());
          } catch (_) {}
        }
        final commentCount = map['comment_count'] as int?;
        posts.add(Post(
          id: postId,
          title: title,
          content: content,
          region: regionId != null ? (_regionIdToName[regionId] ?? '미정') : '전체',
          category: categoryId != null ? (_categoryIdToName[categoryId] ?? '미정') : '미정',
          author: 'User${userId ?? 0}',
          createdAt: dt,
          comments: [],
          commentCount: commentCount,
        ));
      }
      setState(() {
        _allPosts = posts;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _allPosts = [];
          _loadError = '게시글 목록을 불러오지 못했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildPostList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToWritePage,
        backgroundColor: const Color(0xFF29B6F6),
        foregroundColor: Colors.white,
        elevation: 2,
        tooltip: '글쓰기',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  // === 필터 & 검색 영역 ===
  Widget _buildFilterSection() {
    final hasRegionFilter = _selectedRegion != '전체';
    final hasCategoryFilter = _selectedCategory != '전체';
    final isFiltered = hasRegionFilter || hasCategoryFilter;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 + 게시글 수
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('여행 커뮤니티',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (!_isLoading && _allPosts.isNotEmpty)
                Text('${_allPosts.length}개',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 12),
          // 검색창
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '제목 또는 내용 검색',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                      onPressed: () {
                        setState(() { _searchController.clear(); });
                        _loadPosts();
                      },
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
            onSubmitted: (_) => _loadPosts(),
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: 10),
          // 지역 칩
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableRegions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final region = _availableRegions[i];
                final isSelected = _selectedRegion == region;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRegion = region);
                    _loadPosts();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            ),
          ),
          const SizedBox(height: 6),
          // 카테고리 칩
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final category = _filterCategories[i];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    _loadPosts();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getCategoryColor(category)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        )),
                  ),
                );
              },
            ),
          ),
          // 활성 필터 요약 + 초기화
          if (isFiltered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.filter_list, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                if (hasRegionFilter)
                  _buildActiveFilterBadge(
                    _selectedRegion,
                    () { setState(() => _selectedRegion = '전체'); _loadPosts(); },
                  ),
                if (hasRegionFilter && hasCategoryFilter) const SizedBox(width: 6),
                if (hasCategoryFilter)
                  _buildActiveFilterBadge(
                    _selectedCategory,
                    () { setState(() => _selectedCategory = '전체'); _loadPosts(); },
                    color: _getCategoryColor(_selectedCategory),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() { _selectedRegion = '전체'; _selectedCategory = '전체'; });
                    _loadPosts();
                  },
                  child: const Text('초기화',
                      style: TextStyle(fontSize: 12, color: Color(0xFF29B6F6), fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilterBadge(String label, VoidCallback onRemove, {Color? color}) {
    final c = color ?? const Color(0xFF29B6F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: c),
          ),
        ],
      ),
    );
  }

  // === 게시글 목록 ===
  Widget _buildPostList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF29B6F6), strokeWidth: 2),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadPosts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('다시 시도',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      );
    }
    if (_allPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('게시글이 없어요\n첫 글을 작성해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[400], height: 1.6)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _allPosts.length,
      itemBuilder: (context, index) => _buildPostCard(_allPosts[index]),
    );
  }

  // === 게시글 카드 ===
  Widget _buildPostCard(Post post) {
    final commentCount = post.commentCount ?? post.comments.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CommunityDetailPage(post: post)),
          ).then((_) => _loadPosts());
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F6FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.region,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0288D1)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryChip(post.category),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                post.content,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(post.author,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 10),
                      Text(_formatDate(post.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('$commentCount',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey[300]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카테고리 칩 위젯
  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _getCategoryColor(category),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // 카테고리별 색상 반환
  Color _getCategoryColor(String category) {
    switch (category) {
      case '날씨':
        return Colors.lightBlue;
      case '양도':
        return Colors.orange;
      case '동행':
        return Colors.purple;
      case '후기':
        return Colors.green;
      case 'Q&A':
        return Colors.blue;
      case '선택 안 함':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // 날짜 포맷팅
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

  // === 글쓰기 페이지로 이동 ===
  void _navigateToWritePage() async {
    final result = await Navigator.push<Post>(
      context,
      MaterialPageRoute(
        builder: (context) => const CommunityWritePage(),
      ),
    );

    // 글쓰기 페이지에서 게시글을 작성하고 돌아왔을 때
    if (result != null) {
      setState(() {
        _allPosts.insert(0, result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글이 등록되었습니다.'),
        ),
      );
    }
  }
}

