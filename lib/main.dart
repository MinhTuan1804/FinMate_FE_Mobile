import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/config/app_config_gate.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/glass/glass_theme_sync.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/routes/app_router.dart';
// ignore: unused_import
import 'widget_config_main.dart' as widget_config_entrypoint;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  runApp(
    const ProviderScope(
      child: FinMateApp(),
    ),
  );
}

class FinMateApp extends ConsumerWidget {
  const FinMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(appConfigProvider.select((config) => config.theme));
    final themeMode = ref.watch(themeModeProvider);
    final reduceTransparency = ref.watch(reduceTransparencyProvider);
    final userTextScale = ref.watch(textScaleProvider);

    return MaterialApp.router(
      title: 'FinMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.applyConfig(
        AppTheme.lightTheme,
        themeConfig,
        reduceTransparency: reduceTransparency,
      ),
      darkTheme: AppTheme.applyConfig(
        AppTheme.darkTheme,
        themeConfig,
        reduceTransparency: reduceTransparency,
      ),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Cỡ chữ admin đặt nhân với cỡ chữ người dùng chọn trong hệ điều hành: không ghi đè lựa chọn trợ năng của họ.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * themeConfig.textScale * userTextScale),
          ),
          child: GlassThemeSync(
            child: AppConfigGate(
              child: NotificationCaptureScope(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
