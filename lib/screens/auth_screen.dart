import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  SupabaseClient get supabase => Supabase.instance.client;

  Future<void> _login() async {
    final loginId = _idController.text.trim();
    final pw = _pwController.text.trim();

    if (loginId.isEmpty || pw.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력하세요');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final pwHash = sha256.convert(utf8.encode(pw)).toString();

      final res = await supabase
          .from('shops')
          .select('id, name, login_id, password_hash')
          .eq('login_id', loginId)
          .eq('password_hash', pwHash)
          .maybeSingle();

      if (res == null) {
        if (mounted) setState(() { _error = '아이디 또는 비밀번호가 틀렸습니다'; _loading = false; });
        return;
      }

      // 로그인 성공 → SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.shop_id', res['id']);
      await prefs.setString('flutter.shop_name', res['name'] ?? '');
      await prefs.setBool('flutter.logged_in', true);

      if (mounted) setState(() => _loading = false);
      // main.dart의 StreamBuilder 대신 ValueNotifier로 감지하므로 페이지 전환 필요
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) setState(() { _error = '로그인 실패: $e'; _loading = false; });
    }
  }

  void _openTelegram() async {
    final uri = Uri.parse('https://t.me/yae_jinsang');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                const Text(
                  '진상 손님 사전 차단 시스템',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 48),

                // 아이디
                TextField(
                  controller: _idController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '아이디',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.white38, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 비밀번호
                TextField(
                  controller: _pwController,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 16),
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white24, size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

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

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      disabledBackgroundColor: const Color(0xFFFF3B30).withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                // 구분선
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('아직 계정이 없으신가요?', style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),

                const SizedBox(height: 24),

                // 텔레그램 가입 신청
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openTelegram,
                    icon: const Text('✈️', style: TextStyle(fontSize: 18)),
                    label: const Text('텔레그램으로 가입 신청', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF29B6F6),
                      side: const BorderSide(color: Color(0xFF29B6F6), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF29B6F6).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '가입 방법',
                        style: TextStyle(color: Color(0xFF29B6F6), fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '텔레그램 @yae_jinsang 으로\n업소명과 전화번호를 보내주세요.\n확인 후 아이디/비밀번호를 발급해드립니다.',
                        style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
