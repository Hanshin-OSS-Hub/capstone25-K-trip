// === AI 일정 추천 화면 ===
// 이 파일은 AI 일정 추천 메인 화면입니다.
// 사용자가 여행 조건(도시, 날짜 범위, 동행 타입, 관심사)을 입력하면 더미 일정을 생성하여 보여줍니다.
// setState를 사용하여 입력값과 일정 리스트를 상태로 관리합니다.
// 나중에 AI API나 DB 연동 시 선택된 값들을 한 곳에서 쉽게 읽을 수 있도록 구조화되어 있습니다.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위한 패키지

// === 여행 동행 타입을 정의하는 Enum ===
// 나중에 AI 요청 시 이 값을 서버로 전송하면 됩니다.
// enum을 사용하면 타입 안정성을 보장하고, 오타나 잘못된 값을 방지할 수 있습니다.
enum TravelCompanion {
  friend,  // 친구와
  family,  // 가족과
  solo,     // 혼자
}

// === 추천 장소 데이터 모델 ===
// 각 일정에 포함되는 장소의 정보를 담는 클래스입니다.
// TODO: 추후 실제 지도 API 연동 시 mockLat, mockLng를 실제 좌표로 교체
class RecommendedSpot {
  final String dayLabel;      // 'Day 1', 'Day 2' 등
  final String name;          // 장소 이름
  final String description;   // 간단 설명
  final int order;            // 하루 안에서의 순서
  final double mockLat;       // 추후 실제 좌표 매핑용 더미 값
  final double mockLng;       // 추후 실제 좌표 매핑용 더미 값

  RecommendedSpot({
    required this.dayLabel,
    required this.name,
    required this.description,
    required this.order,
    required this.mockLat,
    required this.mockLng,
  });
}

// === AI 일정 추천 폼의 모든 입력값을 한 곳에서 관리하기 위한 클래스 ===
// 나중에 서버로 전송할 때 이 클래스의 인스턴스를 JSON으로 변환하면 됩니다.
// 현재는 화면 내에서만 사용하지만, 추후 API 연동 시 유용합니다.
class AiScheduleFormData {
  final String city;
  final DateTime? startDate;
  final DateTime? endDate;
  final TravelCompanion? companion;
  final List<String> interests;

  AiScheduleFormData({
    required this.city,
    this.startDate,
    this.endDate,
    this.companion,
    required this.interests,
  });

  // 모든 필수 항목이 입력되었는지 확인하는 메서드
  bool get isValid {
    return city.isNotEmpty &&
        startDate != null &&
        endDate != null &&
        companion != null;
  }

  // 디버깅이나 로그 출력 시 사용할 수 있는 문자열 표현
  @override
  String toString() {
    return 'AiScheduleFormData(city: $city, startDate: $startDate, endDate: $endDate, companion: $companion, interests: $interests)';
  }
}

class HomeAISchedulePage extends StatefulWidget {
  const HomeAISchedulePage({super.key});

  @override
  State<HomeAISchedulePage> createState() => _HomeAISchedulePageState();
}

class _HomeAISchedulePageState extends State<HomeAISchedulePage> {
  // === 상태 변수들 ===
  
  // 선택 가능한 도시 목록
  // TODO: 추후 DB/데이터 수집 결과에서 도시 목록을 불러오도록 수정 예정
  static const List<String> availableCities = [
    '서울',
    '부산',
    '제주',
    '인천',
    '강릉',
    '전주',
  ];
  
  // 선택된 도시 (null이면 아직 선택되지 않은 상태)
  String? _selectedCity;
  
  // 여행 시작 날짜 (null이면 아직 선택되지 않은 상태)
  // DateTime? 형태로 선언하여 null 체크로 선택 여부를 판단합니다.
  DateTime? _startDate;
  
  // 여행 종료 날짜 (null이면 아직 선택되지 않은 상태)
  DateTime? _endDate;

  // 선택 가능한 관심사 목록
  final List<String> _interests = ['K-pop', 'Food', 'History', 'Cafe', 'Shopping'];
  
  // 현재 선택된 관심사 목록 (복수 선택 가능)
  final List<String> _selectedInterests = [];

  // 여행 동행 타입 (null이면 아직 선택되지 않은 상태)
  // enum을 사용하여 타입 안정성을 보장합니다.
  TravelCompanion? _selectedCompanion;

  // 생성된 추천 일정 리스트 (RecommendedSpot 객체들의 리스트)
  List<RecommendedSpot> _recommendedSpots = [];

