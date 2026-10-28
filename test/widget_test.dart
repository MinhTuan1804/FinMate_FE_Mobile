import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/main.dart';

void main() {
  testWidgets('FinMateApp smoke test - chưa đăng nhập: splash rồi vào WelcomeScreen với cam kết Zero-Credential', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Không có Keystore trong môi trường test
        overrides: [tokenStorageProvider.overrideWithValue(InMemoryTokenStorage())],
        child: const FinMateApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify WelcomeScreen elements exist
    expect(find.text('FinMate'), findsOneWidget);
    expect(find.text('Đăng nhập với Email'), findsOneWidget);
    expect(find.text('Cam kết bảo mật Zero-Credential'), findsOneWidget);
  });
}
