// 이 파일은 게시판(커뮤니티) 페이지입니다.
// 게시글 목록을 API에서 불러와 표시하고, 필터/검색 시 서버 쿼리로 재요청합니다.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'community_detail_page.dart';
import 'community_write_page.dart';

// 플랫폼별 API Base URL (Android 에뮬: 10.0.2.2, iOS 시뮬: 127.0.0.1)
const String _kBoardBaseUrl = 'http://10.0.2.2:8000';

/// API 응답이 비었거나 실패할 때 사용할 지역 목록(전체 제외) 및 이름→id 폴백 매핑
const List<String> _kFallbackRegionNames = [
  '서울', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남',
  '부산', '대구', '대전', '울산', '광주', '제주',
];
/// API 응답이 비었거나 실패할 때 사용할 카테고리 목록(전체 제외)
const List<String> _kFallbackCategoryNames = ['날씨', '양도', '동행', '후기', 'Q&A'];

// === 게시글 데이터 모델 ===
class Post {
  final int id;
  final String title;
  final String content;
  final String region;      // 지역 (예: 서울, 부산, 제주 등)
  final String category;   // 카테고리 (날씨, 양도, 동행, 후기, Q&A, 선택 안 함)
  final String author;      // 작성자
  final DateTime createdAt;
  final List<Comment> comments; // 댓글 리스트 (목록에서는 비워두고 commentCount 사용)
  final int? commentCount; // 서버에서 준 댓글 개수(목록 카드 표시용)

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

// === 댓글 데이터 모델 ===
// TODO: 추후 백엔드 API에서 받아온 데이터로 교체
class Comment {
  final String author;      // 작성자 (지금은 "익명"으로 고정)
  final String content;     // 댓글 내용
  final DateTime createdAt; // 작성 시간

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
      body: Column(
        children: [
          // 상단 필터 & 검색 영역
          _buildFilterSection(),
          
          // 게시글 목록
          Expanded(
            child: _buildPostList(),
          ),
        ],
      ),
      // 오른쪽 아래 플로팅 액션 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToWritePage,
        child: const Icon(Icons.edit),
        tooltip: '글쓰기',
      ),
    );
  }

  // === 필터 & 검색 영역 ===
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            '여행 커뮤니티',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // 지역 선택
          Row(
            children: [
              const Icon(Icons.location_on, size: 20),
              const SizedBox(width: 8),
              Text(
                '지역',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _availableRegions.contains(_selectedRegion) ? _selectedRegion : '전체',
                  isExpanded: true,
                  items: _availableRegions.map((region) {
                    return DropdownMenuItem<String>(
                      value: region,
                      child: Text(region),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _selectedRegion = value;
                      });
                      _loadPosts(); // 필터 변경 시 서버에 다시 요청
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 카테고리 선택
          Row(
            children: [
              const Icon(Icons.category, size: 20),
              const SizedBox(width: 8),
              Text(
                '카테고리',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _filterCategories.contains(_selectedCategory) ? _selectedCategory : '전체',
                  isExpanded: true,
                  items: _filterCategories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                      _loadPosts(); // 필터 변경 시 서버에 다시 요청
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 검색창 (검색 시 서버 쿼리로 요청)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '제목 또는 내용 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                              _loadPosts();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _loadPosts(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadPosts,
                icon: const Icon(Icons.search),
                tooltip: '검색',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === 게시글 목록 (API 결과 그대로 표시, 로딩/에러 처리) ===
  Widget _buildPostList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadPosts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_allPosts.isEmpty) {
      return Center(
        child: Text(
          '게시글이 없습니다.\n첫 게시글을 작성해보세요!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _allPosts.length,
      itemBuilder: (context, index) {
        return _buildPostCard(_allPosts[index]);
      },
    );
  }

  // === 게시글 카드 ===
  Widget _buildPostCard(Post post) {
    final commentCount = post.commentCount ?? post.comments.length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 상세 페이지로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailPage(post: post),
            ),
          ).then((_) {
            // 상세 페이지에서 돌아왔을 때 댓글이 추가되었을 수 있으므로 화면 갱신
            setState(() {});
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리와 지역
              Row(
                children: [
                  // 지역 태그
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.region,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 카테고리 태그
                  _buildCategoryChip(post.category),
                ],
              ),
              const SizedBox(height: 8),
              
              // 제목
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // 내용 일부 (1~2줄만)
              Text(
                post.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // 작성자, 작성일, 댓글 개수
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    post.author,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  Row(
                    children: [
                      // 댓글 개수 표시 (작은 글씨)
                      Text(
                        '댓글 $commentCount개',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
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