  // === 날짜 범위 선택 다이얼로그를 여는 메서드 ===
  // showDateRangePicker는 Flutter 기본 위젯으로, 달력 UI를 자동으로 제공합니다.
  // 사용자가 시작 날짜와 종료 날짜를 선택하면 DateTimeRange 객체를 반환합니다.
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      // 달력의 초기 날짜 (오늘 날짜)
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      // 선택 가능한 첫 날짜 (오늘부터)
      firstDate: DateTime.now(),
      // 선택 가능한 마지막 날짜 (1년 후까지)
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // 한국어 로케일 설정 (날짜 표시를 한국어로)
      locale: const Locale('ko', 'KR'),
      // 달력 헤더 스타일 커스터마이징
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    // 사용자가 날짜를 선택하고 "확인"을 눌렀을 때만 상태 업데이트
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // === 선택된 날짜 범위를 포맷팅하여 표시하는 메서드 ===
  // "2025.03.01 ~ 2025.03.04" 형식으로 변환합니다.
  String _formatDateRange() {
    if (_startDate == null || _endDate == null) {
      return '여행 날짜를 선택해주세요';
    }
    
    // intl 패키지의 DateFormat을 사용하여 날짜 포맷팅
    final dateFormat = DateFormat('yyyy.MM.dd');
    return '${dateFormat.format(_startDate!)} ~ ${dateFormat.format(_endDate!)}';
  }

