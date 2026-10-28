import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/notifications/presentation/notification_capture_scope.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/screens/transactions_screen.dart';

class _FakeTx extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  _FakeTx(super.state, {this._drafts = false});

  bool _drafts;
  TransactionType? _filter;
  final calls = <String>[];
  Object? confirmError;
  Completer<void>? confirmGate;
  int loads = 0;

  @override
  bool get draftsOnly => _drafts;

  @override
  TransactionType? get filter => _filter;

  @override
  bool get hasMore => false;

  @override
  Future<void> setDraftsOnly(bool value) async {
    _drafts = value;
    calls.add('drafts:$value');
  }

  @override
  Future<void> setFilter(TransactionType? type) async {
    _filter = type;
    calls.add('filter:${type?.name}');
  }

  @override
  Future<void> loadTransactions() async => loads++;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> confirmDraft(String id, {String? categoryId}) async {
    calls.add('confirm:$id');
    await confirmGate?.future;
    if (confirmError != null) throw confirmError!;
    state = AsyncValue.data([for (final t in state.value ?? const <TransactionEntity>[]) if (t.id != id) t]);
  }

  Object? saveError;
  Completer<void>? saveGate;
  BigInt? savedAmount;

  @override
  Future<void> saveDraft({
    required String id,
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    required DateTime date,
    String? merchantName,
    String description = '',
  }) async {
    calls.add('save:$id');
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    savedAmount = amountCents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridge extends NotificationBridge {
  int opens = 0;
  Completer<void>? flushGate;

  @override
  Future<void> openNotificationAccessSettings() async => opens++;

  @override
  Future<void> flushQueue() async => await flushGate?.future;

  @override
  Future<bool> consumeSessionExpired() async => false;
}

class _FakeAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _FakeAccounts() : super(AsyncValue.data([FinancialAccount(id: 'acc-1', type: AccountType.bank, name: 'MB Bank', balanceCents: BigInt.zero)]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransactionEntity _draft(String id, {int amount = 45000, TransactionType type = TransactionType.expense, String? merchant = 'Highlands Coffee'}) =>
    TransactionEntity(
      id: id,
      amountCents: BigInt.from(amount),
      type: type,
      categoryId: 'cat-1',
      categoryName: 'Ăn uống',
      merchantName: merchant,
      description: 'Thanh toan QR',
      date: DateTime(2026, 10, 27, 8, 30),
      accountId: 'acc-1',
      status: TransactionStatus.draft,
      source: 'Notification',
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeTx tx, {
  bool accessEnabled = true,
  _FakeBridge? bridge,
  ValueNotifier<bool>? visible,
  bool nested = false, // đẩy màn hình lên trên một route gốc để thấy route nào bị pop
  bool withScope = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shown = visible ?? ValueNotifier(true);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      transactionControllerProvider.overrideWith((ref) => tx),
      accountsControllerProvider.overrideWith((ref) => _FakeAccounts()),
      categoriesProvider.overrideWith((ref) async => const [Category(id: 'cat-1', name: 'Ăn uống', slug: 'food')]),
      notificationAccessEnabledProvider.overrideWith((ref) async => accessEnabled),
      notificationBridgeProvider.overrideWithValue(bridge ?? _FakeBridge()),
    ],
    child: Builder(builder: (_) {
      final home = ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (_, v, __) => v ? const TransactionsScreen() : const Scaffold(body: Text('khác')),
      );
      final app = nested
          ? MaterialApp(home: const Scaffold(body: Text('gốc')), routes: {'/tx': (_) => home}, initialRoute: '/tx')
          : MaterialApp(home: home);
      return withScope ? NotificationCaptureScope(child: app) : app;
    }),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows_Cho_duyet_chip', (tester) async {
    await _pump(tester, _FakeTx(const AsyncValue.data([])));
    expect(find.widgetWithText(ChoiceChip, 'Chờ duyệt'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
  });

  testWidgets('tapping_chip_requests_drafts', (tester) async {
    final tx = _FakeTx(const AsyncValue.data([]));
    await _pump(tester, tx);
    await tester.tap(find.text('Chờ duyệt'));
    await tester.pumpAndSettle();
    expect(tx.calls, ['drafts:true']);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chờ duyệt')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tất cả')).selected, isFalse);
  });

  testWidgets('draft_tile_shows_amount_and_actions', (tester) async {
    await _pump(tester, _FakeTx(AsyncValue.data([_draft('d1'), _draft('d2', amount: 2000000, type: TransactionType.income, merchant: null)]), drafts: true));
    expect(find.text('Highlands Coffee'), findsOneWidget);
    expect(find.text('-45.000 ₫'), findsOneWidget);
    expect(find.text('+2.000.000 ₫'), findsOneWidget);
    // Không có người nhận thì dùng mô tả
    expect(find.text('Thanh toan QR'), findsOneWidget);
    expect(find.textContaining('Ăn uống'), findsNWidgets(2));
    expect(find.textContaining('27/10/2026'), findsNWidgets(2));
    expect(find.text('Xác nhận'), findsNWidgets(2));
    expect(find.text('Sửa'), findsNWidgets(2));
  });

  testWidgets('tapping_Xac_nhan_confirms_draft', (tester) async {
    final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true);
    await _pump(tester, tx);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(tx.calls, ['confirm:d1']);
    expect(find.text('Highlands Coffee'), findsNothing);
    expect(find.text('Đã xác nhận giao dịch'), findsOneWidget);
  });

  testWidgets('permission_card_shown_when_access_disabled', (tester) async {
    final bridge = _FakeBridge();
    await _pump(tester, _FakeTx(const AsyncValue.data([]), drafts: true), accessEnabled: false, bridge: bridge);
    expect(find.text('Mở cài đặt'), findsOneWidget);
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pump();
    expect(bridge.opens, 1);
  });

  testWidgets('permission_card_hidden_when_access_enabled_or_not_in_drafts_mode', (tester) async {
    await _pump(tester, _FakeTx(const AsyncValue.data([]), drafts: true));
    expect(find.text('Mở cài đặt'), findsNothing);

    await _pump(tester, _FakeTx(const AsyncValue.data([]), drafts: false), accessEnabled: false);
    expect(find.text('Mở cài đặt'), findsNothing);
  });

  testWidgets('empty_state_when_no_drafts', (tester) async {
    final tx = _FakeTx(const AsyncValue.data([]), drafts: true);
    await _pump(tester, tx);
    // Offline cũng trả danh sách rỗng nên không khẳng định "không có nháp"
    expect(find.textContaining('Hiện chưa hiển thị'), findsOneWidget);
    expect(find.textContaining('Chưa có giao dịch nào'), findsNothing);
    await tester.tap(find.text('Tải lại'));
    await tester.pump();
    expect(tx.loads, 1);
  });

  testWidgets('error_state_in_drafts_mode_offers_retry', (tester) async {
    final tx = _FakeTx(AsyncValue.error(ApiException(message: 'Mất kết nối'), StackTrace.empty), drafts: true);
    await _pump(tester, tx);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(tx.loads, 1);
  });

  group('leaving_drafts_view_resets_draftsOnly', () {
    testWidgets('chọn chip khác', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]), drafts: true);
      await _pump(tester, tx);
      await tester.tap(find.text('Chi tiêu'));
      await tester.pumpAndSettle();
      expect(tx.draftsOnly, isFalse);
      expect(tx.filter, TransactionType.expense);
    });

    testWidgets('chọn Tất cả', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]), drafts: true);
      await _pump(tester, tx);
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(tx.draftsOnly, isFalse);
    });

    testWidgets('rời màn hình', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]), drafts: true);
      final visible = ValueNotifier(true);
      await _pump(tester, tx, visible: visible);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('khác'), findsOneWidget);
      expect(tx.draftsOnly, isFalse);
    });

    testWidgets('rời màn khi không ở chế độ nháp thì không gọi gì', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]));
      final visible = ValueNotifier(true);
      await _pump(tester, tx, visible: visible);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(tx.calls, isEmpty);
    });
  });

  testWidgets('confirm_error_shows_snackbar_and_requests_reload', (tester) async {
    // BE báo nháp không còn hợp lệ (đã duyệt/404): tải lại để dòng cũ biến mất khỏi danh sách.
    final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..confirmError = ApiException(message: 'Giao dịch không còn là nháp');
    await _pump(tester, tx);
    expect(tx.loads, 0);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch không còn là nháp'), findsOneWidget);
    expect(tx.loads, 1);
  });

  testWidgets('confirm_success_does_not_reload', (tester) async {
    final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true);
    await _pump(tester, tx);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(tx.loads, 0);
  });

  testWidgets('confirm_error_shows_snackbar_and_keeps_tile', (tester) async {
    final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..confirmError = ApiException(message: 'Giao dịch đã được xác nhận');
    await _pump(tester, tx);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch đã được xác nhận'), findsOneWidget);
    expect(find.text('Highlands Coffee'), findsOneWidget);
    // Nút bấm lại được sau lỗi
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(tx.calls, ['confirm:d1', 'confirm:d1']);
  });

  testWidgets('double_tap_confirms_once_and_disables_buttons_while_busy', (tester) async {
    final gate = Completer<void>();
    final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..confirmGate = gate;
    await _pump(tester, tx);
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.tap(find.text('Xác nhận'), warnIfMissed: false);
    await tester.pump();
    expect(tx.calls, ['confirm:d1']);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Sửa')).onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Highlands Coffee'), findsNothing);
  });

  group('làm mới nháp khi quay lại app', () {
    testWidgets('reload_happens_after_scope_flush_completes_exactly_once', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]), drafts: true);
      final bridge = _FakeBridge();
      await _pump(tester, tx, bridge: bridge, withScope: true);
      final before = tx.loads;

      bridge.flushGate = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // Flush chưa xong thì chưa được tải lại (tải trước khi hàng đợi được đẩy sẽ bỏ lỡ nháp mới)
      expect(tx.loads, before);

      bridge.flushGate!.complete();
      await tester.pumpAndSettle();
      expect(tx.loads, before + 1);
    });

    testWidgets('resume_does_not_reload_outside_drafts_mode', (tester) async {
      final tx = _FakeTx(const AsyncValue.data([]));
      await _pump(tester, tx, withScope: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tx.loads, 0);
    });
  });

  group('Sửa', () {
    Future<void> openEdit(WidgetTester tester, _FakeTx tx) async {
      await _pump(tester, tx);
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
    }

    testWidgets('edit_saves_then_confirms', (tester) async {
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true);
      await openEdit(tester, tx);
      expect(find.text('Lưu & xác nhận'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('draft-amount')), '50.000');
      await tester.tap(find.text('Lưu & xác nhận'));
      await tester.pumpAndSettle();
      expect(tx.calls, ['save:d1', 'confirm:d1']);
      expect(tx.savedAmount, BigInt.from(50000));
      expect(find.text('Lưu & xác nhận'), findsNothing);
    });

    testWidgets('edit_rejects_invalid_amount_without_calling_controller', (tester) async {
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true);
      await openEdit(tester, tx);
      await tester.enterText(find.byKey(const ValueKey('draft-amount')), '0');
      await tester.tap(find.text('Lưu & xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsOneWidget);
      expect(tx.calls, isEmpty);
    });

    testWidgets('edit_confirm_failure_keeps_saved_draft_and_shows_error', (tester) async {
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..confirmError = ApiException(message: 'Không có mạng');
      await openEdit(tester, tx);
      await tester.tap(find.text('Lưu & xác nhận'));
      await tester.pumpAndSettle();
      expect(tx.calls, ['save:d1', 'confirm:d1']);
      expect(find.textContaining('Không có mạng'), findsOneWidget);
      expect(find.text('Lưu & xác nhận'), findsOneWidget); // sheet còn mở để thử lại
      expect(tx.state.value, isNotEmpty);
    });

    testWidgets('edit_sheet_cannot_be_dismissed_while_saving_and_does_not_pop_the_screen', (tester) async {
      final gate = Completer<void>();
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..saveGate = gate;
      await _pump(tester, tx, nested: true);
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu & xác nhận'));
      await tester.pump();

      await tester.tapAt(const Offset(10, 10)); // chạm nền mờ
      await tester.pump();
      await tester.binding.handlePopRoute(); // nút Back
      await tester.pump(const Duration(milliseconds: 300)); // không pumpAndSettle: vòng xoay đang chạy
      expect(find.byKey(const ValueKey('draft-amount')), findsOneWidget);
      expect(find.byType(TransactionsScreen), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-amount')), findsNothing);
      expect(find.byType(TransactionsScreen), findsOneWidget);
      expect(find.text('gốc'), findsNothing);
      expect(tx.calls, ['save:d1', 'confirm:d1']);
    });

    testWidgets('edit_sheet_cancel_button_closes_it_when_idle', (tester) async {
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true);
      await _pump(tester, tx, nested: true);
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-amount')), findsNothing);
      expect(find.byType(TransactionsScreen), findsOneWidget);
      expect(tx.calls, isEmpty);
    });

    testWidgets('edit_save_failure_does_not_confirm', (tester) async {
      final tx = _FakeTx(AsyncValue.data([_draft('d1')]), drafts: true)..saveError = ApiException(message: 'Lưu lỗi');
      await openEdit(tester, tx);
      await tester.tap(find.text('Lưu & xác nhận'));
      await tester.pumpAndSettle();
      expect(tx.calls, ['save:d1']);
      expect(find.text('Lưu lỗi'), findsOneWidget);
    });
  });
}
