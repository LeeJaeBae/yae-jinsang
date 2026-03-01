import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class MyTagsScreen extends StatefulWidget {
  const MyTagsScreen({super.key});

  @override
  State<MyTagsScreen> createState() => _MyTagsScreenState();
}

class _MyTagsScreenState extends State<MyTagsScreen> {
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _filterTag = '전체';

  String _shopId = '';

  static const tagEmojis = {
    '폭력': '👊',
    '먹튀': '💸',
    '행패': '🤬',
    '스토커': '👁️',
    '블랙': '⛔',
  };

  static const tagColors = {
    '폭력': Color(0xFFFF3B30),
    '먹튀': Color(0xFFFF9500),
    '행패': Color(0xFFFF2D55),
    '스토커': Color(0xFF8E8E93),
    '블랙': Color(0xFF000000),
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('flutter.shop_id') ?? '';
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _loading = true);
    try {
      final tags = await SupabaseService.getMyTags(_shopId);
      setState(() {
        _tags = tags;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('불러오기 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF3B30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    _filtered = _tags.where((t) {
      final matchTag = _filterTag == '전체' || t['tag'] == _filterTag;
      final matchSearch = query.isEmpty ||
          (t['phone_hash'] as String).contains(query) ||
          (t['phone_display'] ?? '').toString().contains(query) ||
          (t['phone_last4'] ?? '').toString().contains(query) ||
          (t['tag'] as String).toLowerCase().contains(query) ||
          (t['memo'] ?? '').toString().toLowerCase().contains(query);
      return matchTag && matchSearch;
    }).toList();
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('태그 삭제'),
        content: Text('${tag['tag']} 태그를 삭제하시겠습니까?'),
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
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteTag(tag['id'].toString());
        setState(() {
          _tags.removeWhere((t) => t['id'] == tag['id']);
          _applyFilter();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ 삭제 완료'),
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
              content: Text('삭제 실패: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _editTag(Map<String, dynamic> tag) async {
    final memoController = TextEditingController(text: tag['memo'] ?? '');
    String selectedTag = tag['tag'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('태그 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '번호: ${_displayPhone(tag)}',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 16),
              const Text('태그', style: TextStyle(fontSize: 13, color: Colors.white54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...tagEmojis.entries.map((e) {
                    final isSelected = selectedTag == e.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedTag = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (tagColors[e.key] ?? const Color(0xFFFF3B30)).withOpacity(0.25)
                              : const Color(0xFF252525),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (tagColors[e.key] ?? const Color(0xFFFF3B30)).withOpacity(0.6)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          '${e.value} ${e.key}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              const Text('메모', style: TextStyle(fontSize: 13, color: Colors.white54)),
              const SizedBox(height: 8),
              TextField(
                controller: memoController,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '메모 입력 (선택)',
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
              onPressed: () => Navigator.pop(context, {
                'tag': selectedTag,
                'memo': memoController.text.trim(),
              }),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await Supabase.instance.client.from('tags').update({
          'tag': result['tag'],
          'memo': result['memo']!.isEmpty ? null : result['memo'],
        }).eq('id', tag['id']);

        await _loadTags();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ 수정 완료'),
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
              content: Text('수정 실패: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Set<String> get _uniqueTags {
    return {'전체', ..._tags.map((t) => t['tag'] as String)};
  }

  String _getEmoji(String tag) => tagEmojis[tag] ?? '⚠️';

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _maskHash(String hash) {
    if (hash.length < 12) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  String _displayPhone(Map<String, dynamic> tag) {
    final display = tag['phone_display'] as String?;
    if (display != null && display.isNotEmpty) return display;
    final last4 = tag['phone_last4'] as String?;
    if (last4 != null && last4.isNotEmpty) {
      return '***-****-$last4';
    }
    return _maskHash(tag['phone_hash'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('내 태그 관리', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadTags,
            icon: const Icon(Icons.refresh, color: Colors.white54),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 + 필터
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilter),
              decoration: InputDecoration(
                hintText: '태그, 메모로 검색',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 태그 필터 칩
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: _uniqueTags.map((tag) {
                final isSelected = _filterTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _filterTag = tag;
                      _applyFilter();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF3B30).withOpacity(0.2)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF3B30).withOpacity(0.5)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        tag == '전체' ? '전체 (${_tags.length})' : '${_getEmoji(tag)} $tag',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : Colors.white54,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 결과 카운트
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filtered.length}건',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
          ),

          // 리스트
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🛡️', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              _tags.isEmpty ? '등록된 태그가 없습니다' : '검색 결과가 없습니다',
                              style: const TextStyle(color: Colors.white38, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTags,
                        color: const Color(0xFFFF3B30),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final tag = _filtered[index];
                            final tagName = tag['tag'] as String;
                            final hash = tag['phone_hash'] as String;
                            final memo = tag['memo'] as String?;
                            final created = tag['created_at'] as String?;
                            final color = tagColors[tagName] ?? const Color(0xFFFF3B30);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(_getEmoji(tagName), style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tagName,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _displayPhone(tag),
                                        style: const TextStyle(fontSize: 12, color: Colors.white38, fontFamily: 'monospace'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (memo != null && memo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '📝 $memo',
                                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        _formatDate(created),
                                        style: const TextStyle(fontSize: 11, color: Colors.white24),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                                  color: const Color(0xFF252525),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) {
                                    if (value == 'edit') _editTag(tag);
                                    if (value == 'delete') _deleteTag(tag);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                                          SizedBox(width: 10),
                                          Text('수정'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF3B30)),
                                          SizedBox(width: 10),
                                          Text('삭제', style: TextStyle(color: Color(0xFFFF3B30))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