  // === AI 일정 추천 버튼을 눌렀을 때 호출되는 메서드 ===
  // 모든 입력값을 검증하고, 유효하면 더미 일정을 생성합니다.
  void _generateSchedule() {
    // 입력값 검증
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 도시를 선택해주세요.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 날짜를 선택해주세요.')),
      );
      return;
    }

    if (_selectedCompanion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동행 타입을 선택해주세요.')),
      );
      return;
    }

    // === 선택된 모든 값을 AiScheduleFormData로 묶어서 관리 ===
    // 나중에 AI API 호출 시 이 객체를 사용하면 됩니다.
    final formData = AiScheduleFormData(
      city: _selectedCity!,
      startDate: _startDate,
      endDate: _endDate,
      companion: _selectedCompanion,
      interests: _selectedInterests.isEmpty 
          ? _interests.take(2).toList() 
          : _selectedInterests,
    );

    // 디버깅용: 선택된 값들을 콘솔에 출력 (실제 앱에서는 제거해도 됨)
    debugPrint('선택된 여행 정보: $formData');

    // setState를 호출하여 화면을 다시 그립니다.
    // 이 안에서 상태 변수를 변경하면 자동으로 UI가 업데이트됩니다.
    setState(() {
      // 더미 일정 데이터 생성
      _recommendedSpots = _generateMockItinerary(formData);
    });
  }

  // === 더미 추천 일정을 생성하는 메서드 ===
  // 실제 AI API 연동 시 이 부분을 서버 응답으로 대체하면 됩니다.
  // TODO: 추후 DB 연동
  List<RecommendedSpot> _generateMockItinerary(AiScheduleFormData formData) {
    final city = formData.city;
    // 선택된 관심사는 추후 AI 추천 로직에 활용 예정
    // final selectedInterests = formData.interests;
    
    // 선택된 날짜 범위로 여행 일수 계산
    final days = formData.endDate!.difference(formData.startDate!).inDays + 1;

    // 도시별 더미 장소 데이터
    final Map<String, List<Map<String, String>>> citySpots = {
      '서울': [
        {'name': '경복궁', 'desc': '조선 왕조의 대표 궁궐'},
        {'name': '북촌 한옥마을', 'desc': '전통 한옥 거리'},
        {'name': '인사동', 'desc': '전통 문화 거리'},
        {'name': '명동', 'desc': '쇼핑과 맛집의 중심지'},
        {'name': 'N서울타워', 'desc': '서울의 랜드마크'},
        {'name': '한강 공원', 'desc': '도심 속 휴식 공간'},
      ],
      '부산': [
        {'name': '해운대 해수욕장', 'desc': '부산의 대표 해변'},
        {'name': '광안리 해수욕장', 'desc': '야경이 아름다운 해변'},
        {'name': '자갈치 시장', 'desc': '신선한 해산물 시장'},
        {'name': '태종대', 'desc': '아름다운 절경'},
        {'name': '감천문화마을', 'desc': '부산의 산토리니'},
        {'name': '부산타워', 'desc': '부산 전망대'},
      ],
      '제주': [
        {'name': '성산일출봉', 'desc': '유네스코 세계자연유산'},
        {'name': '한라산', 'desc': '제주의 상징'},
        {'name': '천지연폭포', 'desc': '아름다운 폭포'},
        {'name': '카멜리아힐', 'desc': '동백꽃 테마파크'},
        {'name': '협재해수욕장', 'desc': '에메랄드 빛 바다'},
        {'name': '제주 올레길', 'desc': '걷기 좋은 코스'},
      ],
      '인천': [
        {'name': '인천 차이나타운', 'desc': '한국 최대 차이나타운'},
        {'name': '월미도', 'desc': '인천의 대표 관광지'},
        {'name': '송도 센트럴파크', 'desc': '도심 속 공원'},
        {'name': '강화도', 'desc': '역사와 자연이 공존하는 섬'},
      ],
      '강릉': [
        {'name': '경포대 해수욕장', 'desc': '강릉의 대표 해변'},
        {'name': '안목해변', 'desc': '커피거리로 유명'},
        {'name': '오죽헌', 'desc': '신사임당 생가'},
        {'name': '정동진', 'desc': '일출 명소'},
      ],
      '전주': [
        {'name': '전주 한옥마을', 'desc': '한국의 전통 문화'},
        {'name': '전주 비빔밥 거리', 'desc': '전주 음식의 본고장'},
        {'name': '전주 경기전', 'desc': '조선 왕조의 사당'},
        {'name': '덕진공원', 'desc': '전주의 대표 공원'},
      ],
    };

    // 도시에 맞는 장소 리스트 가져오기 (없으면 기본값)
    final spots = citySpots[city] ?? [
      {'name': '$city 명소 1', 'desc': '관광지'},
      {'name': '$city 명소 2', 'desc': '맛집'},
      {'name': '$city 명소 3', 'desc': '카페'},
    ];

    // 일정 생성
    List<RecommendedSpot> itinerary = [];
    int spotIndex = 0;
    
    for (int day = 1; day <= days; day++) {
      final dayLabel = 'Day $day';
      // 하루에 3-4개 장소 배정
      final spotsPerDay = day == 1 ? 4 : 3;
      
      for (int order = 1; order <= spotsPerDay; order++) {
        if (spotIndex >= spots.length) {
          spotIndex = 0; // 리스트가 끝나면 처음부터 다시
        }
        
        final spot = spots[spotIndex];
        // 더미 좌표 생성 (도시별로 약간씩 다른 범위)
        final baseLat = 37.5 + (day * 0.01); // 위도
        final baseLng = 127.0 + (order * 0.01); // 경도
        
        itinerary.add(
          RecommendedSpot(
            dayLabel: dayLabel,
            name: spot['name']!,
            description: spot['desc']!,
            order: order,
            mockLat: baseLat,
            mockLng: baseLng,
          ),
        );
        
        spotIndex++;
      }
    }

    return itinerary;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 설명 텍스트
          _buildDescription(),
          const SizedBox(height: 24),
          
          // 여행 도시 선택 드롭다운
          _buildCityDropdown(),
          const SizedBox(height: 16),
          
          // 여행 날짜 범위 선택 버튼
          _buildDateRangeSelector(),
          const SizedBox(height: 16),
          
          // 동행 타입 선택 섹션
          _buildCompanionSection(),
          const SizedBox(height: 16),
          
          // 관심사 선택 섹션
          _buildInterestsSection(),
          const SizedBox(height: 24),
          
          // AI 일정 추천 버튼
          _buildGenerateButton(),
          const SizedBox(height: 24),
          
          // 생성된 일정 결과
          if (_recommendedSpots.isNotEmpty) _buildItineraryResult(),
        ],
      ),
    );
  }

  // 상단 설명 위젯
  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          '여행 조건을 입력하면 AI가 일정을 추천해 줍니다.\n현재는 더미 데이터입니다.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 도시 선택 드롭다운
  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: const InputDecoration(
        labelText: '여행 도시',
        hintText: '도시를 선택하세요',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city),
      ),
      items: availableCities.map((city) {
        return DropdownMenuItem<String>(
          value: city,
          child: Text(city),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          _selectedCity = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '도시를 선택해주세요';
        }
        return null;
      },
    );
  }

  // === 날짜 범위 선택 버튼 ===
  // TextField 대신 버튼을 사용하여 DateRangePicker를 호출합니다.
  Widget _buildDateRangeSelector() {
    return InkWell(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: _startDate != null && _endDate != null
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 달력 아이콘
            Icon(
              Icons.calendar_today,
              color: _startDate != null && _endDate != null
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            // 선택된 날짜 범위 표시 (또는 안내 텍스트)
            Expanded(
              child: Text(
                _formatDateRange(),
                style: TextStyle(
                  fontSize: 16,
                  color: _startDate != null && _endDate != null
                      ? Colors.black87
                      : Colors.grey[600],
                  fontWeight: _startDate != null && _endDate != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
            // 오른쪽 화살표 아이콘
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  // === 동행 타입 선택 섹션 ===
  // 라디오 버튼을 사용하여 3가지 옵션 중 하나를 선택할 수 있습니다.
  Widget _buildCompanionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '누구와 여행하시나요?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        // 라디오 버튼 그룹
        // RadioListTile을 사용하면 텍스트와 함께 클릭 영역이 넓어져 사용성이 좋습니다.
        RadioListTile<TravelCompanion>(
          title: const Text('친구와'),
          value: TravelCompanion.friend,
          groupValue: _selectedCompanion,
          onChanged: (TravelCompanion? value) {
            setState(() {
              _selectedCompanion = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<TravelCompanion>(
          title: const Text('가족과'),
          value: TravelCompanion.family,
          groupValue: _selectedCompanion,
          onChanged: (TravelCompanion? value) {
            setState(() {
              _selectedCompanion = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<TravelCompanion>(
          title: const Text('혼자'),
          value: TravelCompanion.solo,
          groupValue: _selectedCompanion,
          onChanged: (TravelCompanion? value) {
            setState(() {
              _selectedCompanion = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // 관심사 선택 섹션
  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '관심사 선택 (복수 선택 가능)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interests.map((interest) {
            // 각 관심사를 ChoiceChip으로 표시
            // 선택 여부는 _selectedInterests 리스트에 포함되어 있는지로 판단
            final isSelected = _selectedInterests.contains(interest);
            return ChoiceChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    // 선택된 경우 리스트에 추가
                    _selectedInterests.add(interest);
                  } else {
                    // 선택 해제된 경우 리스트에서 제거
                    _selectedInterests.remove(interest);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // AI 일정 추천 버튼
  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _generateSchedule,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AI 일정 추천 받기'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  // === 추천 일정 결과 영역 ===
  Widget _buildItineraryResult() {
    // Day별로 그룹화
    final Map<String, List<RecommendedSpot>> spotsByDay = {};
    for (var spot in _recommendedSpots) {
      if (!spotsByDay.containsKey(spot.dayLabel)) {
        spotsByDay[spot.dayLabel] = [];
      }
      spotsByDay[spot.dayLabel]!.add(spot);
    }

    // 일수 계산
    final days = _endDate!.difference(_startDate!).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 결과 헤더
        Card(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedCity ${days}일 AI 추천 일정',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateRange(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Day별 일정 카드
        ...spotsByDay.entries.map((entry) => _buildDayScheduleCard(entry.key, entry.value)),
        
        const SizedBox(height: 16),
        
        // 지도 미리보기
        ItineraryMapPreview(spots: _recommendedSpots),
      ],
    );
  }

  // Day별 일정 카드
  Widget _buildDayScheduleCard(String dayLabel, List<RecommendedSpot> spots) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day 헤더
            Text(
              dayLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            // 장소 리스트
            ...spots.map((spot) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 순서 번호
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${spot.order}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 장소 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              spot.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// === 지도 미리보기 위젯 ===
// TODO: 추후 실제 지도 위젯(GoogleMap 등)으로 교체
// 현재는 가짜 지도 UI로 장소들의 경로를 시각화합니다.
class ItineraryMapPreview extends StatelessWidget {
  final List<RecommendedSpot> spots;

  const ItineraryMapPreview({
    super.key,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    // Day별로 그룹화
    final Map<String, List<RecommendedSpot>> spotsByDay = {};
    for (var spot in spots) {
      if (!spotsByDay.containsKey(spot.dayLabel)) {
        spotsByDay[spot.dayLabel] = [];
      }
      spotsByDay[spot.dayLabel]!.add(spot);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(
                  Icons.map,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '일정 경로 미리보기',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '(추후 실제 지도와 연동 예정)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 16),
            
            // 가짜 지도 영역
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // 배경 그리드 패턴 (선택사항)
                  CustomPaint(
                    painter: GridPainter(),
                    child: Container(),
                  ),
                  
                  // Day별 경로 표시
                  ...spotsByDay.entries.map((entry) {
                    final daySpots = entry.value;
                    final dayIndex = spotsByDay.keys.toList().indexOf(entry.key);
                    
                    return Positioned(
                      left: 20.0 + (dayIndex * 80.0),
                      top: 20.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day 라벨
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 장소 마커들
                          ...daySpots.asMap().entries.map((spotEntry) {
                            final index = spotEntry.key;
                            final spot = spotEntry.value;
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < daySpots.length - 1 ? 8.0 : 0,
                              ),
                              child: Column(
                                children: [
                                  // 마커 아이콘
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${spot.order}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 연결선 (마지막 장소가 아니면)
                                  if (index < daySpots.length - 1)
                                    Container(
                                      width: 2,
                                      height: 20,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                  
                  // 중앙 안내 텍스트
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${spots.length}개 장소',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 그리드 패턴을 그리는 CustomPainter ===
// 지도 미리보기 배경에 그리드 효과를 주기 위한 위젯
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    // 수직선
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 수평선
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}