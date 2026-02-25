import 'dart:async';
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
import 'screens/notices_screen.dart';
import 'services/update_service.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool? _hasSubscription;
  bool _loading = true;
  bool? _onboardingDone;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
    _checkSubscription();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkSubscription());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSubscription();
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _onboardingDone = prefs.getBool('onboarding_done') ?? false);
  }

  Future<void> _checkSubscription() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() { _hasSubscription = null; _loading = false; });
      return;
    }

    // Kotlin CallScreeningService에서 구독 체크용
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_user_id', session.user.id);

    try {
      final shop = await Supabase.instance.client
          .from('shops')
          .select('subscription_until, is_active')
          .eq('id', session.user.id)
          .maybeSingle();

      final isActive = shop?['is_active'] == true;
      final until = shop?['subscription_until'];
      final valid = isActive &&
          until != null &&
          DateTime.tryParse(until)?.isAfter(DateTime.now()) == true;

      if (mounted) setState(() { _hasSubscription = valid; _loading = false; });
    } catch (e) {
      debugPrint('구독 체크 실패: $e');
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // 온보딩 (로그인 전에 보여줌)
        if (_onboardingDone == false) {
          return OnboardingScreen(onComplete: () {
            setState(() => _onboardingDone = true);
          });
        }

        if (session == null) return const AuthScreen();

        if (_loading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
          );
        }

        if (_hasSubscription == true) return _homePage;
        return const PaywallScreen();
      },
    );
  }

  // HomePage 인스턴스 캐시 — StreamBuilder 리빌드 시 state 유지
  static const _homePage = HomePage();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
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

  bool _showHomeTutorial = false;
  int _tutorialStep = 0;

  // 코치마크용 GlobalKey
  final _keyScreeningCard = GlobalKey();
  final _keyTagManage = GlobalKey();
  final _keyRecommend = GlobalKey();
  final _keyPhoneInput = GlobalKey();
  final _keyTagChips = GlobalKey();
  final _keyRegisterBtn = GlobalKey();
  final _keyTagList = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForRegisterPhone();
    _loadTagsFromSupabase();
    _checkPendingPhone();
    // 네이티브 채널 준비 후 상태 체크
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkScreeningStatus();
        _checkOverlayPermission();
      }
    });
    // 업데이트 체크
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) UpdateService.checkForUpdate(context);
    });
    // 홈 튜토리얼 체크
    _checkHomeTutorial();
    // shop_id를 SharedPreferences에 저장 (Kotlin에서 구독 체크용)
    _saveShopId();
  }

  Future<void> _saveShopId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_id', _shopId);
  }

  Future<void> _checkHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('home_tutorial_done') ?? false;
    if (!done && mounted) {
      // 약간 딜레이 줘서 화면 렌더링 후 표시
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showHomeTutorial = true);
      });
    }
  }

  Future<void> _finishHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_tutorial_done', true);
    if (mounted) setState(() => _showHomeTutorial = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkScreeningStatus();
      _checkOverlayPermission();
    }
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

  /// 네이티브에서 실시간으로 전화번호 등록 요청 + 스크리닝 상태 수신
  void _listenForRegisterPhone() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onRegisterPhone') {
        final phone = call.arguments as String?;
        if (phone != null && phone.isNotEmpty && mounted) {
          _showQuickRegisterDialog(phone);
        }
      } else if (call.method == 'onScreeningStateChanged') {
        final enabled = call.arguments as bool? ?? false;
        if (mounted) setState(() => _screeningEnabled = enabled);
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
          phoneDisplay: t['phone_display'] as String?,
          phoneLast4: t['phone_last4'] as String?,
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
      print('🔴 isScreeningEnabled 결과: $result (type: ${result.runtimeType})');
      if (mounted) setState(() => _screeningEnabled = result == true);
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
    // 이미 활성화면 스낵바로 알림
    if (_screeningEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ 이미 기본 전화 스크리닝 앱으로 등록되어 있습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF34C759),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }
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
    List<Contact> contacts;
    try {
      // 권한 체크 우회 — 직접 로드 시도
      await FlutterContacts.requestPermission();
      contacts = await FlutterContacts.getContacts(withProperties: true);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('📋 연락처 권한 필요'),
            content: Text(
              '연락처에서 진상을 불러오려면 권한이 필요합니다.\n\n'
              '설정 → 권한 → 연락처 → 허용\n\n'
              '오류: $e',
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  platform.invokeMethod('openAppSettings').catchError((_) {});
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
      }
      return;
    }
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
        onSelectMultiple: (selectedContacts) {
          Navigator.pop(context);
          _showBatchImportDialog(selectedContacts);
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

  /// 연락처 이름+메모에서 태그 자동 감지
  static const _tagKeywords = {
    '폭력': ['폭력', '때림', '주먹', '폭행', '때리'],
    '먹튀': ['먹튀', '외상', '떼먹', '안냄', '미지급'],
    '행패': ['행패', '난동', '취객', '행패부림'],
    '스토커': ['스토커', '스토킹', '집착', '찾아옴'],
    '블랙': ['진상', '블랙리스트', '출입금지', '출금'],
  };

  /// 태그 + 매칭 키워드 리턴
  ({String tag, String keyword})? _autoDetectTag(Contact contact) {
    final notes = contact.notes.map((n) => n.note).join(' ').toLowerCase();
    if (notes.isEmpty) return null;

    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (notes.contains(keyword)) return (tag: entry.key, keyword: keyword);
      }
    }
    return null;
  }

  bool _hasJinsangHint(Contact contact) {
    if (contact.notes.isNotEmpty && contact.notes.first.note.trim().isNotEmpty) {
      return true;
    }
    return _autoDetectTag(contact) != null;
  }

  void _showBatchImportDialog(List<Contact> contacts) {
    // 자동 분류: 힌트 있는 연락처만 추출
    final classified = <_ClassifiedContact>[];
    final skipped = <Contact>[];

    for (final c in contacts) {
      if (_hasJinsangHint(c)) {
        final detected = _autoDetectTag(c);
        final memo = c.notes.isNotEmpty ? c.notes.first.note.trim() : null;
        classified.add(_ClassifiedContact(
          contact: c,
          tag: detected?.tag ?? '블랙',
          memo: memo,
          autoDetected: detected != null,
          matchedKeyword: detected?.keyword,
        ));
      } else {
        skipped.add(c);
      }
    }

    if (classified.isEmpty) {
      // 힌트 있는 연락처가 없으면 수동 모드로 전환
      _showManualBatchDialog(contacts);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BatchClassifyScreen(
          classified: classified,
          skipped: skipped,
          allContacts: contacts,
          presetTags: presetTags,
          shopId: _shopId,
          onComplete: () {
            _loadTagsFromSupabase();
          },
          onManualMode: () {
            _showManualBatchDialog(contacts);
          },
        ),
      ),
    );
  }

  /// 힌트 없는 연락처 수동 일괄 등록
  void _showManualBatchDialog(List<Contact> contacts) {
    String selectedTag = _selectedTag;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🚨 ${contacts.length}명 수동 등록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  contacts.map((c) => c.displayName).join(', '),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              const Text('전체 적용 태그', style: TextStyle(fontSize: 13, color: Colors.white54)),
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
                int count = 0;
                for (final contact in contacts) {
                  final phones = contact.phones.map((p) => p.number).toList();
                  final noteText = contact.notes.isNotEmpty ? contact.notes.first.note.trim() : null;
                  for (final phone in phones) {
                    try {
                      await SupabaseService.addTag(
                        shopId: _shopId,
                        phone: phone,
                        tag: selectedTag,
                        memo: noteText?.isNotEmpty == true ? noteText : null,
                      );
                      count++;
                    } catch (_) {}
                  }
                }
                await _loadTagsFromSupabase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ $count건 등록 완료'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF34C759),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('${contacts.length}명 등록'),
            ),
          ],
        ),
      ),
    );
  }

  static String _getTagEmojiStatic(String tag) {
    const map = {
      '폭력': '👊', '먹튀': '💸', '행패': '🤬',
      '스토커': '👁️', '블랙': '⛔',
    };
    return map[tag] ?? '⚠️';
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
        content: Text('${_maskPhone(tag)} 삭제됨'),
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
    return Stack(
      children: [
        Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset('assets/logo.png', width: 28, height: 28),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '얘진상',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'v1.1.0',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 아이콘 2개만 헤더에 (프로필 + 공지)
                        SizedBox(
                          width: 36, height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NoticesScreen()),
                              );
                            },
                            icon: const Icon(Icons.campaign_outlined, color: Colors.white54, size: 22),
                            tooltip: '공지사항',
                          ),
                        ),
                        SizedBox(
                          width: 36, height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              );
                            },
                            icon: const Icon(Icons.person_outline, color: Colors.white54, size: 22),
                            tooltip: '내 정보',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 퀵 액션 바
                    Row(
                      children: [
                        Expanded(
                          key: _keyTagManage,
                          child: _QuickActionButton(
                            icon: Icons.list_alt,
                            label: '태그 관리',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MyTagsScreen()),
                              );
                              _loadTagsFromSupabase();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          key: _keyRecommend,
                          child: _QuickActionButton(
                            icon: Icons.card_giftcard,
                            label: '추천하기',
                            color: const Color(0xFFFF6B6B),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReferralScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 스크리닝 상태 (꺼져있을 때만)
            if (!_screeningEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                  child: GestureDetector(
                    onTap: _requestScreeningRole,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                                    ? '탭하여 기본 전화 앱 재등록'
                                    : '전화 스크리닝을 활성화하세요',
                                style: const TextStyle(fontSize: 13, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _screeningEnabled ? Icons.refresh : Icons.arrow_forward_ios,
                          color: Colors.white38,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 오버레이 권한
            if (!_overlayEnabled)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
              key: _keyPhoneInput,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                      key: _keyRegisterBtn,
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
              key: _keyTagList,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      _maskPhone(tag),
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
    ),
        if (_showHomeTutorial) _buildTutorialOverlay(),
      ],
    );
  }

  List<_CoachStep> get _coachSteps => [
    _CoachStep(key: _keyTagManage, title: '🏷️ 태그 관리', desc: '등록한 진상 목록을 검색하고\n태그별로 필터링할 수 있어요.'),
    _CoachStep(key: _keyRecommend, title: '🤝 추천하기', desc: '동료 사장님에게 추천하면\n1개월 무료 혜택을 받아요!'),
    _CoachStep(key: _keyPhoneInput, title: '📝 진상 등록', desc: '전화번호 입력 후 태그를 선택해서\n진상을 등록하세요.'),
    _CoachStep(key: _keyRegisterBtn, title: '✅ 등록 버튼', desc: '번호와 태그를 선택한 후\n여기를 눌러 등록 완료!'),
    _CoachStep(key: _keyTagList, title: '📋 등록 목록', desc: '내가 등록한 진상 목록이에요.\n좌로 밀면 삭제할 수 있어요.'),
  ];

  Rect? _getWidgetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(offset.dx, offset.dy, renderBox.size.width, renderBox.size.height);
  }

  Widget _buildTutorialOverlay() {
    final step = _coachSteps[_tutorialStep];
    final rect = _getWidgetRect(step.key);

    return GestureDetector(
      onTap: () {
        if (_tutorialStep < _coachSteps.length - 1) {
          setState(() => _tutorialStep++);
        } else {
          _finishHomeTutorial();
        }
      },
      child: Stack(
        children: [
          // 반투명 배경 (하이라이트 영역 빼고)
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _SpotlightPainter(
              target: rect,
              padding: 8,
            ),
          ),

          // 툴팁 말풍선
          if (rect != null)
            Positioned(
              left: 24,
              right: 24,
              top: _tooltipTop(rect),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 위에 표시할 때 화살표
                  if (rect.top > MediaQuery.of(context).size.height * 0.5)
                    _buildTooltipCard(step)
                  else ...[
                    // 아래에 표시
                  ],

                  if (rect.top <= MediaQuery.of(context).size.height * 0.5)
                    _buildTooltipCard(step),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _tooltipTop(Rect rect) {
    final screenH = MediaQuery.of(context).size.height;
    // 대상이 화면 상반부면 아래에 표시, 하반부면 위에 표시
    if (rect.top <= screenH * 0.5) {
      return rect.bottom + 16;
    } else {
      // 툴팁이 대상 위에 → 대략 계산
      return rect.top - 160;
    }
  }

  Widget _buildTooltipCard(_CoachStep step) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            step.desc,
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 인디케이터
              Row(
                children: List.generate(_coachSteps.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _tutorialStep == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _tutorialStep == i ? const Color(0xFFFF3B30) : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              Text(
                _tutorialStep < _coachSteps.length - 1 ? '탭 → 다음' : '탭 → 완료 ✓',
                style: TextStyle(
                  fontSize: 13,
                  color: _tutorialStep < _coachSteps.length - 1 ? Colors.white38 : const Color(0xFF34C759),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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

  String _maskPhone(JinsangTag tag) {
    if (tag.phoneDisplay != null && tag.phoneDisplay!.isNotEmpty) return tag.phoneDisplay!;
    if (tag.phoneLast4 != null && tag.phoneLast4!.isNotEmpty) return '***-****-${tag.phoneLast4}';
    final phone = tag.phone;
    if (phone.length > 20) return '${phone.substring(0, 6)}...${phone.substring(phone.length - 4)}';
    if (phone.length >= 8) return '${phone.substring(0, phone.length - 4)}****';
    return phone;
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _BatchClassifyScreen extends StatefulWidget {
  final List<_ClassifiedContact> classified;
  final List<Contact> skipped;
  final List<Contact> allContacts;
  final List<TagOption> presetTags;
  final String shopId;
  final VoidCallback onComplete;
  final VoidCallback onManualMode;

  const _BatchClassifyScreen({
    required this.classified,
    required this.skipped,
    required this.allContacts,
    required this.presetTags,
    required this.shopId,
    required this.onComplete,
    required this.onManualMode,
  });

  @override
  State<_BatchClassifyScreen> createState() => _BatchClassifyScreenState();
}

class _BatchClassifyScreenState extends State<_BatchClassifyScreen> {
  late List<_ClassifiedContact> _items;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.classified);
  }

  static String _getEmoji(String tag) {
    const map = {'폭력': '👊', '먹튀': '💸', '행패': '🤬', '스토커': '👁️', '블랙': '⛔'};
    return map[tag] ?? '⚠️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('🤖 자동 분류 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (widget.skipped.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onManualMode();
              },
              child: const Text('전체 수동', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 요약 바
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFF34C759).withOpacity(0.15), const Color(0xFF1A1A1A)],
              ),
              border: Border.all(color: const Color(0xFF34C759).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF34C759)),
                const SizedBox(width: 10),
                Text(
                  '등록 ${_items.length}명',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF34C759)),
                ),
                if (widget.skipped.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    '스킵 ${widget.skipped.length}명',
                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                  ),
                ],
              ],
            ),
          ),

          // 분류 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length + (widget.skipped.isNotEmpty ? 1 + widget.skipped.length : 0),
              itemBuilder: (context, index) {
                // 등록 대상
                if (index < _items.length) {
                  final item = _items[index];
                  final phone = item.contact.phones.isNotEmpty ? item.contact.phones.first.number : '';
                  final reason = item.autoDetected
                      ? '메모에서 "${item.matchedKeyword}" 감지'
                      : (item.memo != null ? '메모 있음 (키워드 미감지)' : '수동 분류');

                  return Dismissible(
                    key: Key('classified_${item.contact.id}_$index'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      setState(() {
                        final removed = _items.removeAt(index);
                        widget.skipped.add(removed.contact);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.contact.displayName} → 스킵으로 이동'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          action: SnackBarAction(
                            label: '되돌리기',
                            onPressed: () {
                              setState(() {
                                widget.skipped.remove(item.contact);
                                _items.insert(index.clamp(0, _items.length), item);
                              });
                            },
                          ),
                        ),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('스킵', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이름 + 태그
                        Row(
                          children: [
                            Text(_getEmoji(item.tag), style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.contact.displayName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  if (phone.isNotEmpty)
                                    Text(phone, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                                ],
                              ),
                            ),
                            // 태그 변경
                            PopupMenuButton<String>(
                              initialValue: item.tag,
                              onSelected: (tag) => setState(() {
                                _items[index] = _ClassifiedContact(
                                  contact: item.contact,
                                  tag: tag,
                                  memo: item.memo,
                                  autoDetected: false,
                                  matchedKeyword: item.matchedKeyword,
                                );
                              }),
                              itemBuilder: (_) => [
                                for (final t in widget.presetTags)
                                  PopupMenuItem(value: t.name, child: Text('${t.emoji} ${t.name}')),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(item.tag, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white38),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 분류 사유
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.autoDetected
                                ? const Color(0xFFFF9500).withOpacity(0.1)
                                : const Color(0xFF252525),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.autoDetected ? Icons.auto_fix_high : Icons.notes,
                                size: 14,
                                color: item.autoDetected ? const Color(0xFFFF9500) : Colors.white38,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item.autoDetected ? const Color(0xFFFF9500) : Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 메모 내용
                        if (item.memo != null && item.memo!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '📝 ${item.memo}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  );
                }

                // 스킵 헤더
                if (index == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.skip_next, size: 18, color: Colors.white24),
                        const SizedBox(width: 8),
                        Text(
                          '스킵 — 메모/키워드 없음 (${widget.skipped.length}명)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white38),
                        ),
                      ],
                    ),
                  );
                }

                // 스킵된 연락처
                final skipIndex = index - _items.length - 1;
                final skippedContact = widget.skipped[skipIndex];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skippedContact.displayName,
                              style: const TextStyle(fontSize: 13, color: Colors.white38),
                            ),
                            if (skippedContact.phones.isNotEmpty)
                              Text(
                                skippedContact.phones.first.number,
                                style: const TextStyle(fontSize: 11, color: Colors.white12),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32, height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _addSkippedContact(skipIndex),
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFFFF6B6B)),
                          tooltip: '등록 추가',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 하단 등록 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0D),
              border: Border(top: BorderSide(color: Color(0xFF252525))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRegistering ? null : _registerAll,
                icon: _isRegistering
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 20),
                label: Text(
                  _isRegistering ? '등록 중...' : '${_items.length}명 등록',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  disabledBackgroundColor: const Color(0xFFFF3B30).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSkippedContact(int skipIndex) {
    final contact = widget.skipped[skipIndex];
    String selectedTag = '블랙';
    final memoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('➕ ${contact.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 전화번호
              if (contact.phones.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contact.phones.map((p) => p.number).join(', '),
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ),
              const SizedBox(height: 14),
              // 태그
              const Text('태그', style: TextStyle(fontSize: 13, color: Colors.white54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.presetTags.map((tag) {
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
              const SizedBox(height: 14),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _items.add(_ClassifiedContact(
                    contact: contact,
                    tag: selectedTag,
                    memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                    autoDetected: false,
                    matchedKeyword: null,
                  ));
                  widget.skipped.removeAt(skipIndex);
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerAll() async {
    setState(() => _isRegistering = true);
    int count = 0;
    for (final item in _items) {
      final phones = item.contact.phones.map((p) => p.number).toList();
      for (final phone in phones) {
        try {
          await SupabaseService.addTag(
            shopId: widget.shopId,
            phone: phone,
            tag: item.tag,
            memo: item.memo,
          );
          count++;
        } catch (_) {}
      }
    }
    widget.onComplete();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count건 등록 완료 (${widget.skipped.length}명 스킵)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF34C759),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _ClassifiedContact {
  final Contact contact;
  final String tag;
  final String? memo;
  final bool autoDetected;
  final String? matchedKeyword; // 어떤 키워드로 매칭됐는지

  _ClassifiedContact({
    required this.contact,
    required this.tag,
    this.memo,
    this.autoDetected = false,
    this.matchedKeyword,
  });
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JinsangTag {
  final String? id;
  final String phone;
  final String tag;
  final String? memo;
  final String? phoneDisplay;
  final String? phoneLast4;
  final DateTime addedAt;

  JinsangTag({
    this.id,
    required this.phone,
    required this.tag,
    this.memo,
    this.phoneDisplay,
    this.phoneLast4,
    required this.addedAt,
  });
}

class _CoachStep {
  final GlobalKey key;
  final String title;
  final String desc;

  _CoachStep({required this.key, required this.title, required this.desc});
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final double padding;

  _SpotlightPainter({this.target, this.padding = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.75);

    if (target == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
      return;
    }

    final spotlight = RRect.fromRectAndRadius(
      target!.inflate(padding),
      const Radius.circular(12),
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(spotlight)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, bgPaint);

    // 하이라이트 테두리
    final borderPaint = Paint()
      ..color = const Color(0xFFFF3B30).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(spotlight, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.target != target;
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
  final void Function(List<Contact>) onSelectMultiple;

  const _ContactPickerSheet({
    required this.contacts,
    required this.onSelect,
    required this.onSelectMultiple,
  });

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  List<Contact> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _multiMode = false;

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

  void _toggleSelect(Contact contact) {
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
        if (_selectedIds.isEmpty) _multiMode = false;
      } else {
        _selectedIds.add(contact.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filtered.length) {
        _selectedIds.clear();
        _multiMode = false;
      } else {
        _selectedIds.addAll(_filtered.map((c) => c.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIds.length == _filtered.length && _filtered.isNotEmpty;
    
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
                  Row(
                    children: [
                      Text(
                        '${_filtered.length}명',
                        style: const TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() => _multiMode = !_multiMode);
                          if (!_multiMode) _selectedIds.clear();
                        },
                        child: Text(
                          _multiMode ? '취소' : '선택',
                          style: TextStyle(
                            fontSize: 13,
                            color: _multiMode ? const Color(0xFFFF3B30) : Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_multiMode) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _selectAll,
                          child: Text(
                            allSelected ? '전체 해제' : '전체 선택',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                  final isSelected = _selectedIds.contains(contact.id);

                  return ListTile(
                    leading: _multiMode
                        ? Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? const Color(0xFFFF3B30) : Colors.white38,
                            size: 24,
                          )
                        : CircleAvatar(
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
                    trailing: !_multiMode && hasNote
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
                    onTap: () {
                      if (_multiMode) {
                        _toggleSelect(contact);
                      } else {
                        widget.onSelect(contact);
                      }
                    },
                    onLongPress: () {
                      if (!_multiMode) {
                        setState(() => _multiMode = true);
                        _toggleSelect(contact);
                      }
                    },
                  );
                },
              ),
            ),
            // 선택 완료 버튼
            if (_multiMode && _selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final selected = widget.contacts
                          .where((c) => _selectedIds.contains(c.id))
                          .toList();
                      widget.onSelectMultiple(selected);
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      '${_selectedIds.length}명 등록',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
