import 'package:flutter/material.dart';
import '../api/review_api.dart';

const int _kTempUserId = 1;
const int _kDefaultLocationId = 1;

const List<String> _kReviewRegions = [
  '서울', '부산', '제주', '경기', '인천', '강원', '경주',
  '대구', '대전', '광주', '울산', '전북', '전남', '경북', '경남', '충북', '충남',
];

class ReviewWritePage extends StatefulWidget {
  const ReviewWritePage({super.key});

  @override
  State<ReviewWritePage> createState() => _ReviewWritePageState();
}

class _ReviewWritePageState extends State<ReviewWritePage> {
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedRegion = '서울';
  int _selectedRating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _placeController.dispose();
    _contentController.dispose();
    super.dispose();
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
          '리뷰 작성',
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
              onPressed: _isSubmitting ? null : _submitReview,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('등록', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 장소명
            TextField(
              controller: _placeController,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(hint: '장소명을 입력하세요  (예: 경복궁, 해운대)', icon: Icons.place_outlined),
            ),
            const SizedBox(height: 20),

            // 지역 선택
            const Text('지역',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kReviewRegions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final region = _kReviewRegions[i];
                  final isSelected = _selectedRegion == region;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRegion = region),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        region,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 별점
            const Text('별점',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 34,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // 리뷰 내용
            const Text('리뷰 내용',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: _fieldDecoration(hint: '여행지에 대한 솔직한 리뷰를 남겨주세요.').copyWith(
                contentPadding: const EdgeInsets.all(16),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소명을 입력해주세요.')),
      );
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 내용을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ReviewApi.createReview(
        userId: _kTempUserId,
        locationId: _kDefaultLocationId,
        rating: _selectedRating,
        title: _placeController.text.trim(),
        comment: _contentController.text.trim(),
        region: _selectedRegion,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // true = 새 리뷰 등록됨
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰가 등록되었습니다.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
