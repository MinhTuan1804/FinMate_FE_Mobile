import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';

/// Màn test chi tiết quán + các bài liên quan — `GET /api/v1/community/places/{id}`.
class CommunityPlaceDetailScreen extends ConsumerWidget {
  final String placeId;

  const CommunityPlaceDetailScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(communityPlaceDetailProvider(placeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết quán')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (d) {
          final place = d.place;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(place.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(place.addressText ?? '${place.areaCode}, ${place.provinceCode}'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  Chip(label: Text('Chia sẻ: ${place.shareCount}')),
                  Chip(label: Text('Chạm: ${place.spentHereCount}')),
                  Chip(label: Text('Vote: ${place.voteCount}')),
                  if (place.typicalPriceCents != null)
                    Chip(label: Text('~${place.typicalPriceCents! ~/ BigInt.from(100)}đ')),
                ],
              ),
              if (place.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.xs, children: [for (final t in place.tags) Chip(label: Text(t))]),
              ],
              const Divider(height: AppSpacing.lg * 2),
              Text('Bài liên quan (${d.posts.length})', style: Theme.of(context).textTheme.titleMedium),
              for (final post in d.posts)
                ListTile(
                  key: ValueKey('community-place-post-${post.id}'),
                  title: Text(post.title?.isNotEmpty == true ? post.title! : (post.isSpentHereOnly ? '(chạm quán)' : post.body)),
                  subtitle: Text(
                      '${post.author.isAnonymous ? "Ẩn danh" : (post.author.displayName ?? "")} • vote ${post.voteCount} • cmt ${post.commentCount}'),
                  onTap: post.isSpentHereOnly ? null : () => context.push('/community-post', extra: post.id),
                ),
            ],
          );
        },
      ),
    );
  }
}
