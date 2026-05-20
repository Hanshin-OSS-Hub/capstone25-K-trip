import 'package:flutter/material.dart';

// 로그인 화면 위젯
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // 임시 로그인 이동 처리 함수
  void _onLoginPressed(BuildContext context) {
    // 임시 이동 처리 / 추후 API 연동 예정
    Navigator.pushReplacementNamed(context, '/main');
  }

  // 비밀번호 찾기 화면 이동 처리 함수
  void _onPasswordResetPressed(BuildContext context) {
    // 임시 이동 처리 / 추후 API 연동 예정
    Navigator.pushNamed(context, '/password-reset');
  }

  // 회원가입 화면 이동 처리 함수
  void _onSignupPressed(BuildContext context) {
    // 임시 이동 처리 / 추후 API 연동 예정
    Navigator.pushNamed(context, '/signup');
  }

  // 더미 소셜 로그인 처리 함수
  void _onSocialLoginPressed(BuildContext context, String provider) {
    // TODO: 실제 소셜 로그인 API 연동 위치
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider 로그인 기능은 준비 중입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // 상단 앱 이름 영역
              const Center(
                child: Text(
                  'K-Trip',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // 이메일/아이디 입력 필드
              _buildTextField(
                hintText: '이메일 또는 아이디',
                icon: Icons.mail_outline,
                obscureText: false,
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 필드
              _buildTextField(
                hintText: '비밀번호',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              // 로그인 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _onLoginPressed(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222222),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0x22000000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 하단 텍스트 버튼 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _onPasswordResetPressed(context),
                    child: const Text(
                      '비밀번호 찾기',
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _onSignupPressed(context),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // 간편 로그인 구분선 및 타이틀
              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '간편 로그인',
                      style: TextStyle(color: Color(0xFF8A8A8A)),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                ],
              ),
              const SizedBox(height: 20),
              // 간편 로그인 버튼 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    context: context,
                    label: '게스트',
                    icon: Icons.person_outline,
                    color: const Color(0xFF9E9E9E),
                    onPressed: () => _onSocialLoginPressed(context, '게스트'),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    label: '구글',
                    icon: Icons.g_mobiledata,
                    color: const Color(0xFF4285F4),
                    onPressed: () => _onSocialLoginPressed(context, '구글'),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    label: '애플',
                    icon: Icons.apple,
                    color: const Color(0xFF111111),
                    onPressed: () => _onSocialLoginPressed(context, '애플'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 입력 필드 공통 스타일
  static Widget _buildTextField({
    required String hintText,
    required IconData icon,
    required bool obscureText,
  }) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF9E9E9E)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
      ),
    );
  }

  // 원형 간편 로그인 버튼
  static Widget _buildSocialButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E5E5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A7A7A),
          ),
        ),
      ],
    );
  }
}
