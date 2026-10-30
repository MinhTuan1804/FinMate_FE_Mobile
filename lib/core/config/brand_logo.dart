import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/theme/app_spacing.dart';

/// Logo thương hiệu: ảnh do admin đặt (https) nếu có, không thì dấu hiệu mặc định của app. Ảnh lỗi hay chưa tải xong cũng rơi về mặc định
/// nên một đường dẫn hỏng không bao giờ để lại ô trống.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoUrl = ref.watch(appConfigProvider.select((config) => config.theme.logoUrl));
    final fallback = _DefaultMark(size: size);
    if (logoUrl == null) return fallback;
    return ClipRRect(
      borderRadius: AppSpacing.roundedLarge,
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Logo FinMate',
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

class _DefaultMark extends StatelessWidget {
  const _DefaultMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Center(child: Icon(LucideIcons.wallet, size: size / 2, color: primary)),
    );
  }
}
