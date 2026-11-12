import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';
import '../../fixtures/fixture.dart';

/// Fake tối giản: chỉ cần override đúng những gì TransactionsScreen gọi tới
/// (shareToGroup/unshareFromGroup) và các getter nó đọc trong build(); phần còn lại
/// rơi vào noSuchMethod giống FakeTxController trong transaction_test.dart.
class _FakeTxController extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  final List<(String id, String groupId, String? groupCategoryId)> shareCalls = [];
  final List<String> unshareCalls = [];
  Object? shareError;
  Object? unshareError;

  _FakeTxController(super.state);

  @override
  bool get hasMore => false;

  @override
  bool get draftsOnly => false;

  @override
  TransactionType? get filter => null;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> loadTransactions() async {}

  @override
  Future<void> shareToGroup({required String id, required String groupId, String? groupCategoryId}) async {
    shareCalls.add((id, groupId, groupCategoryId));
    if (shareError != null) throw shareError!;
    state = AsyncValue.data([
      for (final t in state.value ?? const <TransactionEntity>[]) t.id == id ? t.withGroupId(groupId) : t,
    ]);
  }

  @override
  Future<void> unshareFromGroup(String id) async {
    unshareCalls.add(id);
    if (unshareError != null) throw unshareError!;
    state = AsyncValue.data([
      for (final t in state.value ?? const <TransactionEntity>[]) t.id == id ? t.withGroupId(null) : t,
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransactionEntity _tx(String id, {String? groupId}) => TransactionEntity(
      id: id,
      amountCents: BigInt.from(50000),
      type: TransactionType.expense,
      categoryName: 'Ăn uống',
      description: 'Giao dịch $id',
      date: DateTime(2026, 10, 1, 12),
      accountId: 'acc-1',
      groupId: groupId,
    );

/// Adapter giả cho groups: GET /groups -> groups.json; GET /groups/{id}/categories -> group_categories.json.
RouteAdapter _groupsAdapter() => RouteAdapter((o) {
      if (o.path.contains('/categories')) return respondFixture('group_categories');
      return respondFixture('groups');
    });

Future<_FakeTxController> _pump(WidgetTester tester, {List<TransactionEntity>? initial, RouteAdapter? groupsAdapter}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tx = _FakeTxController(AsyncValue.data(initial ?? [_tx('t1')]));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      transactionControllerProvider.overrideWith((ref) => tx),
      apiClientProvider.overrideWithValue(testApiClient(groupsAdapter ?? _groupsAdapter())),
      currentUserIdProvider.overrideWith((ref) => 'u1'),
    ],
    child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
  ));
  await tester.pumpAndSettle();
  return tx;
}

void main() {
  group('Chia sẻ / bỏ chia sẻ giao dịch vào nhóm', () {
    testWidgets('giao dịch chưa chia sẻ: bấm icon mở hộp thoại chọn nhóm + danh mục, xác nhận gọi shareToGroup', (tester) async {
      final tx = await _pump(tester, initial: [_tx('t1')]);

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Chia sẻ vào nhóm'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-share-group')), findsOneWidget);

      // Chưa chọn nhóm: nút Chia sẻ bị khoá
      final shareBtnBefore = tester.widget<TextButton>(find.byKey(const ValueKey('confirm-share-group')));
      expect(shareBtnBefore.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('share-group-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gia đình').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('share-category-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống chung').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-share-group')));
      await tester.pumpAndSettle();

      expect(tx.shareCalls.single, ('t1', 'g1', 'gc1'));
      expect(find.text('Đã chia sẻ giao dịch vào nhóm'), findsOneWidget);
    });

    testWidgets('không chọn danh mục vẫn chia sẻ được (groupCategoryId null)', (tester) async {
      final tx = await _pump(tester, initial: [_tx('t1')]);

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-group-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gia đình').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-share-group')));
      await tester.pumpAndSettle();

      expect(tx.shareCalls.single, ('t1', 'g1', null));
    });

    testWidgets('giao dịch đã chia sẻ: bấm icon mở hộp thoại xác nhận bỏ chia sẻ', (tester) async {
      final tx = await _pump(tester, initial: [_tx('t1', groupId: 'g1')]);

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Bỏ chia sẻ giao dịch'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm-unshare-group')));
      await tester.pumpAndSettle();

      expect(tx.unshareCalls, ['t1']);
      expect(find.text('Đã bỏ chia sẻ giao dịch'), findsOneWidget);
    });

    testWidgets('hủy hộp thoại bỏ chia sẻ thì không gọi unshareFromGroup', (tester) async {
      final tx = await _pump(tester, initial: [_tx('t1', groupId: 'g1')]);

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(tx.unshareCalls, isEmpty);
    });

    testWidgets('lỗi khi chia sẻ hiện thông điệp thân thiện, không đóng danh sách', (tester) async {
      final tx = await _pump(tester, initial: [_tx('t1')]);
      tx.shareError = Exception('Bạn không có quyền chia sẻ giao dịch vào nhóm này');

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-group-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gia đình').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-share-group')));
      await tester.pumpAndSettle();

      expect(find.text('Bạn không có quyền chia sẻ giao dịch vào nhóm này'), findsOneWidget);
    });

    testWidgets('chưa tham gia nhóm nào: hộp thoại báo không có nhóm, không có ô chọn', (tester) async {
      await _pump(
        tester,
        initial: [_tx('t1')],
        groupsAdapter: RouteAdapter((o) => respondJson({'success': true, 'data': <dynamic>[], 'error': null, 'meta': null})),
      );

      await tester.tap(find.byKey(const ValueKey('share-group-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa tham gia nhóm nào.'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-group-select')), findsNothing);
    });
  });
}
