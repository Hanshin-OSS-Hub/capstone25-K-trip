import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/itinerary_api.dart';

enum TravelCompanion {
  friend,
  family,
  solo,
  couple,
}

class RecommendedSpot {
  final String dayLabel;
  final String name;
  final String description;
  final int order;
  final double mockLat;
  final double mockLng;

  RecommendedSpot({
    required this.dayLabel,
    required this.name,
    required this.description,
    required this.order,
    required this.mockLat,
    required this.mockLng,
  });
}

class HomeAISchedulePage extends StatefulWidget {
  const HomeAISchedulePage({super.key});

  @override
  State<HomeAISchedulePage> createState() => _HomeAISchedulePageState();
}

class _HomeAISchedulePageState extends State<HomeAISchedulePage> {

  // 영어로 표시할 도시 목록
  static const List<String> availableCities = [
    'Seoul', 'Busan', 'Jeju', 'Gyeonggi', 'Incheon', 'Gangwon',
    'Gyeongju', 'Daegu', 'Daejeon', 'Gwangju', 'Ulsan', 'Suwon',
    'Jeonbuk', 'Jeonnam', 'Gyeongbuk', 'Gyeongnam', 'Chungnam', 'Chungbuk',
    'Ulleung', 'Sejong',
  ];

  // 영어 → 한국어 변환 맵 (서버에 보낼 때 사용)
  static const Map<String, String> cityToKo = {
    'Seoul': '서울', 'Busan': '부산', 'Jeju': '제주',
    'Incheon': '인천', 'Daegu': '대구', 'Daejeon': '대전',
    'Gwangju': '광주', 'Ulsan': '울산', 'Gyeonggi': '경기',
    'Gangwon': '강원', 'Chungnam': '충남', 'Chungbuk': '충북',
    'Jeonnam': '전남', 'Jeonbuk': '전북', 'Gyeongnam': '경남',
    'Gyeongbuk': '경북', 'Suwon': '수원', 'Gyeongju': '경주',
    'Ulleung': '울릉', 'Sejong': '세종',
  };

  // 영어로 표시할 관심사
  final List<String> _interests = [
    'Food', 'Dessert', 'History', 'Nature', 'Shopping', 'Experience', 'K-Culture'
  ];

  // 영어 → 한국어 변환 맵
  static const Map<String, String> interestToKo = {
    'Food': '맛집', 'Dessert': '디저트', 'History': '역사',
    'Nature': '자연', 'Shopping': '쇼핑', 'Experience': '체험', 'K-Culture': '한류',
  };

