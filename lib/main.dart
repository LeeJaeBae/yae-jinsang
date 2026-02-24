import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/my_tags_screen.dart';
import 'screens/profile_screen.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const YaeJinsangApp());
}

class YaeJinsangApp extends StatelessWidget {
  const YaeJinsangApp({super.key});

  static final _theme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFF3B30),
      secondary: Color(0xFFFF6B6B),
      surface: Color(0xFF1A1A1A),
      onSurface: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF252525),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    useMaterial3: true,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '얘진상',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: const AuthGate(),
    );
  }
}

/// 인증 + 구독 상태에 따라 화면 분기
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // 미로그인
        if (session == null) {
          return const AuthScreen();
        }

        // 로그인됨 → 구독 실시간 체크
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('shops')
              .stream(primaryKey: ['id'])
              .eq('id', session.user.id),
          builder: (context, shopSnapshot) {
            if (!shopSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF0D0D0D),
                body: Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
              );
            }

            final shops = shopSnapshot.data!;
            if (shops.isEmpty) return const PaywallScreen();

            final shop = shops.first;
            final isActive = shop['is_active'] == true;
            final until = shop['subscription_until'];
            final hasSubscription = isActive &&
                until != null &&
                DateTime.tryParse(until)?.isAfter(DateTime.now()) == true;

            if (hasSubscription) {
              return const HomePage();
            }

            return const PaywallScreen();
          },
        );
      },
    );
  }

}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const platform = MethodChannel('com.thebespoke.yae_jinsang/screening');
  bool _screeningEnabled = false;
  bool _overlayEnabled = false;
  final List<JinsangTag> _tags = [];
  final _phoneController = TextEditingController();
  final _customTagController = TextEditingController();
  String _selectedTag = '폭력';
  bool _isCustomTag = false;

  final List<TagOption> presetTags = [
    TagOption('폭력', '👊', Color(0xFFFF3B30)),
    TagOption('먹튀', '💸', Color(0xFFFF9500)),
    TagOption('행패', '🤬', Color(0xFFFF2D55)),
    TagOption('스토커', '👁️', Color(0xFF8E8E93)),
    TagOption('블랙', '⛔', Color(0xFF000000)),
  ];

  String get _shopId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _checkScreeningStatus();
    _checkOverlayPermission();
    _loadTagsFromSupabase();
    _checkPendingPhone();
    _listenForRegisterPhone();
    // 앱 시작 2초 후 업데이트 체크
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) UpdateService.checkForUpdate(context);
    });
  }

  /// 앱 시작 시 pending phone 확인
  Future<void> _checkPendingPhone() async {
    try {
      final phone = await platform.invokeMethod('getPendingPhone');
      if (phone != null && phone is String && phone.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showQuickRegisterDialog(phone);
        });
      }
    } catch (e) {
      debugPrint('Pending phone 확인 실패: $e');
    }
  }

  /// 네이티브에서 실시간으로 전화번호 등록 요청 수신
  void _listenForRegisterPhone() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onRegisterPhone') {
        final phone = call.arguments as String?;
        if (phone != null && phone.isNotEmpty && mounted) {
          _showQuickRegisterDialog(phone);
        }
      }
    });
  }

  /// 빠른 진상 등록 다이얼로그
  void _showQuickRegisterDialog(String phone) {
    String selectedTag = '폭력';
    final memoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('🚨 진상 등록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 전화번호
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 18, color: Colors.white38),
                    const SizedBox(width: 8),
                    Text(
                      phone.length > 4
                          ? '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}'
                          : phone,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 태그 선택
              const Text('태그', style: TextStyle(fontSize: 13, color: Colors.white54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetTags.map((tag) {
                  final isSelected = selectedTag == tag.name;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedTag = tag.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? tag.color.withOpacity(0.25) : const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? tag.color.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        '${tag.emoji} ${tag.name}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 메모
              TextField(
                controller: memoController,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '메모 (선택)',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF252525),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await SupabaseService.addTag(
                    shopId: _shopId,
                    phone: phone,
                    tag: selectedTag,
                    memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                  );
                  await _loadTagsFromSupabase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ $selectedTag 등록 완료'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF34C759),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('등록 실패: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFFFF3B30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTagsFromSupabase() async {
    try {
      final tags = await SupabaseService.getMyTags(_shopId);
      setState(() {
        _tags.clear();
        _tags.addAll(tags.map((t) => JinsangTag(
          id: t['id'].toString(),
          phone: t['phone_hash'] as String,
          tag: t['tag'] as String,
          memo: t['memo'] as String?,
          addedAt: DateTime.tryParse(t['created_at'] ?? '') ?? DateTime.now(),
        )));
      });
    } catch (e) {
      debugPrint('태그 로드 실패: $e');
    }
  }

  Future<void> _checkScreeningStatus() async {
    try {
      final result = await platform.invokeMethod('isScreeningEnabled');
      setState(() => _screeningEnabled = result == true);
    } catch (e) {
      debugPrint('스크리닝 상태 확인 실패: $e');
    }
  }

  Future<void> _checkOverlayPermission() async {
    try {
      final result = await platform.invokeMethod('canDrawOverlays');
      setState(() => _overlayEnabled = result == true);
    } catch (e) {
      debugPrint('오버레이 권한 확인 실패: $e');
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
      await Future.delayed(const Duration(seconds: 2));
      _checkOverlayPermission();
    } catch (e) {
      debugPrint('오버레이 권한 요청 실패: $e');
    }
  }

  Future<void> _requestScreeningRole() async {
    try {
      await platform.invokeMethod('requestScreeningRole');
      await Future.delayed(const Duration(seconds: 1));
      _checkScreeningStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Android 10 이상이 필요합니다'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _openContactPicker() async {
    if (!await FlutterContacts.requestPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('연락처 접근 권한이 필요합니다'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ContactPickerSheet(
        contacts: contacts,
        onSelect: (contact) {
          Navigator.pop(context);
          _showContactImportDialog(contact);
        },
      ),
    );
  }

  void _showContactImportDialog(Contact contact) {
    final phones = contact.phones.map((p) => p.number).toList();
    if (phones.isEmpty) return;

    // 연락처 이름/메모에서 태그 자동 추출 시도
    final name = contact.displayName;
    final notes = contact.notes.map((n) => n.note).join(' ');
    final allText = '$name $notes'.toLowerCase();

    String? autoTag;
    for (final preset in presetTags) {
      if (allText.contains(preset.name)) {
        autoTag = preset.name;
        break;
      }
    }
    // 진상 관련 키워드 추가 감지
    final keywords = {
      '진상': '블랙', '블랙': '블랙', '차단': '블랙',
      '폭력': '폭력', '때': '폭력', '주먹': '폭력',
      '먹튀': '먹튀', '돈': '먹튀', '미수': '먹튀',
      '행패': '행패', '난동': '행패', '취객': '행패',
      '스토커': '스토커', '스토킹': '스토커',
    };
    if (autoTag == null) {
      for (final entry in keywords.entries) {
        if (allText.contains(entry.key)) {
          autoTag = entry.value;
          break;
        }
      }
    }

    // 전화번호가 여러 개면 전부 등록할지 물어보기
    if (autoTag != null) {
      setState(() {
        _selectedTag = autoTag!;
        _isCustomTag = false;
      });
    }

    // 메모가 있으면 커스텀 태그로 제안
    final noteText = contact.notes.isNotEmpty ? contact.notes.first.note : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📋 ${contact.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...phones.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  Text(p, style: const TextStyle(fontSize: 15)),
                ],
              ),
            )),
            if (noteText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('메모', style: TextStyle(fontSize: 12, color: Colors.white38)),
                    const SizedBox(height: 4),
                    Text(noteText, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
            if (autoTag != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '자동 감지: $autoTag',
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final tagName = autoTag ?? _selectedTag;
              final memoText = noteText.isNotEmpty ? noteText : null;
              try {
                for (final phone in phones) {
                  await SupabaseService.addTag(
                    shopId: _shopId,
                    phone: phone,
                    tag: tagName,
                    memo: memoText,
                  );
                }
                await _loadTagsFromSupabase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ${contact.displayName} — ${phones.length}개 번호 등록완료'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF34C759),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('등록 실패: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTag() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('전화번호를 입력하세요'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final tag = _isCustomTag ? _customTagController.text.trim() : _selectedTag;
    if (_isCustomTag && tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('태그를 입력하세요'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      await SupabaseService.addTag(shopId: _shopId, phone: phone, tag: tag);
      _phoneController.clear();
      _customTagController.clear();
      await _loadTagsFromSupabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $phone → $tag 등록완료'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF34C759),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _removeTag(int index) async {
    final tag = _tags[index];
    setState(() => _tags.removeAt(index));

    try {
      if (tag.id != null) {
        await SupabaseService.deleteTag(tag.id!);
      }
    } catch (e) {
      // 실패 시 복원
      setState(() => _tags.insert(index, tag));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_maskPhone(tag.phone)} 삭제됨'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () {
            // 되돌리기는 로컬만 (이미 DB에서 삭제됨 — 재등록 필요)
            setState(() => _tags.insert(index, tag));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset('assets/logo.png', width: 36, height: 36),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '얘진상',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '진상 손님 사전 차단 시스템',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyTagsScreen()),
                        );
                        _loadTagsFromSupabase();
                      },
                      icon: const Icon(Icons.list_alt, color: Colors.white54),
                      tooltip: '태그 관리',
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReferralScreen()),
                        );
                      },
                      icon: const Icon(Icons.card_giftcard, color: Color(0xFFFF6B6B)),
                      tooltip: '추천하기',
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_outline, color: Colors.white54),
                      tooltip: '내 정보',
                    ),
                  ],
                ),
              ),
            ),

            // 스크리닝 상태
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _screeningEnabled
                          ? [const Color(0xFF1B3A2D), const Color(0xFF0D2818)]
                          : [const Color(0xFF3A1B1B), const Color(0xFF280D0D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _screeningEnabled
                          ? const Color(0xFF34C759).withOpacity(0.3)
                          : const Color(0xFFFF3B30).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (_screeningEnabled ? const Color(0xFF34C759) : const Color(0xFFFF3B30)).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _screeningEnabled ? Icons.shield : Icons.shield_outlined,
                          color: _screeningEnabled ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _screeningEnabled ? '보호 활성화' : '보호 꺼짐',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _screeningEnabled
                                  ? '수신 전화를 실시간 감시 중'
                                  : '전화 스크리닝을 활성화하세요',
                              style: const TextStyle(fontSize: 13, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      if (!_screeningEnabled)
                        FilledButton(
                          onPressed: _requestScreeningRole,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text('활성화', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 오버레이 권한
            if (!_overlayEnabled)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFFF9500).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.layers_outlined, color: Color(0xFFFF9500), size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('화면 위 표시 권한', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('전화 수신 시 경고 오버레이 표시에 필요', style: TextStyle(fontSize: 12, color: Colors.white54)),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _requestOverlayPermission,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9500),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('허용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 진상 등록 섹션
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '진상 등록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 전화번호 입력
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '전화번호 입력',
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white38, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.contacts_outlined, color: Colors.white38, size: 20),
                          onPressed: _openContactPicker,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 태그 선택 (칩)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...presetTags.map((tag) => _buildTagChip(tag)),
                        _buildCustomTagChip(),
                      ],
                    ),

                    // 직접입력 필드
                    if (_isCustomTag) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customTagController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: '태그 직접 입력 (예: 음주난동, 무단취소)',
                          hintStyle: TextStyle(color: Colors.white24),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 등록 버튼
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addTag,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('등록', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 등록 목록 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                child: Row(
                  children: [
                    const Text(
                      '등록 목록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_tags.length}',
                        style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 등록 목록 또는 빈 상태
            if (_tags.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🛡️', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text(
                        '등록된 진상이 없습니다',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '위에서 전화번호와 태그를 등록하세요',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tag = _tags[index];
                      return Dismissible(
                        key: Key('${tag.phone}_${tag.addedAt.millisecondsSinceEpoch}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeTag(index),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white70),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _getTagEmoji(tag.tag),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _maskPhone(tag.phone),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tag.tag,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatTime(tag.addedAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _tags.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(TagOption tag) {
    final selected = !_isCustomTag && _selectedTag == tag.name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTag = tag.name;
          _isCustomTag = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tag.color.withOpacity(0.25) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? tag.color.withOpacity(0.6) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTagChip() {
    return GestureDetector(
      onTap: () {
        setState(() => _isCustomTag = true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _isCustomTag ? Colors.white.withOpacity(0.15) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isCustomTag ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 14, color: _isCustomTag ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(
              '직접입력',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _isCustomTag ? FontWeight.w600 : FontWeight.w400,
                color: _isCustomTag ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTagEmoji(String tag) {
    final map = {
      '폭력': '👊',
      '먹튀': '💸',
      '행패': '🤬',
      '스토커': '👁️',
      '블랙': '⛔',
    };
    return map[tag] ?? '⚠️';
  }

  String _maskPhone(String phone) {
    // phone_hash인 경우 마스킹
    if (phone.length > 20) return '${phone.substring(0, 6)}...${phone.substring(phone.length - 4)}';
    // 일반 전화번호
    if (phone.length >= 8) return '${phone.substring(0, phone.length - 4)}****';
    return phone;
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class JinsangTag {
  final String? id;
  final String phone;
  final String tag;
  final String? memo;
  final DateTime addedAt;

  JinsangTag({
    this.id,
    required this.phone,
    required this.tag,
    this.memo,
    required this.addedAt,
  });
}

class TagOption {
  final String name;
  final String emoji;
  final Color color;

  TagOption(this.name, this.emoji, this.color);
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  final void Function(Contact) onSelect;

  const _ContactPickerSheet({required this.contacts, required this.onSelect});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  List<Contact> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.contacts;
      } else {
        _filtered = widget.contacts.where((c) {
          final name = c.displayName.toLowerCase();
          final phones = c.phones.map((p) => p.number).join(' ');
          final notes = c.notes.map((n) => n.note).join(' ').toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || phones.contains(q) || notes.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 타이틀 + 검색
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  const Text(
                    '연락처에서 불러오기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: '이름, 번호, 메모로 검색',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length}명',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
            // 리스트
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final contact = _filtered[index];
                  final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '번호 없음';
                  final hasNote = contact.notes.isNotEmpty && contact.notes.first.note.isNotEmpty;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF333333),
                      child: Text(
                        contact.displayName.isNotEmpty ? contact.displayName[0] : '?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    title: Text(
                      contact.displayName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(phone, style: const TextStyle(fontSize: 13, color: Colors.white38)),
                        if (hasNote)
                          Text(
                            '📝 ${contact.notes.first.note}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: hasNote
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '메모있음',
                              style: TextStyle(fontSize: 11, color: Color(0xFFFF6B6B)),
                            ),
                          )
                        : null,
                    onTap: () => widget.onSelect(contact),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
