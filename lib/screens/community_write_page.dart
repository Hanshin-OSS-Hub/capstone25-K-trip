// 이 파일은 게시글 작성 페이지입니다.
// 사용자가 새 게시글을 작성할 수 있는 화면을 제공합니다.
// TODO: 추후 백엔드 API 연동 예정

import 'package:flutter/material.dart';
import 'community_page.dart';

class CommunityWritePage extends StatefulWidget {
  const CommunityWritePage({super.key});

  @override
  State<CommunityWritePage> createState() => _CommunityWritePageState();
}

class _CommunityWritePageState extends State<CommunityWritePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  // 지역 선택 (작성 시에는 '전체' 제외)
  static const List<String> _writeRegions = [
    '서울',
    '부산',
    '제주',
  ];
  
  // 카테고리 선택 (작성 시에는 '선택 안 함' 포함)
  static const List<String> _writeCategories = [
    '날씨',
    '양도',
    '동행',
    '후기',
    'Q&A',
    '선택 안 함',
  ];

  String _selectedRegion = _writeRegions[0];
  String _selectedCategory = '선택 안 함';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 작성'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '게시글 제목을 입력하세요',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            
            // 지역 선택
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: const InputDecoration(
                labelText: '지역',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              items: _writeRegions.map((region) {
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
                }
              },
            ),
            const SizedBox(height: 16),
            
            // 카테고리 선택
            Text(
              '카테고리',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _writeCategories.length,
                itemBuilder: (context, index) {
                  final category = _writeCategories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      selectedColor: _getCategoryColor(category),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // 본문 입력
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '본문',
                hintText: '게시글 내용을 입력하세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 24),
            
            // 등록 버튼
            ElevatedButton(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

  // === 게시글 등록 ===
  void _submitPost() {
    // 입력값 검증
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목을 입력해주세요.'),
        ),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('본문을 입력해주세요.'),
        ),
      );
      return;
    }

    // 새 게시글 생성
    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      region: _selectedRegion,
      category: _selectedCategory,
      author: 'User${DateTime.now().millisecondsSinceEpoch % 1000}',
      createdAt: DateTime.now(),
      comments: [],
    );

    // 게시글을 반환하고 페이지 닫기
    Navigator.pop(context, newPost);
  }
}



