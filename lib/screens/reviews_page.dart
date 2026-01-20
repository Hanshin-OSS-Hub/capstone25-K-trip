// 이 파일은 여행지 리뷰 페이지입니다.
// 지도 영역과 여행지 선택 기능을 포함한 리뷰 목록 및 작성 기능을 제공합니다.
// setState를 사용하여 리뷰 리스트를 상태로 관리합니다.
// 이미지 첨부 및 추천/비추천 기능이 포함되어 있습니다.
// TODO: 추후 실제 지도 위젯, GPS 위치, 백엔드 API 연동 예정

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../api/review_api.dart';


// === 여행지 데이터 모델 ===
// TODO: 추후 백엔드 API에서 받아온 데이터로 교체
class Place {
  final String id;
  final String name;

  Place({
    required this.id,
    required this.name,
  });
}

// === 리뷰 데이터 모델 ===
// 이미지 첨부 및 추천/비추천 기능을 포함한 확장된 구조
class Review {
  final String id;
  final String placeId;      // 어떤 여행지에 대한 리뷰인지 연결
  final String placeName;    // 여행지 이름 (표시용)
  final String region;       // 지역 (서울, 경기, 강원 등)
  final int rating;
  final String content;
  final String author;
  final DateTime createdAt;
  final XFile? image;        // 첨부된 이미지 파일 (null이면 이미지 없음)
  final int likeCount;       // 추천 수
  final int dislikeCount;    // 비추천 수
  final int userVote;        // 사용자의 투표 상태 (1 = 추천, -1 = 비추천, 0 = 투표 안 함)

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

  // 추천/비추천 상태를 업데이트한 새로운 Review 인스턴스 생성
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
  // ImagePicker 인스턴스 (갤러리에서 이미지 선택 시 사용)
  final ImagePicker _picker = ImagePicker();
  static const int _currentUserId = 1;
  static const int _defaultLocationId = 1;
  bool _isLoading = false;
  String? _loadError;

  // 선택 가능한 지역 목록
  static const List<String> _availableRegions = [
    '전체',
    '서울',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '부산',
    '대구',
    '대전',
    '울산',
    '광주',
    '제주',
  ];

  // 현재 선택된 지역 (null이면 전체 보기)
  String? _selectedRegion;

