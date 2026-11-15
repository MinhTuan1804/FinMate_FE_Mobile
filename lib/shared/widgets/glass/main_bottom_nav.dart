import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_nav.dart';

/// Thanh điều hướng chính dùng chung cho 4 tab (Trang chủ, Giao dịch, Kế hoạch, Phân tích).
/// Màn nào là tab chính chỉ cần: `bottomNavigationBar: const MainBottomNav(currentIndex: n)`.
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.currentIndex});

  /// 0=Trang chủ, 1=Giao dịch, 2=Kế hoạch, 3=Phân tích.
  final int currentIndex;

  static const _routes = ['/home', '/transactions', '/planning', '/analytics'];

  @override
  Widget build(BuildContext context) {
    return GlassBottomNav(
      currentIndex: currentIndex,
      onDestinationSelected: (idx) {
        if (idx == -1) {
          context.push('/qr-transfers');
        } else if (idx != currentIndex) {
          // go (không push) để chuyển tab không chồng stack
          context.go(_routes[idx]);
        }
      },
    );
  }
}
