import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/config/app_config_gate.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/appearance_prefs.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/theme/glass/glass_theme_sync.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';
import 'package:finmate/features/devices/data/push_messaging.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_overlay_frame.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/routes/app_router.dart';
// ignore: unused_import
import 'widget_config_main.dart' as widget_config_entrypoint;
// ignore: unused_import
import 'assistant_bubble_main.dart' as assistant_bubble_entrypoint;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase lấy cấu hình từ android/app/google-services.json; nền tảng khác chưa có file cấu hình.
  // ponytail: chỉ Android, chạy `flutterfire configure` khi cần iOS/web.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
  await initializeDateFormatting('vi_VN', null);
  // Sáng/tối, cỡ chữ, giảm trong suốt người dùng đã chọn ở lần trước.
  final appearance = await AppearancePrefs().loadOverrides();
  runApp(
    ProviderScope(
      overrides: appearance,
      child: const FinMateApp(),
    ),
  );
}

class FinMateApp extends ConsumerWidget {
  const FinMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(appConfigProvider.select((config) => config.theme));
    persistAppearanceChanges(ref);
    ref.watch(pushMessagingProvider);
    // Font admin chọn: mọi style (AppTypography/GlassTypography) đọc từ đây.
    AppTypography.configure(themeConfig);
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
      scaffoldMessengerKey: pushMessengerKey,
      builder: (context, child) {
        // Cỡ chữ người dùng chọn trong app (Nhỏ/Chuẩn/Lớn) nhân với cỡ chữ hệ điều hành: không ghi đè lựa chọn trợ năng của họ.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * userTextScale),
          ),
          child: ref.watch(isAssistantOverlayProvider) ? AssistantOverlayFrame(child: _app(child)) : _app(child),
        );
      },
    );
  }

  Widget _app(Widget? child) => GlassThemeSync(
        child: AppConfigGate(
          child: NotificationCaptureScope(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
}
