import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '🛡️',
      title: '얘진상에 오신 걸 환영합니다',
      subtitle: '업소 사장님들을 위한\n진상 손님 공유 서비스',
      description: '다른 업소에서 등록한 진상 정보를\n전화 수신 시 바로 확인하세요',
    ),
    _OnboardingPage(
      emoji: '📞',
      title: '전화가 오면 자동 감지',
      subtitle: '수신 전화 번호를 즉시 조회해서\n진상 여부를 알려드려요',
      description: '빨간 경고 = 주의 필요\n초록 안심 = 등록 정보 없음',
    ),
    _OnboardingPage(
      emoji: '📋',
      title: '연락처에서 한번에 등록',
      subtitle: '저장된 연락처를 불러와서\n메모 기반으로 자동 분류해요',
      description: '"폭력", "먹튀" 등 메모가 있으면\n자동으로 태그를 붙여줍니다',
    ),
    _OnboardingPage(
      emoji: '🤝',
      title: '업소끼리 함께 지켜요',
      subtitle: '내가 등록한 진상 정보가\n다른 업소 사장님도 보호합니다',
      description: '추천 코드로 동료에게 알려주세요\n함께 쓸수록 더 안전해져요',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // 스킵 버튼
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    _currentPage < _pages.length - 1 ? '건너뛰기' : '',
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              ),
            ),

            // 페이지
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(page.emoji, style: const TextStyle(fontSize: 72)),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 인디케이터
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? const Color(0xFFFF3B30)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? '다음' : '시작하기 🚀',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}