  String? _selectedCity;
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedInterests = [];
  TravelCompanion? _selectedCompanion;
  List<RecommendedSpot> _recommendedSpots = [];
  bool _isLoading = false;

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('en', 'US'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) {
      return 'Select travel dates';
    }
    final dateFormat = DateFormat('yyyy.MM.dd');
    return '${dateFormat.format(_startDate!)} ~ ${dateFormat.format(_endDate!)}';
  }

  Future<void> _generateSchedule() async {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a city.')));
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select travel dates.')));
      return;
    }
    if (_selectedCompanion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a companion type.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companionMap = {
        TravelCompanion.friend: '친구와',
        TravelCompanion.family: '가족과',
        TravelCompanion.solo:   '혼자',
        TravelCompanion.couple: '연인과',
      };

      // 영어 → 한국어 변환 후 서버로 전송
      final themes = _selectedInterests.isEmpty
          ? ['맛집', '자연']
          : _selectedInterests.map((i) => interestToKo[i] ?? i).toList();

      final result = await ItineraryApi.generatePlan(
        region: cityToKo[_selectedCity] ?? _selectedCity!,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        companion: companionMap[_selectedCompanion]!,
        themes: themes,
      );

      final schedule = result['schedule'] as List;
      List<RecommendedSpot> spots = [];

      for (var day in schedule) {
        final dayLabel = 'Day ${day['day']}';
        final places = day['places'] as List;
        for (int i = 0; i < places.length; i++) {
          final p = places[i];
          spots.add(RecommendedSpot(
            dayLabel: dayLabel,
            name: p['name_ko'] ?? '',
            description: p['category'] ?? '',
            order: i + 1,
            mockLat: double.tryParse(p['lat'].toString()) ?? 0.0,
            mockLng: double.tryParse(p['lon'].toString()) ?? 0.0,
          ));
        }
      }

      setState(() {
        _recommendedSpots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate schedule: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDescription(),
          const SizedBox(height: 24),
          _buildCityDropdown(),
          const SizedBox(height: 12),
          _buildDateRangeSelector(),
          const SizedBox(height: 20),
          _buildCompanionSection(),
          const SizedBox(height: 20),
          _buildInterestsSection(),
          const SizedBox(height: 28),
          _buildGenerateButton(),
          const SizedBox(height: 28),
          if (_recommendedSpots.isNotEmpty) _buildItineraryResult(),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI 일정 추천',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('여행 정보를 입력하면 AI가 최적의 일정을 추천해드려요',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: InputDecoration(
        labelText: '도시 선택',
        hintText: '여행할 도시를 선택하세요',
        prefixIcon: const Icon(Icons.location_city_outlined, color: Color(0xFF29B6F6)),
        filled: true,
        fillColor: const Color(0xFFF8FEFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF29B6F6), width: 1.5),
        ),
      ),
      items: availableCities.map((city) {
        return DropdownMenuItem<String>(value: city, child: Text(city));
      }).toList(),
      onChanged: (String? value) {
        setState(() => _selectedCity = value);
      },
    );
  }

  Widget _buildDateRangeSelector() {
    final hasDate = _startDate != null && _endDate != null;
    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFFE3F6FD) : const Color(0xFFF8FEFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate ? const Color(0xFF29B6F6) : const Color(0xFFE0E0E0),
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: hasDate ? const Color(0xFF29B6F6) : Colors.grey[400],
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatDateRange(),
                style: TextStyle(
                  fontSize: 14,
                  color: hasDate ? const Color(0xFF222222) : Colors.grey[400],
                  fontWeight: hasDate ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionSection() {
    final companions = [
      {'value': TravelCompanion.solo,   'label': '혼자',   'icon': Icons.person_outline},
      {'value': TravelCompanion.friend, 'label': '친구',   'icon': Icons.group_outlined},
      {'value': TravelCompanion.couple, 'label': '연인',   'icon': Icons.favorite_outline},
      {'value': TravelCompanion.family, 'label': '가족',   'icon': Icons.family_restroom},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('동행 유형',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 10),
        Row(
          children: companions.map((c) {
            final isSelected = _selectedCompanion == c['value'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCompanion = c['value'] as TravelCompanion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(c['icon'] as IconData,
                            size: 20,
                            color: isSelected ? Colors.white : Colors.grey[500]),
                        const SizedBox(height: 5),
                        Text(c['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.grey[600],
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('관심사 선택 (복수)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(interest);
                  } else {
                    _selectedInterests.add(interest);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  interest,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF29B6F6),
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: const Color(0xFFB3E5FC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 18),
                  SizedBox(width: 8),
                  Text('AI 일정 추천받기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildItineraryResult() {
    final Map<String, List<RecommendedSpot>> spotsByDay = {};
    for (var spot in _recommendedSpots) {
      spotsByDay.putIfAbsent(spot.dayLabel, () => []).add(spot);
    }

    final days = _endDate!.difference(_startDate!).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedCity · $days일 일정',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateRange(),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...spotsByDay.entries.map((entry) =>
            _buildDayScheduleCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDayScheduleCard(String dayLabel, List<RecommendedSpot> spots) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF29B6F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(dayLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...spots.map((spot) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F6FD),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${spot.order}',
                          style: const TextStyle(
                              color: Color(0xFF29B6F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(spot.description,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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