  // 검색어 입력 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // TODO: 추후 백엔드 API에서 리뷰 리스트를 가져오도록 수정
  // 리뷰 리스트를 상태로 관리
  // 더미데이터 주석상태
  List<Review> _reviews = [
    // Review(
    //   id: '1',
    //   placeId: 'seoul1',
    //   placeName: '경복궁',
    //   region: '서울',
    //   rating: 5,
    //   content: '한국의 역사를 느낄 수 있는 아름다운 곳입니다! 조선 왕조의 대표적인 궁궐로 정말 인상적이었어요.',
    //   author: 'Traveler123',
    //   createdAt: DateTime.now().subtract(const Duration(days: 3)),
    //   likeCount: 12,
    //   dislikeCount: 1,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '2',
    //   placeId: 'seoul2',
    //   placeName: '명동 거리',
    //   region: '서울',
    //   rating: 4,
    //   content: '쇼핑하기 좋지만 사람이 많아요. 다양한 브랜드와 맛집이 있어서 좋습니다.',
    //   author: 'KoreaLover',
    //   createdAt: DateTime.now().subtract(const Duration(days: 2)),
    //   likeCount: 8,
    //   dislikeCount: 2,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '3',
    //   placeId: 'seoul3',
    //   placeName: '한강 공원',
    //   region: '서울',
    //   rating: 5,
    //   content: '저녁에 산책하기 완벽한 장소입니다. 야경도 아름답고 분위기가 좋아요.',
    //   author: 'SeoulExplorer',
    //   createdAt: DateTime.now().subtract(const Duration(days: 1)),
    //   likeCount: 15,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '4',
    //   placeId: 'busan1',
    //   placeName: '해운대 해수욕장',
    //   region: '부산',
    //   rating: 5,
    //   content: '부산의 대표 해변으로 정말 아름답습니다. 일몰이 특히 장관이에요!',
    //   author: 'BeachLover',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    //   likeCount: 20,
    //   dislikeCount: 1,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '5',
    //   placeId: 'busan2',
    //   placeName: '자갈치 시장',
    //   region: '부산',
    //   rating: 4,
    //   content: '신선한 해산물을 맛볼 수 있는 곳입니다. 활기찬 분위기가 좋아요.',
    //   author: 'Foodie',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    //   likeCount: 10,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '6',
    //   placeId: 'jeju1',
    //   placeName: '성산일출봉',
    //   region: '제주',
    //   rating: 5,
    //   content: '유네스코 세계자연유산으로 정말 인상적입니다. 일출을 보러 가는 것을 추천해요!',
    //   author: 'NatureLover',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 18)),
    //   likeCount: 25,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '7',
    //   placeId: 'incheon1',
    //   placeName: '인천 차이나타운',
    //   region: '인천',
    //   rating: 4,
    //   content: '한국 최대 차이나타운으로 중국 음식과 문화를 경험할 수 있어요.',
    //   author: 'CultureExplorer',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    //   likeCount: 7,
    //   dislikeCount: 1,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '8',
    //   placeId: 'gangneung1',
    //   placeName: '경포대 해수욕장',
    //   region: '강원',
    //   rating: 5,
    //   content: '강릉의 대표 해변으로 깨끗하고 아름다운 곳입니다. 커피거리도 가까워서 좋아요.',
    //   author: 'CoastalTraveler',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    //   likeCount: 18,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '9',
    //   placeId: 'gangnam1',
    //   placeName: '강남역',
    //   region: '서울',
    //   rating: 4,
    //   content: '서울의 중심지로 쇼핑과 맛집이 많아요. 지하철 접근성도 좋습니다.',
    //   author: 'CityExplorer',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    //   likeCount: 9,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
    // Review(
    //   id: '10',
    //   placeId: 'hongdae1',
    //   placeName: '홍대 거리',
    //   region: '서울',
    //   rating: 5,
    //   content: '젊은 문화의 중심지! 클럽, 카페, 쇼핑몰이 많아서 하루 종일 즐길 수 있어요.',
    //   author: 'YouthTraveler',
    //   createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    //   likeCount: 14,
    //   dislikeCount: 0,
    //   userVote: 0,
    // ),
  ];

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
      final rawReviews = await ReviewApi.getReviewsByUser(_currentUserId);
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
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      return fallback;
    }

    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = data[key];
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    final createdAtRaw = readString(['created_at', 'createdAt'], fallback: '');
    final parsedDate = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    final userId = readInt(['user_id', 'userId'], fallback: 0);

    return Review(
      id: readString(['review_id', 'id'], fallback: DateTime.now().millisecondsSinceEpoch.toString()),
      placeId: readString(['location_id', 'place_id', 'placeId'], fallback: 'unknown'),
      placeName: readString(['review_title', 'place_name', 'placeName', 'spot_name'], fallback: '리뷰'),
      region: readString(['region', 'area'], fallback: '전체'),
      rating: readInt(['rating', 'score'], fallback: 5),
      content: readString(['review_comment', 'content', 'review'], fallback: ''),
      author: userId > 0 ? 'User$userId' : readString(['author', 'user_name', 'nickname'], fallback: 'Unknown'),
      createdAt: parsedDate,
      likeCount: readInt(['total_likes', 'like_count', 'likes'], fallback: 0),
      dislikeCount: readInt(['dislike_count', 'dislikes'], fallback: 0),
      userVote: readInt(['user_vote', 'userVote', 'vote'], fallback: 0),
      image: null,
    );
  }

  // 선택된 지역과 검색어에 따라 필터링된 리뷰 리스트
  List<Review> get _filteredReviews {
    var filtered = _reviews;

    // 지역 필터링
    if (_selectedRegion != null && _selectedRegion != '전체') {
      filtered = filtered.where((review) => review.region == _selectedRegion).toList();
    }

    // 검색어 필터링
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((review) {
        return review.placeName.toLowerCase().contains(searchQuery) ||
            review.content.toLowerCase().contains(searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // 전체 스크롤을 위해 SingleChildScrollView로 변경
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopSection(),

            // ⭐ 리뷰 API 연결 테스트 버튼 (임시)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () async {
                  await _loadReviewsFromApi();
                },
                child: const Text("리뷰 API 테스트"),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: CircularProgressIndicator(),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Text(
                  '리뷰를 불러오지 못했습니다.\n$_loadError',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.redAccent,
                      ),
                ),
              )
            else
              _buildReviewList(),
          ],

        ),
      ),
      // 오른쪽 아래 플로팅 액션 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReviewDialog,
        child: const Icon(Icons.add),
        tooltip: '리뷰 작성',
      ),
    );
  }

  // === 상단 섹션 (지도 영역 + 검색) ===
  Widget _buildTopSection() {
    return Column(
      children: [
        // 한국 지도 이미지
        _buildKoreaMap(),
        
        const SizedBox(height: 16),
        
        // 검색 입력 필드
        _buildSearchBar(),
        
        const SizedBox(height: 8),
      ],
    );
  }

  // === 한국 지도 이미지 (클릭 가능한 지역 버튼 포함) ===
  Widget _buildKoreaMap() {
    // 지도 영역 높이 확장 및 비율 유지로 이미지 잘림 방지
    return Container(
      height: 450,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 리뷰 탭 상단 한국 지도 이미지
            Image.asset(
              'assets/images/koreamap.png',  // 한국 지도 이미지 경로
              fit: BoxFit.contain,  // 비율 유지하여 이미지 잘림 방지
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                // 이미지가 없을 경우 placeholder 표시
                return Container(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '한국 지도',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 클릭 가능한 지역 버튼들 (Overlay)
            ..._buildRegionMarkers(),
          ],
        ),
      ),
    );
  }

  // === 지도 위에 배치할 지역 마커 버튼들 ===
  List<Widget> _buildRegionMarkers() {
    // 각 지역의 상대적 위치 (지도 크기 기준 퍼센트)
    final Map<String, Offset> regionPositions = {
      '서울': const Offset(0.28, 0.18),
      '경기': const Offset(0.33, 0.23),
      '강원': const Offset(0.55, 0.18),
      '충북': const Offset(0.46, 0.28),
      '충남': const Offset(0.29, 0.34),
      '대전': const Offset(0.34, 0.39),
      '전북': const Offset(0.35, 0.50),
      '전남': const Offset(0.30, 0.67),
      '경북': const Offset(0.57, 0.39),
      '대구': const Offset(0.58, 0.49),
      '경남': const Offset(0.50, 0.56),
      '부산': const Offset(0.67, 0.60),
      '울산': const Offset(0.70, 0.54),
      '광주': const Offset(0.29, 0.60),
      '제주': const Offset(0.25, 0.92),
    };

    return regionPositions.entries.map((entry) {
      final region = entry.key;
      final position = entry.value;
      final isSelected = _selectedRegion == region;

      return Positioned(
        left: position.dx * (MediaQuery.of(context).size.width - 32), // margin 고려
        top: position.dy * 450, // 지도 높이에 맞춰 마커 위치 조정
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedRegion = region;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              region,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }


  // === 검색 입력 필드 ===
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '장소명 또는 내용 검색 (예: 강남, 홍대, 해운대)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  // === 리뷰 목록 ===
  Widget _buildReviewList() {
    final filteredReviews = _filteredReviews;

    if (filteredReviews.isEmpty) {
      // 리뷰 리스트는 내부 스크롤을 끄고 shrinkWrap 사용
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            _selectedRegion == null && _searchController.text.isEmpty
                ? '아직 리뷰가 없습니다.\n첫 리뷰를 작성해보세요!'
                : '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    // 리뷰 리스트는 내부 스크롤을 끄고 shrinkWrap 사용
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredReviews.length,
      itemBuilder: (context, index) {
        // 원본 리스트에서의 인덱스 찾기
        final review = filteredReviews[index];
        final originalIndex = _reviews.indexWhere((r) => r.id == review.id);
        return _buildReviewCard(review, originalIndex >= 0 ? originalIndex : index);
      },
    );
  }

  // === 리뷰 카드 ===
  Widget _buildReviewCard(Review review, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === 이미지 첨부 영역 ===
          // 이미지가 있는 경우에만 썸네일 표시
          if (review.image != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.file(
                File(review.image!.path),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 여행지 이름과 별점
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 지역 태그
                          Text(
                            '[${review.region}] ${review.placeName}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 별점 표시 (1~5개 별 아이콘)
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 리뷰 내용 (두 줄만 표시)
                Text(
                  review.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 작성자 정보
                Row(
                  children: [
                    Text(
                      '작성자: ${review.author}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // === 추천/비추천 버튼 영역 ===
                Row(
                  children: [
                    // 추천 버튼
                    Expanded(
                      child: _buildVoteButton(
                        icon: Icons.thumb_up,
                        label: '추천',
                        count: review.likeCount,
                        isSelected: review.userVote == 1,
                        onTap: () => _toggleLike(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 비추천 버튼
                    Expanded(
                      child: _buildVoteButton(
                        icon: Icons.thumb_down,
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
    final previous = review;
    int newLikeCount = review.likeCount;
    int newDislikeCount = review.dislikeCount;
    int newUserVote = review.userVote;

    if (review.userVote == 0) {
      // 아무것도 선택하지 않은 상태에서 추천 클릭
      newLikeCount = review.likeCount + 1;
      newUserVote = 1;
    } else if (review.userVote == 1) {
      // 이미 추천을 눌러 둔 상태에서 추천 재클릭 (해제)
      newLikeCount = (review.likeCount - 1).clamp(0, double.infinity).toInt();
      newUserVote = 0;
    } else if (review.userVote == -1) {
      // 비추천이 선택된 상태에서 추천 클릭 (전환)
      newDislikeCount = (review.dislikeCount - 1).clamp(0, double.infinity).toInt();
      newLikeCount = review.likeCount + 1;
      newUserVote = 1;
    }

    setState(() {
      _reviews[reviewIndex] = review.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        userVote: newUserVote,
      );
    });

    try {
      final reviewId = int.tryParse(review.id);
      if (reviewId == null) {
        throw Exception('리뷰 ID 형식이 올바르지 않습니다.');
      }

      if (newUserVote == 1) {
        await ReviewApi.likeReview(reviewId: reviewId, userId: _currentUserId);
      } else if (newUserVote == 0 && previous.userVote == 1) {
        await ReviewApi.unlikeReview(reviewId: reviewId, userId: _currentUserId);
      }
    } catch (e) {
      setState(() {
        _reviews[reviewIndex] = previous;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 상태 저장 실패: $e')),
        );
      }
    }
  }

  // === 비추천 버튼 토글 처리 ===
  Future<void> _toggleDislike(int reviewIndex) async {
    final review = _reviews[reviewIndex];
    final previous = review;
    int newLikeCount = review.likeCount;
    int newDislikeCount = review.dislikeCount;
    int newUserVote = review.userVote;

    if (review.userVote == 0) {
      // 아무것도 선택하지 않은 상태에서 비추천 클릭
      newDislikeCount = review.dislikeCount + 1;
      newUserVote = -1;
    } else if (review.userVote == -1) {
      // 이미 비추천을 눌러 둔 상태에서 비추천 재클릭 (해제)
      newDislikeCount = (review.dislikeCount - 1).clamp(0, double.infinity).toInt();
      newUserVote = 0;
    } else if (review.userVote == 1) {
      // 추천이 선택된 상태에서 비추천 클릭 (전환)
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비추천은 서버에서 지원하지 않습니다.')),
      );
    }
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

  // === 리뷰 작성 다이얼로그 표시 ===
  void _showAddReviewDialog() {
    // 입력값을 저장할 변수들
    final contentController = TextEditingController();
    final placeNameController = TextEditingController();
    int selectedRating = 5; // 기본값 5점
    XFile? selectedImage; // 선택된 이미지 파일
    String? selectedRegion = _selectedRegion ?? '서울'; // 기본값은 현재 선택된 지역
    final rootContext = context;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '리뷰 작성',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 지역 선택 드롭다운
                  DropdownButtonFormField<String>(
                    value: selectedRegion,
                    decoration: const InputDecoration(
                      labelText: '지역 선택',
                      hintText: '지역을 선택하세요',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    items: _availableRegions.where((r) => r != '전체').map((region) {
                      return DropdownMenuItem<String>(
                        value: region,
                        child: Text(region),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setModalState(() {
                        if (value != null) {
                          selectedRegion = value;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 장소명 입력
                  TextField(
                    controller: placeNameController,
                    decoration: const InputDecoration(
                      labelText: '장소명',
                      hintText: '예: 경복궁, 해운대 해수욕장, 강남역',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 별점 선택
                  Text(
                    '별점',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // === 이미지 선택 영역 ===
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '사진 첨부 (선택사항)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // 선택된 이미지 미리보기
                      if (selectedImage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(selectedImage!.path),
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // 이미지 삭제 버튼
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setModalState(() {
                                        selectedImage = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 이미지 선택 버튼
                      OutlinedButton.icon(
                        onPressed: () async {
                          // 갤러리에서 이미지 선택
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setModalState(() {
                              selectedImage = image;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: Text(selectedImage == null ? '갤러리에서 선택' : '이미지 변경'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 리뷰 내용 입력
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '리뷰 내용',
                      hintText: '여행지에 대한 리뷰를 작성해주세요.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  
                  // 등록 버튼
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final placeName = placeNameController.text.trim();
                            final content = contentController.text.trim();

                            if (placeName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('장소명을 입력해주세요.'),
                                ),
                              );
                              return;
                            }

                            if (content.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('리뷰 내용을 입력해주세요.'),
                                ),
                              );
                              return;
                            }

                            setModalState(() {
                              isSubmitting = true;
                            });

                            try {
                              await ReviewApi.createReview(
                                userId: _currentUserId,
                                locationId: _defaultLocationId,
                                rating: selectedRating,
                                title: placeName,
                                comment: content,
                              );

                              await _loadReviewsFromApi();

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.pop(context);

                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(
                                  content: Text('리뷰가 등록되었습니다.'),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('리뷰 등록 실패: $e'),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() {
                                  isSubmitting = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('등록'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
