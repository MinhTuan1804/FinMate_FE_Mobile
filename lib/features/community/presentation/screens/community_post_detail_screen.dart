import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';

const _reportReasons = ['scam', 'personal_info', 'harassment', 'sexual', 'spam', 'self_harm', 'other'];

String _reasonLabel(String r) => switch (r) {
      'scam' => 'Lừa đảo',
      'personal_info' => 'Lộ thông tin cá nhân',
      'harassment' => 'Quấy rối',
      'sexual' => 'Nội dung nhạy cảm',
      'spam' => 'Spam',
      'self_harm' => 'Tự hại',
      'other' => 'Khác',
      _ => r,
    };

/// Màn test chi tiết 1 bài: vote, bình luận, ảnh, báo cáo, xóa — `/api/v1/community/posts/{id}`.
class CommunityPostDetailScreen extends ConsumerWidget {
  final String postId;

  const CommunityPostDetailScreen({super.key, required this.postId});

  Future<void> _report(BuildContext context, WidgetRef ref, {String? commentId}) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Báo cáo'),
        children: [
          for (final r in _reportReasons)
            SimpleDialogOption(
              key: ValueKey('community-report-reason-$r'),
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(_reasonLabel(r)),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      final controller = ref.read(communityPostDetailControllerProvider(postId).notifier);
      if (commentId != null) {
        await controller.reportComment(commentId, reason);
      } else {
        await controller.reportPost(reason);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _addComment(BuildContext context, WidgetRef ref) async {
    final bodyCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bình luận'),
        content: TextField(key: const ValueKey('community-comment-body'), controller: bodyCtrl, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi')),
        ],
      ),
    );
    if (submitted != true || !context.mounted) return;
    try {
      await ref.read(communityPostDetailControllerProvider(postId).notifier).addComment(bodyCtrl.text);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _uploadImage(BuildContext context, WidgetRef ref) async {
    final pick = ref.read(pickCommunityImageProvider);
    final picked = await pick();
    if (picked == null || !context.mounted) return;
    try {
      await ref
          .read(communityPostDetailControllerProvider(postId).notifier)
          .uploadImage(picked.path, picked.name);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã gửi ảnh, chờ nhân viên duyệt.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(communityPostDetailControllerProvider(postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        actions: [
          IconButton(
            key: const ValueKey('community-post-report'),
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _report(context, ref),
          ),
          detailAsync.maybeWhen(
            data: (d) => d.post.isMine
                ? IconButton(
                    key: const ValueKey('community-post-delete'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await ref.read(communityPostDetailControllerProvider(postId).notifier).deletePost();
                        if (context.mounted) context.pop();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                        }
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (d) {
          final post = d.post;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (post.title != null && post.title!.isNotEmpty)
                Text(post.title!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(post.body),
              const SizedBox(height: AppSpacing.sm),
              Text('${post.author.isAnonymous ? "Ẩn danh" : (post.author.displayName ?? "")} • ${post.createdOn.toString().split(" ").first}${post.edited ? " • đã sửa" : ""}'),
              if (post.status != null) Text('Trạng thái: ${post.status}', key: const ValueKey('community-post-status')),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('community-post-vote'),
                    icon: Icon(post.votedByMe ? Icons.favorite : Icons.favorite_border,
                        color: post.votedByMe ? AppColors.danger : null),
                    onPressed: () async {
                      final controller = ref.read(communityPostDetailControllerProvider(postId).notifier);
                      if (post.votedByMe) {
                        await controller.unvote();
                      } else {
                        await controller.vote();
                      }
                    },
                  ),
                  Text('${post.voteCount}'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Ảnh (${post.images.length})', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final img in post.images)
                    Chip(
                      key: ValueKey('community-image-${img.id}'),
                      label: Text('${img.status} ${img.width}x${img.height}'),
                      onDeleted: post.isMine
                          ? () => ref.read(communityPostDetailControllerProvider(postId).notifier).deleteImage(img.id)
                          : null,
                    ),
                  if (post.isMine)
                    ActionChip(
                      key: const ValueKey('community-upload-image'),
                      avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Gửi ảnh'),
                      onPressed: () => _uploadImage(context, ref),
                    ),
                ],
              ),
              const Divider(height: AppSpacing.lg * 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bình luận (${d.comments.length})', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    key: const ValueKey('community-add-comment'),
                    onPressed: () => _addComment(context, ref),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Bình luận'),
                  ),
                ],
              ),
              for (final c in d.comments)
                ListTile(
                  key: ValueKey('community-comment-${c.id}'),
                  title: Text(c.body),
                  subtitle: Text(
                      '${c.author.isAnonymous ? "Ẩn danh" : (c.author.displayName ?? "")} • ${c.createdOn.toString().split(" ").first}${c.edited ? " • đã sửa" : ""}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isMine)
                        IconButton(
                          key: ValueKey('community-delete-comment-${c.id}'),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () =>
                              ref.read(communityPostDetailControllerProvider(postId).notifier).deleteComment(c.id),
                        )
                      else
                        IconButton(
                          key: ValueKey('community-report-comment-${c.id}'),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          onPressed: () => _report(context, ref, commentId: c.id),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
