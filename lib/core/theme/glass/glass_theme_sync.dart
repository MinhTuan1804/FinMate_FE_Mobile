import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Đồng bộ [GlassColors.dark] với chế độ giao diện đang áp dụng và ép dựng lại cây widget khi đổi sáng/tối.
///
/// [GlassColors] đọc cờ toàn cục thay vì nhận `context`, nên widget không phụ thuộc `Theme` (ví dụ widget `const`) sẽ không tự
/// dựng lại khi đổi giao diện. Sau khi đổi, mọi phần tử bên dưới được đánh dấu cần dựng lại (giữ nguyên trạng thái màn hình).
class GlassThemeSync extends StatefulWidget {
  const GlassThemeSync({super.key, required this.child});

  final Widget child;

  @override
  State<GlassThemeSync> createState() => _GlassThemeSyncState();
}

class _GlassThemeSyncState extends State<GlassThemeSync> {
  Brightness? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    GlassColors.dark = brightness == Brightness.dark;
    final changed = _last != null && _last != brightness;
    _last = brightness;
    if (changed) WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildBelow());
  }

  void _rebuildBelow() {
    if (!mounted) return;
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
