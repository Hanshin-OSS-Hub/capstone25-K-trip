// 이 파일은 상단 카테고리 메뉴 섹션을 표시하는 위젯입니다.
// 가로 스크롤 가능한 리스트로 여러 카테고리 메뉴 아이템을 배치합니다.
// AppBar 아래에 위치하여 탭 네비게이션 역할을 합니다.
// 선택된 카테고리를 시각적으로 표시하고, 클릭 시 해당 페이지로 전환합니다.

import 'package:flutter/material.dart';
import 'category_menu_item.dart';

// 카테고리 메뉴 데이터 모델
class CategoryMenuData {
  final IconData icon;
  final Color iconColor;
  final String label;

  CategoryMenuData({
    required this.icon,
    required this.iconColor,
    required this.label,
  });
}

class CategoryMenuSection extends StatelessWidget {
  // 현재 선택된 카테고리 인덱스
  final int selectedIndex;
  
  // 카테고리 선택 시 호출되는 콜백
  final Function(int) onCategorySelected;

  const CategoryMenuSection({
    super.key,
    required this.selectedIndex,
    required this.onCategorySelected,
  });

  // 카테고리 메뉴 데이터 리스트 (4개 탭: AI 일정, 지도, 리뷰, 게시판)
  // 실제 앱에서는 API나 상태 관리로부터 가져올 수 있습니다.
  List<CategoryMenuData> _getMenuItems() {
    return [
      CategoryMenuData(
        icon: Icons.auto_awesome,
        iconColor: const Color(0xFF3498DB), // 파란색
        label: 'AI일정추천',
      ),
      CategoryMenuData(
        icon: Icons.map,
        iconColor: const Color(0xFFE74C3C), // 붉은색
        label: '지도',
      ),
      CategoryMenuData(
        icon: Icons.rate_review,
        iconColor: const Color(0xFF9B59B6), // 보라색
        label: '리뷰',
      ),
      CategoryMenuData(
        icon: Icons.forum,
        iconColor: const Color(0xFF1ABC9C), // 청록색
        label: '게시판',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuItems();

    return Container(
      // 연한 파스텔톤 배경색
      color: const Color(0xFFF8F9FA),
      // 상하 여백 추가
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 가로 스크롤 가능한 리스트뷰
          SizedBox(
            height: 100,
            child: ListView.builder(
              // 가로 스크롤 설정
              scrollDirection: Axis.horizontal,
              // 좌우 여백 추가
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // 아이템 간 간격 설정
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                // 현재 선택된 카테고리인지 확인
                final isSelected = index == selectedIndex;
                return Padding(
                  // 각 메뉴 아이템 사이에 충분한 간격 추가
                  padding: const EdgeInsets.only(right: 12),
                  child: CategoryMenuItem(
                    icon: item.icon,
                    iconColor: item.iconColor,
                    label: item.label,
                    // 선택 상태 전달
                    isSelected: isSelected,
                    // 카테고리 선택 시 콜백 호출하여 페이지 전환
                    onTap: () {
                      onCategorySelected(index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

