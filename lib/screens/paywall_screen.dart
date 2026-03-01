import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isReferred = false;
  bool _loaded = false;
  final _promoController = TextEditingController();
  bool _applyingPromo = false;

  @override
  void initState() {
    super.initState();
    _checkReferral();
  }

  Future<void> _checkReferral() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('flutter.shop_id');
    if (shopId != null) {
      final referred = await SupabaseService.hasBeenReferred(shopId);
      if (mounted) {
        setState(() {
          _isReferred = referred;
          _loaded = true;
        });
      }
    } else {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _isReferred ? '29,000' : '49,000';
    final priceNote = _isReferred ? '원/첫 달 (추천 할인)' : '원/월';
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 잠금 아이콘
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('🔒', style: TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 24),
                const Text(
                  '구독이 필요합니다',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '얘진상 서비스를 이용하려면\n구독 결제가 필요합니다',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // 가격 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1F1F1F), Color(0xFF171717)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '월 구독',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (_isReferred)
                        const Text(
                          '49,000원',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white38,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white38,
                          ),
                        ),
                      if (_isReferred) const SizedBox(height: 4),
                      Text(
                        '$price원',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: _isReferred ? const Color(0xFF34C759) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isReferred ? '첫 달 추천 할인가' : '/월',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      _feature('🛡️', '수신 전화 실시간 진상 감지'),
                      _feature('📋', '진상 태그 무제한 등록'),
                      _feature('🔗', '업소간 블랙리스트 공유'),
                      _feature('📊', '월간 차단 리포트'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 프로모 코드 입력
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text('🎁 구독 코드', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(fontSize: 15, letterSpacing: 2),
                              decoration: InputDecoration(
                                hintText: '코드 입력',
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: const Color(0xFF252525),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _applyingPromo ? null : _applyPromoCode,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF34C759),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _applyingPromo
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('적용', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 결제 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _showPaymentInfo(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      '구독하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 로그아웃
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('flutter.shop_id');
                    await prefs.remove('flutter.shop_name');
                    await prefs.remove('flutter.logged_in');
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                    }
                  },
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _feature(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  void _showPaymentInfo(BuildContext context) {
    final depositorController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '계좌이체로 결제',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text('입금 계좌', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    SizedBox(height: 8),
                    Text(
                      '토스뱅크 1000-3013-4144',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '예금주: 이재원',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 계좌번호 복사
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: '토스뱅크 1000-3013-4144'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ 계좌번호 복사됨'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF34C759),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('계좌번호 복사'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 구분선
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              const Text(
                '입금 후 아래 버튼을 눌러주세요',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // 입금자명 입력
              TextField(
                controller: depositorController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '입금자명 입력',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF252525),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // 입금완료 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSending ? null : () async {
                    setSheetState(() => isSending = true);
                    await _requestPaymentConfirm(
                      context,
                      depositorController.text.trim(),
                    );
                    setSheetState(() => isSending = false);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    disabledBackgroundColor: const Color(0xFFFF6B00).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '💰 입금완료',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '입금 확인 후 빠르게 활성화됩니다',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('flutter.shop_id');
    if (shopId == null) return;

    setState(() => _applyingPromo = true);
    try {
      final result = await SupabaseService.applyPromo(code, shopId);
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
        // 구독 상태 갱신을 위해 앱 재시작
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ 오류가 발생했습니다'),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
    if (mounted) setState(() => _applyingPromo = false);
  }

  Future<void> _requestPaymentConfirm(BuildContext context, String depositorName) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('flutter.shop_id');
    if (shopId == null) return;

    final price = _isReferred ? 29000 : 49000;

    try {
      final res = await http.post(
        Uri.parse('https://jinsang.thebespoke.team/api/payment-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shop_id': shopId,
          'amount': price,
          'depositor_name': depositorName.isEmpty ? '미입력' : depositorName,
          'plan': 'monthly',
        }),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.statusCode == 200
                  ? '✅ 입금확인 요청 완료! 빠르게 처리해드릴게요'
                  : '⚠️ 요청 실패, 다시 시도해주세요',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: res.statusCode == 200
                ? const Color(0xFF34C759)
                : const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ 네트워크 오류, 다시 시도해주세요'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
