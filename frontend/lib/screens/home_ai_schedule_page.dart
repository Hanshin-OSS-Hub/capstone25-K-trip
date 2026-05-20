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
    'Seoul', 'Busan', 'Jeju', 'Incheon', 'Daegu', 'Daejeon',
    'Gwangju', 'Ulsan', 'Gyeonggi', 'Gangwon', 'Chungnam', 'Chungbuk',
    'Jeonnam', 'Jeonbuk', 'Gyeongnam', 'Gyeongbuk', 'Suwon', 'Gyeongju',
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDescription(),
          const SizedBox(height: 24),
          _buildCityDropdown(),
          const SizedBox(height: 16),
          _buildDateRangeSelector(),
          const SizedBox(height: 16),
          _buildCompanionSection(),
          const SizedBox(height: 16),
          _buildInterestsSection(),
          const SizedBox(height: 24),
          _buildGenerateButton(),
          const SizedBox(height: 24),
          if (_recommendedSpots.isNotEmpty) _buildItineraryResult(),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Enter your travel preferences and get a recommended itinerary!',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: const InputDecoration(
        labelText: 'City',
        hintText: 'Select a city',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city),
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
            Icon(
              Icons.calendar_today,
              color: _startDate != null && _endDate != null
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatDateRange(),
                style: TextStyle(
                  fontSize: 16,
                  color: _startDate != null && _endDate != null
                      ? Colors.black87
                      : Colors.grey[600],
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who are you traveling with?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        RadioListTile<TravelCompanion>(
          title: const Text('With friends'),
          value: TravelCompanion.friend,
          groupValue: _selectedCompanion,
          onChanged: (v) => setState(() => _selectedCompanion = v),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<TravelCompanion>(
          title: const Text('With family'),
          value: TravelCompanion.family,
          groupValue: _selectedCompanion,
          onChanged: (v) => setState(() => _selectedCompanion = v),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<TravelCompanion>(
          title: const Text('Solo'),
          value: TravelCompanion.solo,
          groupValue: _selectedCompanion,
          onChanged: (v) => setState(() => _selectedCompanion = v),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<TravelCompanion>(
          title: const Text('With partner'),
          value: TravelCompanion.couple,
          groupValue: _selectedCompanion,
          onChanged: (v) => setState(() => _selectedCompanion = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select interests (multiple)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return ChoiceChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedInterests.add(interest);
                  } else {
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

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _generateSchedule,
      icon: _isLoading
          ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome),
      label: Text(_isLoading ? 'Generating...' : 'Get Recommended Itinerary'),
      style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16)),
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
        Card(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedCity · $days Day Itinerary',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateRange(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...spotsByDay.entries.map((entry) =>
            _buildDayScheduleCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDayScheduleCard(String dayLabel, List<RecommendedSpot> spots) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dayLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 12),
            ...spots.map((spot) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${spot.order}',
                          style: const TextStyle(
                              color: Colors.white,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(spot.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600])),
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