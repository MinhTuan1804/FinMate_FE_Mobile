import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/glass/glass_theme_sync.dart';
import 'package:finmate/features/home_widget/data/widget_config_bridge.dart';
import 'package:finmate/features/home_widget/presentation/screens/k1_widget_config_screen.dart';

/// Entrypoint Flutter RIÊNG cho `WidgetConfigActivity` (native Android, xem
/// android:configure trong res/xml/w*_widget_info.xml). KHÔNG dùng chung `main()`/app_router.dart:
/// OS tự mở Activity này bằng 1 FlutterEngine mới trỏ thẳng tới entrypoint `widgetConfigMain`,
/// không đi qua FinMateApp/go_router.
@pragma('vm:entry-point')
void widgetConfigMain() {
  runApp(
    const ProviderScope(
      child: _WidgetConfigApp(),
    ),
  );
}

class _WidgetConfigApp extends StatelessWidget {
  const _WidgetConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cấu hình Widget FinMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // đọc sáng/tối của hệ điều hành
      builder: (context, child) => GlassThemeSync(child: child!),
      home: K1WidgetConfigScreen(bridge: WidgetConfigBridge()),
    );
  }
}
