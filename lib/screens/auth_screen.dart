import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  SupabaseClient get supabase => Supabase.instance.client;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = '전화번호를 입력하세요');
      return;
    }

    // 한국 번호 포맷
    String formatted = phone;
    if (phone.startsWith('010')) {
      formatted = '+82${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      formatted = '+82$phone';
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await supabase.auth.signInWithOtp(phone: formatted);
      setState(() {
        _otpSent = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'OTP 발송 실패: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() => _error = '인증번호를 입력하세요');
      return;
    }

    String formatted = phone;
    if (phone.startsWith('010')) {
      formatted = '+82${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      formatted = '+82$phone';
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await supabase.auth.verifyOTP(
        phone: formatted,
        token: otp,
        type: OtpType.sms,
      );

      // 인증 성공 → shops 테이블에 업소 등록 (없으면)
      final user = supabase.auth.currentUser;
      if (user != null) {
        final existing = await supabase
            .from('shops')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (existing == null) {
          final name = _nameController.text.trim();
          if (name.isEmpty) {
            setState(() {
              _loading = false;
              _error = '업소명을 입력하세요';
            });
            return;
          }
          await supabase.from('shops').insert({
            'id': user.id,
            'name': name,
            'owner_phone': formatted,
            'password_hash': '-', // phone auth라 불필요
          });
        }
      }

      // 추천코드 적용
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty && user != null) {
        await SupabaseService.applyReferral(referralCode, user.id);
      }

      setState(() => _loading = false);
      // 인증 완료 → main.dart에서 상태 감지
    } catch (e) {
      setState(() {
        _error = '인증 실패: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('🚨', style: TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '얘진상',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '진상 손님 사전 차단 시스템',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 48),

                // 업소명 (첫 가입 시)
                if (!_otpSent) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '업소명',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.store_outlined, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _referralController,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: '추천코드 (선택)',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.card_giftcard, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Text('첫 달 50%', style: TextStyle(color: Color(0xFF34C759), fontSize: 12)),
                      ),
                      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 전화번호
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpSent,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '010-0000-0000',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white38, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // OTP 입력
                if (_otpSent) ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '인증번호 입력',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 16, letterSpacing: 0),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : () {
                      setState(() => _otpSent = false);
                      _otpController.clear();
                    },
                    child: const Text(
                      '번호 다시 입력',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      disabledBackgroundColor: const Color(0xFFFF3B30).withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _otpSent ? '인증 확인' : '인증번호 받기',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  '전화번호는 인증에만 사용되며\n제3자에게 제공되지 않습니다',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
