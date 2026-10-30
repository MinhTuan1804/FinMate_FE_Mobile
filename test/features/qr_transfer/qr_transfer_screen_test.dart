import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';
import 'package:finmate/features/qr_transfer/presentation/controllers/qr_providers.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/qr_transfer_screen.dart';

class _FakeRepository implements QrTransferRepository {
  @override
  Future<CounterpartyOverride?> lookupOverride({required String bankBin, required String accountNumber}) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

const _banks = [
  QrBank(bin: '970422', name: 'MB Bank', appCode: 'mb', canMatchNotifications: true),
  QrBank(bin: '970415', name: 'VietinBank', appCode: 'icb', canMatchNotifications: true),
  QrBank(bin: '970429', name: 'SCB', appCode: 'scb', canMatchNotifications: false),
];

Widget _app({VietQrData? scanned, Future<List<QrBank>> Function()? banks}) => ProviderScope(
      overrides: [
        qrBanksProvider.overrideWith((ref) => (banks ?? () async => _banks)()),
        categoriesProvider.overrideWith((ref) async => const [Category(id: 'c1', name: 'Ăn uống', slug: 'food')]),
        qrTransferRepositoryProvider.overrideWithValue(_FakeRepository()),
      ],
      child: MaterialApp(home: QrTransferScreen(scanned: scanned)),
    );

const _scanned = VietQrData(bankBin: '970415', accountNumber: '0123456789', beneficiaryName: 'NGUYEN VAN A');

Finder get _submit => find.widgetWithText(FilledButton, 'Ghi nhận và mở app ngân hàng');

/// Form dài hơn màn hình test mặc định và ListView chỉ dựng phần đang thấy: kéo màn hình cao lên để mọi ô đều có trong cây widget.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('hiện người nhận từ mã QR; nút chỉ bật khi có số tiền hợp lệ VÀ đã chọn ngân hàng gửi', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(scanned: _scanned));
    await tester.pumpAndSettle();

    expect(find.text('VietinBank'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.text('NGUYEN VAN A'), findsOneWidget);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VND)'), '50000');
    await tester.pump();
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull, reason: 'chưa chọn ngân hàng gửi');

    await tester.tap(find.text('Chọn app ngân hàng để chuyển'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB Bank'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
  });

  testWidgets('số tiền bằng 0 hoặc để trống thì nút vẫn tắt', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(scanned: _scanned));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn app ngân hàng để chuyển'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB Bank'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VND)'), '0');
    await tester.pump();

    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
  });

  testWidgets('chọn ngân hàng gửi mà FinMate chưa đọc được thông báo thì báo trước là sẽ không tự khớp', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(scanned: _scanned));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chọn app ngân hàng để chuyển'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SCB'));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa đọc được thông báo của SCB'), findsOneWidget);
  });

  testWidgets('ngân hàng người nhận không có trong danh mục thì giải thích và cho quay lại', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(scanned: const VietQrData(bankBin: '999999', accountNumber: '0123456789')));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa có trong danh sách hỗ trợ'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
  });

  testWidgets('không tải được danh sách ngân hàng thì có nút thử lại', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(scanned: _scanned, banks: () async => throw Exception('mất mạng')));
    await tester.pumpAndSettle();

    expect(find.text('Không tải được danh sách ngân hàng.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('nhập tay: chưa chọn ngân hàng nhận và chưa có số tài khoản thì chưa gửi được', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Chọn ngân hàng của người nhận'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Số tài khoản người nhận'), findsOneWidget);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
  });
}
