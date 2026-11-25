import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';

/// Màn test danh sách quán — `GET /api/v1/community/places` (cuộn vô hạn theo cursor, xếp theo điểm).
class CommunityPlacesScreen extends ConsumerWidget {
  const CommunityPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(communityPlacesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quán được chia sẻ')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityPlacesProvider.notifier).refresh(),
        child: placesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(errorMessage(e))),
          data: (items) => items.isEmpty
              ? const Center(child: Text('Chưa có quán nào.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    if (i == items.length) return CursorPagerFooter(pager: ref.read(communityPlacesProvider.notifier));
                    final p = items[i];
                    return ListTile(
                      key: ValueKey('community-place-${p.id}'),
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.addressText ?? "${p.areaCode}, ${p.provinceCode}"}\n'
                          'Chia sẻ: ${p.shareCount} • Chạm: ${p.spentHereCount} • Vote: ${p.voteCount}'),
                      isThreeLine: true,
                      trailing: p.typicalPriceCents != null
                          ? Text('~${p.typicalPriceCents! ~/ BigInt.from(100)}đ')
                          : null,
                      onTap: () => context.push('/community-place', extra: p.id),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
