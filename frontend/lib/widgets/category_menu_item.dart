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
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF29B6F6) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFBBBBBB),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

