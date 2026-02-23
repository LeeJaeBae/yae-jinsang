import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const _supabaseUrl = 'https://jwxwjgcbarbfigucarod.supabase.co';
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp3eHdqZ2NiYXJiZmlndWNhcm9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjUyNTgsImV4cCI6MjA4NzQ0MTI1OH0.YtAbcj3j2AMTgV_iwi9ZgII8x0py0JTShsh0qX-FBGs';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  /// 전화번호 → SHA-256 해시
  static String hashPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  /// 진상 태그 등록
  static Future<void> addTag({
    required String shopId,
    required String phone,
    required String tag,
    String? memo,
  }) async {
    await client.from('tags').insert({
      'shop_id': shopId,
      'phone_hash': hashPhone(phone),
      'tag': tag,
      'memo': memo,
    });
  }

  /// 진상 조회 (해시 매칭)
  static Future<List<Map<String, dynamic>>> lookupJinsang(String phone) async {
    final hash = hashPhone(phone);
    final response = await client.rpc('lookup_jinsang', params: {'p_hash': hash});
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 내 업소 태그 목록
  static Future<List<Map<String, dynamic>>> getMyTags(String shopId) async {
    final response = await client
        .from('tags')
        .select()
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// 태그 삭제
  static Future<void> deleteTag(String tagId) async {
    await client.from('tags').delete().eq('id', tagId);
  }

  /// 내 추천코드 가져오기
  static Future<String?> getMyReferralCode(String shopId) async {
    final response = await client
        .from('shops')
        .select('referral_code')
        .eq('id', shopId)
        .maybeSingle();
    return response?['referral_code'];
  }

  /// 추천코드 적용
  static Future<Map<String, dynamic>> applyReferral(String code, String shopId) async {
    final response = await client.rpc('apply_referral', params: {
      'p_code': code,
      'p_new_shop_id': shopId,
    });
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {'success': false, 'error': '알 수 없는 오류'};
  }

  /// 내 추천 현황
  static Future<int> getReferralCount(String shopId) async {
    final response = await client
        .from('referrals')
        .select('id')
        .eq('referrer_shop_id', shopId);
    return (response as List).length;
  }

  /// 조회 로그 기록
  static Future<void> logLookup({
    required String shopId,
    required String phone,
    required bool matched,
  }) async {
    await client.from('lookup_logs').insert({
      'shop_id': shopId,
      'phone_hash': hashPhone(phone),
      'matched': matched,
    });
  }
}
