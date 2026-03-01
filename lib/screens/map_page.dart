// 이 파일은 지도 페이지입니다.
// 현재 위치 기반 주변 관광지 추천 UI를 제공합니다.
// TODO: 추후 실제 GPS 위치, 지도 SDK(Google Maps 등), 백엔드 연동 예정
// 현재는 더미 데이터와 placeholder UI만 사용합니다.

import 'package:flutter/material.dart';

// === 주변 관광지 데이터 모델 ===
// TODO: 추후 백엔드 API에서 받아온 데이터로 교체
class NearbyPlace {
  final String city;        // 도시명 (예: '서울')
  final String name;        // 장소 이름 (예: '경복궁')
  final String category;    // 카테고리 (예: '역사 · 문화')
  final double distanceKm;  // 현재 위치로부터 거리 (km 단위, 더미 수치)
  final double rating;      // 평점 (예: 4.7)
  final String shortDesc;   // 간단 설명

  NearbyPlace({
    required this.city,
    required this.name,
    required this.category,
    required this.distanceKm,
    required this.rating,
    required this.shortDesc,
  });
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // TODO: 추후 실제 GPS 위치로 교체
  // 현재는 예시 위치를 텍스트로만 표시
  static const String _exampleCurrentLocation = '서울 시청 근처';

  // TODO: 추후 백엔드 API에서 주변 관광지 리스트를 가져오도록 수정
  // 더미 주변 관광지 데이터 (서울 시내 관광지 위주)
  static final List<NearbyPlace> mockNearbyPlaces = [
    NearbyPlace(
      city: '서울',
      name: '경복궁',
      category: '역사 · 문화',
      distanceKm: 0.8,
      rating: 4.7,
      shortDesc: '조선 왕조의 대표적인 궁궐로 한국의 역사를 느낄 수 있는 곳',
    ),
    NearbyPlace(
      city: '서울',
      name: '명동 거리',
      category: '쇼핑 · 음식',
      distanceKm: 1.2,
      rating: 4.5,
      shortDesc: '서울의 대표적인 쇼핑 거리와 맛집이 모여있는 번화가',
    ),
    NearbyPlace(
      city: '서울',
      name: 'N서울타워',
      category: '관광 · 전망',
      distanceKm: 2.5,
      rating: 4.6,
      shortDesc: '서울의 랜드마크로 야경이 아름다운 전망대',
    ),
    NearbyPlace(
      city: '서울',
      name: '북촌 한옥마을',
      category: '역사 · 문화',
      distanceKm: 1.0,
      rating: 4.8,
      shortDesc: '전통 한옥이 잘 보존된 아름다운 마을',
    ),
    NearbyPlace(
      city: '서울',
      name: '인사동',
      category: '문화 · 쇼핑',
      distanceKm: 0.9,
      rating: 4.4,
      shortDesc: '전통 문화와 현대가 공존하는 거리',
    ),
    NearbyPlace(
      city: '서울',
      name: '한강 공원',
      category: '자연 · 휴식',
      distanceKm: 3.2,
      rating: 4.9,
      shortDesc: '도심 속에서 자연을 즐길 수 있는 휴식 공간',
    ),
    NearbyPlace(
      city: '서울',
      name: '덕수궁',
      category: '역사 · 문화',
      distanceKm: 0.5,
      rating: 4.6,
      shortDesc: '조선 시대 궁궐로 석조전이 유명한 곳',
    ),
    NearbyPlace(
      city: '서울',
      name: '동대문 디자인 플라자',
      category: '문화 · 건축',
      distanceKm: 2.8,
      rating: 4.5,
      shortDesc: '현대적 건축물로 유명한 문화 공간',
    ),
  ];

  // 거리 기준으로 정렬된 주변 관광지 리스트
  List<NearbyPlace> get _sortedPlaces {
    final sorted = List<NearbyPlace>.from(mockNearbyPlaces);
    sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 여백 및 작은 안내 텍스트
          Text(
            '현재 위치 기반 추천',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          
          // 큰 제목
          Text(
            '내 주변 추천 여행지',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          
          // 현재 위치 표시
          Text(
            '예시 위치: $_exampleCurrentLocation 기준',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 24),
          
          // 지도 영역 Placeholder
          // TODO: 추후 실제 지도 위젯(GoogleMap 등)으로 교체
          _buildMapPlaceholder(),
          const SizedBox(height: 24),
          
          // 추천 장소 리스트
          _buildPlacesList(),
        ],
      ),
    );
  }

  // === 지도 영역 Placeholder ===
  // TODO: 추후 실제 지도 SDK(google_maps_flutter 등) 연동 시 이 부분을 GoogleMap 위젯으로 교체
  Widget _buildMapPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
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
              '여기는 나중에 실제 지도가 들어갈 영역입니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '(추후 실제 지도 연동 예정)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // === 추천 장소 리스트 ===
  Widget _buildPlacesList() {
    final places = _sortedPlaces;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: places.length,
      itemBuilder: (context, index) {
        return _buildPlaceCard(places[index]);
      },
    );
  }

  // === 장소 카드 ===
  Widget _buildPlaceCard(NearbyPlace place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 도시 + 카테고리
            Row(
              children: [
                Text(
                  place.city,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  place.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 큰 제목: 장소 이름
            Text(
              place.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            
            // 설명
            Text(
              place.shortDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 16),
            
            // 하단: 거리 + 평점
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 왼쪽: 거리 표시
                Row(
                  children: [
                    Icon(
                      Icons.place,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '약 ${place.distanceKm.toStringAsFixed(1)}km',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                
                // 오른쪽: 평점 표시
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
