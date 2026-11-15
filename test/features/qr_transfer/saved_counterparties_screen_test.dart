import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';
import 'package:finmate/features/qr_transfer/presentation/screens/saved_counterparties_screen.dart';

class _FakeRepository implements QrTransferRepository {
  _FakeRepository(this.results);

  /// Mỗi lần gọi getOverrides lấy một phần tử; phần tử là Exception thì ném.
  final List<Object> results;
  int calls = 0;
  final deleted = <String>[];

  @override
  Future<List<CounterpartyOverride>> getOverrides() async {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (r is Exception) throw r;
    return r as List<CounterpartyOverride>;
  }

  @override
  Future<void> deleteOverride(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

const _item = CounterpartyOverride(
  id: 'o1',
  bankBin: '970415',
  bankName: 'VietinBank',
  accountNumber: '0123456789',
  displayName: 'NGUYEN VAN A',
  categoryId: 'c1',
  categoryName: 'Ăn uống',
);

Widget _app(_FakeRepository repo) => ProviderScope(
      overrides: [qrTransferRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SavedCounterpartiesScreen()),
    );

void main() {
  test('CounterpartyOverride.fromJson đọc bankBin từ BE', () {
    final o = CounterpartyOverride.fromJson({
      'id': 'o1',
      'bankBin': '970415',
      'bankName': 'VietinBank',
      'accountNumber': '0123456789',
      'displayName': null,
      'categoryId': 'c1',
      'categoryName': 'Ăn uống',
    });
    expect(o.bankBin, '970415');
    expect(o.displayName, isNull);
  });

  testWidgets('hiện người nhận thật và xóa gọi repository', (tester) async {
    final repo = _FakeRepository([
      [_item],
      <CounterpartyOverride>[],
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('NGUYEN VAN A'), findsOneWidget);
    expect(find.text('VietinBank • Ăn uống'), findsOneWidget);

    await tester.tap(find.byTooltip('Bỏ người nhận đã lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['o1']);
    expect(find.textContaining('Chưa có người nhận nào'), findsOneWidget);
  });

  testWidgets('lỗi hiện thông điệp và Thử lại tải lại', (tester) async {
    final repo = _FakeRepository([
      NetworkException(),
      [_item],
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(NetworkException().message), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('NGUYEN VAN A'), findsOneWidget);
  });
}
