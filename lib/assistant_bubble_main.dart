import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/core/theme/appearance_prefs.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';
import 'package:finmate/main.dart';
import 'package:finmate/routes/app_router.dart';

/// Entrypoint Flutter RIÊNG cho `AssistantBubbleActivity` (cửa sổ nổi khi bấm bong bóng FinMate AI).
/// Dùng lại nguyên FinMateApp (đăng nhập, theme, router, thẻ "Xem và lưu") nhưng mở thẳng màn trợ lý.
@pragma('vm:entry-point')
Future<void> assistantBubbleMain() => _runAssistant(overlay: false);

/// Entrypoint cho `AssistantOverlayActivity` (khung chat của bong bóng tự vẽ đè, dáng Messenger).
@pragma('vm:entry-point')
Future<void> assistantOverlayMain() => _runAssistant(overlay: true);

Future<void> _runAssistant({required bool overlay}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  // Khung chat bong bóng theo đúng sáng/tối và cỡ chữ người dùng đã chọn trong app.
  final appearance = await AppearancePrefs().loadOverrides();
  runApp(
    ProviderScope(
      overrides: [
        ...appearance,
        initialLocationProvider.overrideWithValue('/assistant'),
        isAssistantBubbleProvider.overrideWithValue(true),
        isAssistantOverlayProvider.overrideWithValue(overlay),
      ],
      child: const FinMateApp(),
    ),
  );
}
