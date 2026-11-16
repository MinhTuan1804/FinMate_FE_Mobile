import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// AppBar trong suốt, tiêu đề căn giữa, nút quay lại icon Lucide (chỉ hiện khi có màn bên dưới) — kiểu header của B4–B7.
AppBar glassAppBar(BuildContext context, {required String title, List<Widget>? actions}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    leading: Navigator.of(context).canPop()
        ? IconButton(
            tooltip: 'Quay lại',
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: GlassColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    title: Text(title, style: GlassTypography.headlineSm().copyWith(letterSpacing: -0.425)),
    actions: actions,
  );
}
