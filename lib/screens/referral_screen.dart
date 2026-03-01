import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _myCode;
  int _referralCount = 0;
  bool _loading = true;
  final _promoController = TextEditingController();
  bool _applyingPromo = false;

  String _userId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('flutter.shop_id') ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    final code = await SupabaseService.getMyReferralCode(_userId);
    final count = await SupabaseService.getReferralCount(_userId);
    setState(() {
      _myCode = code;
      _referralCount = count;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _applyingPromo = true);
    try {
      final result = await SupabaseService.applyPromo(code, _userId);
      if (!mounted) return;

      if (result['success'] == true) {
        _promoController.clear();
        final days = result['days_added'] ?? 14;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${days}일 무료 체험이 적용되었습니다!'),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error'] ?? '코드 적용 실패'}'),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ 네트워크 오류. 다시 시도해주세요.'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ 추천코드 $_myCode 복사됨'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF34C759),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareCode() {
    if (_myCode == null) return;
    final text = '🚨 얘진상 — 진상 손님 사전 차단 앱\n\n'
        '추천코드: $_myCode\n'
        '이 코드로 가입하면 첫 달 50% 할인!\n\n'
        '다운로드: https://jinsang.thebespoke.team';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ 공유 메시지 복사됨 — 카톡에 붙여넣기하세요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF34C759),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('추천하기', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 내 추천코드 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A1215), Color(0xFF1A0A0C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('내 추천코드', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _copyCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D0D),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _myCode ?? '---',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    color: Color(0xFFFF3B30),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.copy, color: Colors.white38, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '터치하면 복사됩니다',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 추천 현황
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_referralCount',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text('추천 성공', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 50, color: Colors.white.withOpacity(0.1)),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_referralCount',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                              const Text('무료 연장(월)', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 혜택 안내
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '추천 혜택',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _benefitRow('🎁', '추천한 나', '추천 1건당 1개월 무료 연장'),
                        const SizedBox(height: 12),
                        _benefitRow('🎉', '추천받은 상대', '첫 달 50% 할인 (24,500원)'),
                        const SizedBox(height: 12),
                        _benefitRow('♾️', '제한 없음', '10명 추천 = 10개월 무료!'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 프로모 코드 입력
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🎁 프로모 코드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('무료 체험 코드가 있다면 입력하세요', style: TextStyle(fontSize: 12, color: Colors.white38)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promoController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 2),
                                decoration: InputDecoration(
                                  hintText: '코드 입력',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                  filled: true,
                                  fillColor: const Color(0xFF0D0D0D),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _applyingPromo ? null : _applyPromoCode,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B00),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _applyingPromo
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('적용', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 공유 버튼
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _shareCode,
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('카톡으로 공유하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _benefitRow(String emoji, String title, String desc) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }
}
