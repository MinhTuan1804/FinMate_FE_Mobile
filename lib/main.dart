import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp.router(
      title: 'FinMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => NotificationCaptureScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
