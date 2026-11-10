import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';

String _topicLabel(String t) => switch (t) {
      'places' => 'Quán ngon, deal tốt',
      'experience' => 'Kinh nghiệm chi tiêu',
      'difficulty' => 'Khó khăn tài chính',
      'question' => 'Hỏi đáp',
      _ => t,
    };

/// Màn test bảng tin cộng đồng — `GET/POST /api/v1/community/posts` + điều hướng sang Quán/Hồ sơ.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String? _topic;
  String _sort = 'new';

  CommunityFeedFilter get _filter => (topic: _topic, sort: _sort, mine: false);

  Future<void> _createPost(BuildContext context) async {
    final topicsAsync = ref.read(communityTopicsProvider);
    final topics = topicsAsync.value;
    if (topics == null || topics.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chưa tải được danh sách chủ đề, thử lại sau.')));
      return;
    }
    String topic = topics.first.code;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Đăng bài'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('community-post-topic'),
                  initialValue: topic,
                  items: topics.map((t) => DropdownMenuItem(value: t.code, child: Text(_topicLabel(t.code)))).toList(),
                  onChanged: (v) => setState(() => topic = v ?? topic),
                  decoration: const InputDecoration(labelText: 'Chủ đề'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('community-post-title'),
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Tiêu đề (tùy chọn)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('community-post-body'),
                  controller: bodyCtrl,
                  decoration: const InputDecoration(labelText: 'Nội dung'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng')),
          ],
        ),
      ),
    );

    if (submitted != true || !context.mounted) return;
    try {
      final create = ref.read(communityCreatePostActionProvider);
      final post = await create(
        topic: topic,
        title: titleCtrl.text.isEmpty ? null : titleCtrl.text,
        body: bodyCtrl.text,
      );
      ref.invalidate(communityFeedProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng bài.')));
        context.push('/community-post', extra: post.id);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(communityTopicsProvider);
    final feedAsync = ref.watch(communityFeedProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng đồng'),
        actions: [
          IconButton(
            key: const ValueKey('community-open-places'),
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Quán',
            onPressed: () => context.push('/community-places'),
          ),
          IconButton(
            key: const ValueKey('community-open-profile'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Hồ sơ cộng đồng',
            onPressed: () => context.push('/community-profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('community-create-post'),
        onPressed: () => _createPost(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: topicsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (topics) => DropdownButtonFormField<String?>(
                      key: const ValueKey('community-filter-topic'),
                      initialValue: _topic,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả chủ đề')),
                        for (final t in topics) DropdownMenuItem(value: t.code, child: Text(_topicLabel(t.code))),
                      ],
                      onChanged: (v) => setState(() => _topic = v),
                      decoration: const InputDecoration(labelText: 'Chủ đề'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<String>(
                  key: const ValueKey('community-filter-sort'),
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('Mới nhất')),
                    DropdownMenuItem(value: 'top', child: Text('Nổi bật')),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? 'new'),
                ),
              ],
            ),
          ),
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage(e), textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(communityFeedProvider(_filter)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (page) {
                final items = page.items.where((p) => !p.isSpentHereOnly).toList();
                if (items.isEmpty) {
                  return const Center(child: Text('Chưa có bài nào.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return ListTile(
                      key: ValueKey('community-post-${p.id}'),
                      title: Text(p.title?.isNotEmpty == true ? p.title! : p.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${_topicLabel(p.topic)} • ${p.author.isAnonymous ? "Ẩn danh" : (p.author.displayName ?? "")} • ${p.createdOn.toString().split(" ").first}'),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.votedByMe ? Icons.favorite : Icons.favorite_border,
                              size: 18, color: p.votedByMe ? AppColors.danger : null),
                          Text('${p.voteCount}'),
                        ],
                      ),
                      onTap: () => context.push('/community-post', extra: p.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
