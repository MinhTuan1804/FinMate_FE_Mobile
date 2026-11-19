import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_radio_card.dart';

/// Khung kính (glass) dùng chung cho mọi dialog — cùng phong cách `GlassCard` level 3 (modal) đã
/// dùng ở các bottom sheet (I3's `_FundEntrySheetScaffold`, `_GroupSettingsSheet` cũ), nhưng hiện
/// giữa màn hình qua [showDialog] thay vì trượt lên từ đáy. Không gọi trực tiếp — dùng các hàm tĩnh
/// của [GlassDialog] bên dưới.
class GlassDialogShell extends StatelessWidget {
  final String title;
  final Widget child;

  const GlassDialogShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        // GlassCard làm mờ nội dung phía sau; chỉ tô màu bán trong suốt thì chữ của màn dưới xuyên qua hộp thoại.
        child: GlassCard(
          level: 3,
          padding: const EdgeInsets.all(20),
          borderRadius: GlassRadius.roundedCardLarge,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: GlassTypography.headlineSm())),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog kính (glass) dùng chung toàn app — thay `AlertDialog`/`SimpleDialog` mặc định của Flutter,
/// vốn không đồng bộ với hệ thiết kế glass (`GlassCard`/`GlassTypography`/`GlassColors`) mà các màn
/// dùng dialog đang theo. 3 biến thể: [confirm] (xác nhận 2 nút, có `isDanger` cho hành động phá
/// hủy), [choice] (chọn 1 trong nhiều lựa chọn, thay `SimpleDialog`), [custom] (nội dung tùy ý —
/// dùng cho form nhập liệu như đổi tên/tạo quỹ).
class GlassDialog {
  GlassDialog._();

  /// Dialog xác nhận: [message] + 2 nút full-width (Hủy dạng ghost, hành động chính dạng primary
  /// hoặc đỏ khi [isDanger]). Trả `true` nếu bấm hành động chính, `false`/`null` nếu hủy.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Hủy',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialogShell(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: GlassTypography.bodyMd(color: GlassColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GlassGhostButton(
                    key: const ValueKey('glass-dialog-cancel'),
                    label: cancelLabel,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isDanger
                      ? SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const ValueKey('glass-dialog-confirm'),
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                            ),
                            child: Text(confirmLabel, style: GlassTypography.buttonText()),
                          ),
                        )
                      : GlassPrimaryButton(
                          key: const ValueKey('glass-dialog-confirm'),
                          label: confirmLabel,
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog chọn 1 trong nhiều lựa chọn (thay `SimpleDialog`) — mỗi lựa chọn là 1 [GlassRadioCard],
  /// bấm vào là trả về ngay giá trị đó (không cần nút "Xác nhận" riêng). [labelOf]/[subtitleOf] lấy
  /// nhãn hiển thị; [isSelected] đánh dấu lựa chọn hiện tại (nếu có).
  static Future<T?> choice<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    String? Function(T)? subtitleOf,
    bool Function(T)? isSelected,
    String cancelLabel = 'Hủy',
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => GlassDialogShell(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassRadioCard(
                    key: ValueKey('glass-dialog-choice-${labelOf(o)}'),
                    title: labelOf(o),
                    subtitle: subtitleOf?.call(o),
                    selected: isSelected?.call(o) ?? false,
                    onTap: () => Navigator.pop(ctx, o),
                  ),
                )),
            const SizedBox(height: 4),
            GlassGhostButton(
              key: const ValueKey('glass-dialog-cancel'),
              label: cancelLabel,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog nội dung tùy ý (vd. form đổi tên/tạo quỹ) — [contentBuilder] nhận `setState` của chính
  /// dialog (để validate/báo lỗi tại chỗ như các sheet khác), [actionsBuilder] vẽ hàng nút dưới cùng.
  static Future<T?> custom<T>(
    BuildContext context, {
    required String title,
    required Widget Function(BuildContext context, StateSetter setState) contentBuilder,
    required Widget Function(BuildContext context, StateSetter setState) actionsBuilder,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => GlassDialogShell(
        title: title,
        child: StatefulBuilder(
          builder: (ctx2, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              contentBuilder(ctx2, setState),
              const SizedBox(height: 20),
              actionsBuilder(ctx2, setState),
            ],
          ),
        ),
      ),
    );
  }
}
