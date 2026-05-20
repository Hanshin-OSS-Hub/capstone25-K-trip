import 'package:flutter/material.dart';
import '../api/location_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String _exampleCurrentLocation = '서울 시청 근처';

  List<Map<String, dynamic>> _places = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await LocationApi.getLocations(
        language: 'en',
        limit: 20,
      );
      setState(() {
        _places = List<Map<String, dynamic>>.from(result['locations']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '관광지를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 위치 기반 추천',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '내 주변 추천 여행지',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '예시 위치: $_exampleCurrentLocation 기준',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          _buildMapPlaceholder(),
          const SizedBox(height: 24),
          _buildPlacesList(),
        ],
      ),
    );
  }

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

  Widget _buildPlacesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_places.isEmpty) {
      return const Center(child: Text('주변 관광지가 없습니다.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _places.length,
      itemBuilder: (context, index) {
        return _buildPlaceCard(_places[index]);
      },
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
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
            Row(
              children: [
                Text(
                  place['city'] ?? '',
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
                  place['category_name'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              place['name'] ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              place['address'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}