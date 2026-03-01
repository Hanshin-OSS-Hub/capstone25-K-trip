// 이 파일은 카테고리 메뉴 아이템을 표시하는 재사용 가능한 위젯입니다.
// 둥근 사각형 하얀 박스 안에 아이콘과 텍스트를 수직으로 배치합니다.
// 선택된 상태일 때 시각적으로 구분되도록 배경색이나 테두리를 변경합니다.

import 'package:flutter/material.dart';

class CategoryMenuItem extends StatelessWidget {
  // 아이콘
  final IconData icon;
  
  // 아이콘 색상
  final Color iconColor;
  
  // 메뉴 텍스트
  final String label;
  
  // 선택된 상태인지 여부
  final bool isSelected;
  
  // 클릭 시 호출되는 콜백
  final VoidCallback? onTap;

  const CategoryMenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 메뉴 아이템의 너비 (고정값으로 일정한 크기 유지)
        width: 90,
        // 메뉴 아이템의 높이
        height: 100,
        // 둥근 모서리를 가진 박스
        // 선택된 경우 배경색을 변경하여 시각적으로 구분
        decoration: BoxDecoration(
          color: isSelected 
              ? iconColor.withOpacity(0.1) // 선택 시 아이콘 색상의 연한 배경
              : Colors.white, // 기본 하얀 배경
          borderRadius: BorderRadius.circular(16),
          // 선택된 경우 테두리 추가
          border: isSelected
              ? Border.all(
                  color: iconColor,
                  width: 2,
                )
              : null,
          // 그림자 효과로 입체감 추가
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // 아이콘과 텍스트를 수직으로 배치
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            Icon(
              icon,
              size: 36,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            // 텍스트 라벨
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

