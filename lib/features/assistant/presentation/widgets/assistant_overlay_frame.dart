import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';

// Vị trí bong bóng khi khung chat mở (dp). PHẢI trùng hằng số trong AssistantOverlayService.kt:
// BUBBLE_DP, EDGE_DP, EXPANDED_TOP_DP — bong bóng native và khung Flutter phải thẳng hàng.
const kBubbleSize = 56.0;
const kBubbleEdge = 8.0;
const kBubbleExpandedTop = 8.0;

/// Khoảng hở giữa đáy bong bóng và đỉnh khung chat, chỗ đặt mũi nhọn.
const _pointerGap = 10.0;
const _pointerSize = 16.0;

/// Khung chat dáng Messenger cho bong bóng tự vẽ đè: cửa sổ native trong suốt toàn màn hình, khung chat bo góc
/// nằm ngay dưới bong bóng (bong bóng do AssistantOverlayService vẽ ở góc trên bên phải), mũi nhọn chỉ lên bong
/// bóng. Vùng trống phía trên vẫn thấy app đang dùng; chạm vào đó để thu khung lại.
class AssistantOverlayFrame extends ConsumerWidget {
  const AssistantOverlayFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final panelTop = media.padding.top + kBubbleExpandedTop + kBubbleSize + _pointerGap;
    final pointerCenterX = media.size.width - kBubbleEdge - kBubbleSize / 2;
    // Hình vuông xoay 45° — nửa trên lộ ra trên khung thành mũi nhọn.
    final pointerHalf = _pointerSize * math.sqrt2 / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: 'Thu gọn khung chat',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(assistantBubbleBridgeProvider).closePanel(),
            ),
          ),
        ),
        Positioned(
          top: panelTop - pointerHalf,
          left: pointerCenterX - pointerHalf,
          width: pointerHalf * 2,
          height: pointerHalf * 2,
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 4,
              child: SizedBox.square(
                dimension: _pointerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: panelTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
            // Khung đã nằm dưới thanh trạng thái: bỏ padding trên để header màn trợ lý không chừa khoảng trống thừa.
            child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
          ),
        ),
      ],
    );
  }
}
