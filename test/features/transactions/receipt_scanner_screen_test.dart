import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/presentation/screens/receipt_scanner_screen.dart';
import '../../fixtures/fakes.dart';
import '../../fixtures/fixture.dart';

const _imagePath = 'test/fixtures/receipt_sample.png';

Future<ReviewArgs?> _pumpAndPickGallery(
  WidgetTester tester, {
  required RouteAdapter adapter,
  ReceiptImageSource? source,
  bool pick = true,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ReviewArgs? opened;
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ReceiptScannerScreen()),
    GoRoute(
      path: '/assistant/review',
      builder: (_, state) {
        opened = state.extra as ReviewArgs;
        return const Text('REVIEW_PAGE');
      },
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      receiptImageSourceProvider.overrideWithValue(source ?? FakeImageSource(galleryPath: _imagePath)),
      categoriesProvider.overrideWith((ref) async => const [Category(id: 'c1', name: 'Ăn uống', slug: 'food')]),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  if (pick) {
    await tester.tap(find.text('Thư viện'));
    await _settle(tester);
  }
  return opened;
}

/// Đọc tệp ảnh là IO thật nên phải để event loop thật chạy (runAsync) trước khi bơm khung hình.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quét thật qua API: hiện cửa hàng và tổng tiền, bấm rà soát mở /assistant/review với bản nháp', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('scan_receipt_success'));
    await _pumpAndPickGallery(tester, adapter: adapter);

    expect(adapter.to('/transactions/scan-receipt'), hasLength(1));
    expect(find.text('WinMart'), findsOneWidget);
    expect(find.text('55.000 ₫'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);

    await tester.tap(find.text('Rà soát và lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('REVIEW_PAGE'), findsOneWidget);
  });

  testWidgets('lỗi mạng hiện thông điệp và Thử lại quét lại ảnh cũ', (tester) async {
    var fail = true;
    final adapter = RouteAdapter((o) {
      if (fail) throwNetworkDown(o);
      return respondFixture('scan_receipt_success');
    });
    await _pumpAndPickGallery(tester, adapter: adapter);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await _settle(tester);
    expect(find.text('WinMart'), findsOneWidget);
  });

  testWidgets('OCR không đọc được số tiền: báo không đọc được và cho chọn ảnh khác', (tester) async {
    final adapter = RouteAdapter((o) => respondJson({
          'success': true,
          'data': {'ocrResult': 'failed', 'amountCents': null},
          'error': null,
          'meta': null,
        }));
    await _pumpAndPickGallery(tester, adapter: adapter);

    expect(find.textContaining('Không đọc được hóa đơn'), findsOneWidget);
    expect(find.text('Chọn ảnh khác'), findsWidgets);
    expect(find.text('Rà soát và lưu giao dịch'), findsNothing);
  });

  testWidgets('bị từ chối quyền ảnh: hiện thông điệp và không gọi API', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('scan_receipt_success'));
    await _pumpAndPickGallery(
      tester,
      adapter: adapter,
      source: FakeImageSource(error: const ImageSourceException('Cần quyền truy cập ảnh')),
    );

    expect(find.text('Cần quyền truy cập ảnh'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });
}
