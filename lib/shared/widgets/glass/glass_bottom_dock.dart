import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Thanh hành động cố định đáy màn hình (B3/B6/B7): nền kính mờ, viền trên, chứa 1-2 nút pill.
class GlassBottomDock extends StatelessWidget {
  final List<Widget> actions;

  const GlassBottomDock({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: GlassColors.glassFillModal,
            border: Border(top: BorderSide(color: GlassColors.glassBorderModal)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
