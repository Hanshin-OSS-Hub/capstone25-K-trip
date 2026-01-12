// 이 파일은 K-Trip 앱의 진입점입니다.
// MaterialApp을 설정하고, 상단 카테고리 메뉴를 탭 네비게이션으로 사용하는 메인 화면을 표시합니다.
// 4개의 카테고리(AI 일정 추천, 지도, 리뷰, 게시판)를 관리하는 StatefulWidget입니다.
// 0206-01-12 확인용


import 'package:flutter/material.dart';
import 'screens/home_ai_schedule_page.dart';
import 'screens/map_page.dart';
import 'screens/reviews_page.dart';
import 'screens/community_page.dart';
import 'widgets/category_menu_section.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Trip',

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],


      // K-컬처 느낌의 보라색 계열 테마 설정
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B59B6), // 보라색 계열
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// 메인 화면: 상단 카테고리 메뉴를 탭 네비게이션으로 사용하는 구조
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 카테고리의 인덱스 (0: AI 일정, 1: 지도, 2: 리뷰, 3: 게시판)
  int _currentIndex = 0;

  // 각 카테고리에 해당하는 페이지 위젯 리스트
  final List<Widget> _pages = [
    const HomeAISchedulePage(),
    const MapPage(),
    const ReviewsPage(),
    const CommunityPage(),
  ];

  // 각 카테고리의 제목 리스트
  final List<String> _titles = [
    'AI 일정 추천',
    '지도',
    '리뷰',
    '커뮤니티',
  ];

  // 카테고리 선택 시 호출되는 콜백
  void _onCategorySelected(int index) {
    setState(() {
      // 선택된 카테고리 인덱스를 업데이트하면 자동으로 해당 페이지가 표시됨
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 현재 선택된 카테고리에 맞는 제목 표시
        title: Text(_titles[_currentIndex]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      // 카테고리 메뉴와 선택된 페이지를 표시
      body: Column(
        children: [
          // 상단 카테고리 메뉴 섹션 (가로 스크롤 가능, 탭 네비게이션 역할)
          CategoryMenuSection(
            selectedIndex: _currentIndex,
            onCategorySelected: _onCategorySelected,
          ),
          // 선택된 카테고리의 페이지 내용
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
    );
  }
}
