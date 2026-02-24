import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<Map<String, dynamic>> _notices = [];
  bool _loading = true;

  static const categoryIcons = {
    '공지': '📢',
    '업데이트': '🆕',
    '이벤트': '🎉',
    '점검': '🔧',
  };

  static const categoryColors = {
    '공지': Color(0xFFFF3B30),
    '업데이트': Color(0xFF007AFF),
    '이벤트': Color(0xFFFF9500),
    '점검': Color(0xFF8E8E93),
  };

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('notices')
          .select()
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(50);
      setState(() {
        _notices = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  void _showDetail(Map<String, dynamic> notice) {
    final category = notice['category'] ?? '공지';
    final color = categoryColors[category] ?? const Color(0xFFFF3B30);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 카테고리 + 날짜
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${categoryIcons[category] ?? '📢'} $category',
                      style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(notice['created_at']),
                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 제목
              Text(
                notice['title'] ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              // 내용
              Text(
                notice['content'] ?? '',
                style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.7),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('공지사항', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
          : _notices.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📢', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('공지사항이 없습니다', style: TextStyle(color: Colors.white38, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotices,
                  color: const Color(0xFFFF3B30),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _notices.length,
                    itemBuilder: (context, index) {
                      final notice = _notices[index];
                      final category = notice['category'] ?? '공지';
                      final color = categoryColors[category] ?? const Color(0xFFFF3B30);
                      final isPinned = notice['is_pinned'] == true;

                      return GestureDetector(
                        onTap: () => _showDetail(notice),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPinned
                                ? color.withOpacity(0.08)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPinned
                                  ? color.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${categoryIcons[category] ?? '📢'} $category',
                                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (isPinned) ...[
                                    const SizedBox(width: 6),
                                    const Text('📌', style: TextStyle(fontSize: 12)),
                                  ],
                                  const Spacer(),
                                  Text(
                                    _formatDate(notice['created_at']),
                                    style: const TextStyle(fontSize: 11, color: Colors.white24),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                notice['title'] ?? '',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notice['content'] ?? '',
                                style: const TextStyle(fontSize: 13, color: Colors.white38),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
