import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedRegion;
  String? _selectedCategory;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _shopData;

  String get _shopId => Supabase.instance.client.auth.currentUser!.id;
  String? get _phone => Supabase.instance.client.auth.currentUser?.phone;

  static const regions = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
    '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  static const categories = [
    '노래방', '클럽', '바', '라운지', '룸살롱', '가라오케',
    '마사지', '스파', '기타',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('shops')
          .select()
          .eq('id', _shopId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _shopData = data;
          _nameController.text = data['name'] ?? '';
          _selectedRegion = data['region'];
          _selectedCategory = data['category'];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 로드 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('업소명을 입력하세요'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await Supabase.instance.client.from('shops').update({
        'name': name,
        'region': _selectedRegion,
        'category': _selectedCategory,
      }).eq('id', _shopId);

      setState(() => _saving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ 저장 완료'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF34C759),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  String _subscriptionStatus() {
    final until = _shopData?['subscription_until'];
    if (until == null) return '미구독';
    final dt = DateTime.tryParse(until);
    if (dt == null) return '미구독';
    if (dt.isBefore(DateTime.now())) return '만료됨';
    return '${_formatDate(until)}까지';
  }

  Color _subscriptionColor() {
    final until = _shopData?['subscription_until'];
    if (until == null) return const Color(0xFFFF3B30);
    final dt = DateTime.tryParse(until);
    if (dt == null || dt.isBefore(DateTime.now())) return const Color(0xFFFF3B30);
    return const Color(0xFF34C759);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('내 업소 정보', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 구독 상태 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _subscriptionColor().withOpacity(0.15),
                          _subscriptionColor().withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _subscriptionColor().withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _subscriptionColor() == const Color(0xFF34C759)
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _subscriptionColor(),
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('구독 상태', style: TextStyle(fontSize: 13, color: Colors.white54)),
                            Text(
                              _subscriptionStatus(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _subscriptionColor(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 연락처 (읽기 전용)
                  const Text('연락처', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.white38),
                        const SizedBox(width: 10),
                        Text(
                          _phone ?? '-',
                          style: const TextStyle(fontSize: 15, color: Colors.white70),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '인증됨',
                            style: TextStyle(fontSize: 11, color: Color(0xFF34C759)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 업소명
                  const Text('업소명', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '업소명 입력',
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

                  const SizedBox(height: 20),

                  // 지역
                  const Text('지역', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: regions.map((r) {
                      final selected = _selectedRegion == r;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedRegion = selected ? null : r;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFF3B30).withOpacity(0.2)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFF3B30).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected ? Colors.white : Colors.white54,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 업종
                  const Text('업종', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((c) {
                      final selected = _selectedCategory == c;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory = selected ? null : c;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFF9500).withOpacity(0.2)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFF9500).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected ? Colors.white : Colors.white54,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 추천코드
                  if (_shopData?['referral_code'] != null) ...[
                    const Text('내 추천코드', style: TextStyle(fontSize: 13, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        _shopData!['referral_code'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 가입일
                  if (_shopData?['created_at'] != null) ...[
                    const Text('가입일', style: TextStyle(fontSize: 13, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(_shopData!['created_at']),
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        disabledBackgroundColor: const Color(0xFFFF3B30).withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 로그아웃
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(fontSize: 15, color: Colors.white54),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
