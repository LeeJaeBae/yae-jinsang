import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _verificationId;

  SupabaseClient get supabase => Supabase.instance.client;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = '전화번호를 입력하세요');
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
      await fb.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          // 자동 인증 (Android SMS 자동 읽기)
          await _signInWithCredential(credential);
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _error = '인증 실패: ${e.message}';
              _loading = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
              _loading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'OTP 발송 실패: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = '인증번호를 입력하세요');
      return;
    }
    if (_verificationId == null) {
      setState(() => _error = '인증 세션이 만료되었습니다. 다시 시도하세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '인증 실패: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithCredential(fb.PhoneAuthCredential credential) async {
    try {
      final result = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = result.user;
      if (fbUser == null) throw Exception('Firebase 인증 실패');

      final phone = fbUser.phoneNumber ?? _phoneController.text.trim();
      String formatted = phone;
      if (phone.startsWith('010')) {
        formatted = '+82${phone.substring(1)}';
      } else if (!phone.startsWith('+')) {
        formatted = '+82$phone';
      }

      // Firebase UID로 Supabase shops 직접 관리 (Supabase Auth 사용 안 함)
      final shopId = fbUser.uid;

      // SharedPreferences에 shop_id 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.shop_id', shopId);
      await prefs.setString('flutter.firebase_uid', shopId);
      await prefs.setString('flutter.owner_phone', formatted);

      // shops 테이블에 업소 등록 (없으면)
      final existing = await supabase
          .from('shops')
          .select('id')
          .eq('id', shopId)
          .maybeSingle();

      if (existing == null) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = '업소명을 입력하세요';
            });
          }
          return;
        }
        try {
          await supabase.from('shops').insert({
            'id': shopId,
            'name': name,
            'owner_phone': formatted,
            'password_hash': '-',
          });
          debugPrint('✅ Shop inserted: $shopId / $name / $formatted');
        } catch (e) {
          debugPrint('❌ Shop insert 실패: $e');
          if (mounted) {
            setState(() {
              _loading = false;
              _error = '업소 등록 실패: $e';
            });
          }
          return;
        }
      }

      // 추천코드 적용
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty) {
        final alreadyReferred = await SupabaseService.hasBeenReferred(shopId);
        if (alreadyReferred) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ 이미 추천코드를 사용하셨습니다.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFFFF3B30),
              ),
            );
          }
        } else {
          final applyResult = await SupabaseService.applyReferral(referralCode, shopId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(applyResult['success'] == true
                    ? '✅ 추천코드가 적용되었습니다! 첫 달 50% 할인!'
                    : '❌ 추천코드 적용 실패: ${applyResult['error'] ?? '유효하지 않은 코드'}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: applyResult['success'] == true
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
            );
          }
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '로그인 실패: $e';
          _loading = false;
        });
      }
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
                  child: Image.asset('assets/logo.png', width: 64, height: 64),
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
                      setState(() {
                        _otpSent = false;
                        _verificationId = null;
                      });
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
