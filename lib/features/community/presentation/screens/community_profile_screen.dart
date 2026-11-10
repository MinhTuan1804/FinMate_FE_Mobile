import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/controllers/community_controller.dart';

/// Màn test hồ sơ Cộng đồng: tỉnh/khu vực, nhận gợi ý chia sẻ, và cấp đồng ý tham gia (đăng bài/bình luận).
class CommunityProfileScreen extends ConsumerWidget {
  const CommunityProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(communityProfileProvider);
    final regionsAsync = ref.watch(communityRegionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ Cộng đồng')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (profile) {
          String? provinceCode = profile.provinceCode;
          String? areaCode = profile.areaCode;
          bool promptsEnabled = profile.promptsEnabled;

          return StatefulBuilder(
            builder: (context, setState) {
              final regions = regionsAsync.valueOrNull ?? const [];
              final selectedProvince = regions.where((p) => p.code == provinceCode).toList();
              final areas = selectedProvince.isNotEmpty ? selectedProvince.first.areas : const [];

              Future<void> save() async {
                try {
                  await ref.read(communityUpdateProfileActionProvider)(
                    provinceCode: provinceCode,
                    areaCode: areaCode,
                    promptsEnabled: promptsEnabled,
                  );
                  ref.invalidate(communityProfileProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Row(
                    children: [
                      Text(profile.consentGranted ? 'Đã đồng ý tham gia' : 'Chưa đồng ý tham gia'),
                      const Spacer(),
                      if (!profile.consentGranted)
                        ElevatedButton(
                          key: const ValueKey('community-grant-consent'),
                          onPressed: () async {
                            try {
                              await ref.read(authControllerProvider.notifier).acceptConsent(ConsentKind.community);
                              ref.invalidate(communityProfileProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                              }
                            }
                          },
                          child: const Text('Đồng ý tham gia'),
                        ),
                    ],
                  ),
                  if (profile.isMuted)
                    Text('Đang bị tạm khóa đăng bài đến: ${profile.mutedUntil}',
                        style: const TextStyle(color: Colors.red)),
                  const Divider(height: AppSpacing.lg * 2),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('community-province-dropdown'),
                    decoration: const InputDecoration(labelText: 'Tỉnh/Thành'),
                    initialValue: provinceCode,
                    items: [
                      for (final p in regions) DropdownMenuItem(value: p.code, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() {
                      provinceCode = v;
                      areaCode = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('community-area-dropdown'),
                    decoration: const InputDecoration(labelText: 'Khu vực'),
                    initialValue: areaCode,
                    items: [
                      for (final a in areas) DropdownMenuItem(value: a.code, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => areaCode = v),
                  ),
                  SwitchListTile(
                    key: const ValueKey('community-prompts-switch'),
                    title: const Text('Nhận gợi ý chia sẻ quán sau khi lưu giao dịch'),
                    value: promptsEnabled,
                    onChanged: (v) => setState(() => promptsEnabled = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    key: const ValueKey('community-save-profile'),
                    onPressed: save,
                    child: const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
