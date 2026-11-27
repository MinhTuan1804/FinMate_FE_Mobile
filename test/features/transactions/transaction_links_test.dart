import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/transactions/data/transaction_links_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../fixtures/fixture.dart';

class _FakeTx extends StateNotifier<AsyncValue<List<TransactionEntity>>> implements TransactionController {
  _FakeTx() : super(const AsyncValue.data([]));
  int loads = 0;

  @override
  Future<void> loadTransactions() async => loads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _FakeAccounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlanning extends StateNotifier<AsyncValue<PlanningState>> implements PlanningController {
  _FakePlanning(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecurring extends StateNotifier<AsyncValue<List<RecurringItemEntity>>> implements RecurringItemsController {
  _FakeRecurring() : super(const AsyncValue.data([]));

  @override
  Future<void> load() async => _recurringLoads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Số lần danh sách khoản định kỳ được tải lại (đặt về 0 ở mỗi lần dựng màn).
int _recurringLoads = 0;

const _vcb = '78b154c6-c8d8-4b6d-9367-981772ce5382';
const _cash = 'ca6ba2c5-38ea-4af3-a664-a79a191a3ca7';

/// Giao dịch như BE trả ở GET /transactions/{id}; [links] là các trường chỉ có từ server.
Map<String, dynamic> _tx({String type = 'Debit', String status = 'Confirmed', Map<String, dynamic> links = const {}}) => {
      'id': 't1',
      'amountCents': 35000,
      'transactionType': type,
      'categoryId': null,
      'categoryName': 'Ăn uống',
      'merchantName': 'Highlands',
      'description': '',
      'transactedAt': '2026-11-20T03:00:00Z',
      'financialAccountId': _vcb,
      'status': status,
      'source': 'Manual',
      ...links,
    };

Map<String, dynamic> _dup({String id = 't2', String source = 'Notification'}) => {
      'id': id,
      'amountCents': 35000,
      'transactedAt': '2026-11-20T03:01:00Z',
      'source': source,
      'merchantName': 'HIGHLANDS',
      'categoryName': 'Ăn uống',
      'financialAccountName': 'Vietcombank',
    };

Map<String, dynamic> _preview() => {
      'survivor': _tx(),
      'fee': {..._tx(), 'id': 'fee1', 'amountCents': 1100},
      'balanceChanges': [
        {'accountId': _vcb, 'accountName': 'Vietcombank', 'balanceBeforeCents': 1000000, 'balanceAfterCents': 965000},
        {'accountId': _cash, 'accountName': 'Ví tiền mặt', 'balanceBeforeCents': 0, 'balanceAfterCents': 100000},
      ],
      'warnings': ['Lưu ý của BE'],
    };

/// Phản hồi theo đường dẫn; [detail] là phản hồi của GET /transactions/t1, [fail] gặp mã nào thì trả 422.
RouteAdapter _adapter(Map<String, dynamic> detail, {String? failOn, int? detailStatus}) => RouteAdapter((o) {
      final path = o.path;
      if (failOn != null && path.endsWith(failOn)) {
        return respondJson({
          'success': false,
          'error': {'code': 'TRANSACTION_GROUP_FUND_LINKED', 'message': 'BE từ chối thao tác này.'},
        }, status: 422);
      }
      if (path == '/api/v1/transactions/t1' && o.method == 'GET') {
        return detailStatus != null ? ResponseBody.fromString('', detailStatus) : respondJson({'success': true, 'data': detail});
      }
      if (path.contains('/recurring-items/from-transaction/')) {
        return respondJson({
          'success': true,
          'data': {
            'id': 'r1',
            'direction': 'outflow',
            'name': 'Highlands',
            'counterpartyKey': 'highlands',
            'categoryId': null,
            'financialAccountId': _vcb,
            'amountCents': 35000,
            'cadence': 'yearly',
            'nextDueDate': '2027-11-20',
            'status': 'active',
            'source': 'manual',
            'occurrences': 0,
            'createdAt': '2026-11-20T03:00:00Z',
          },
        });
      }
      if (path.endsWith('/share-receipt')) return respondJson({'success': true, 'data': {'title': 'Biên lai Highlands', 'text': 'Chi: Highlands\nSố tiền: 35.000 ₫'}});
      if (path.endsWith('/preview')) return respondJson({'success': true, 'data': _preview()});
      if (path.endsWith('/convert-to-transfer')) return respondJson({'success': true, 'data': {'transfer': _tx(type: 'Transfer'), 'fee': null, 'warnings': []}});
      return respondJson({'success': true, 'data': detail});
    });

final _accounts = (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();

Future<(GoRouter, _FakeTx)> _pump(WidgetTester tester, RouteAdapter adapter, {TransactionEntity? entity, List<SavingsGoalEntity> goals = const []}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakeTx = _FakeTx();
  _recurringLoads = 0;
  final tx = entity ?? TransactionEntity.fromJson(_tx());
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Center(child: Text('trang danh sách')))),
    GoRoute(path: '/tx', builder: (_, __) => TransactionDetailScreen(transaction: tx)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      transactionLinksRepositoryProvider.overrideWithValue(TransactionLinksRepository(apiClient: testApiClient(adapter))),
      transactionControllerProvider.overrideWith((ref) => fakeTx),
      recurringItemsControllerProvider.overrideWith((ref) => _FakeRecurring()),
      accountsControllerProvider.overrideWith((ref) => _FakeAccounts(AsyncValue.data(_accounts))),
      categoriesProvider.overrideWith((ref) async => []),
      planningControllerProvider.overrideWith(
        (ref) => _FakePlanning(AsyncValue.data(PlanningState(overallBudget: null, categoryBudgets: const [], savingsGoals: goals, daysRemainingInMonth: 10))),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  unawaited(router.push('/tx'));
  await tester.pumpAndSettle();
  return (router, fakeTx);
}

void unawaited(Future<void> f) {}

Finder _key(String k) => find.byKey(ValueKey(k));

List<String> _calls(RouteAdapter a) => [for (final r in a.requests) if (!(r.method == 'GET' && r.path == '/api/v1/transactions/t1')) '${r.method} ${r.path}'];

void main() {
  group('mô hình', () {
    test('TransactionEntity.fromJson đọc các trường liên kết từ server', () {
      final e = TransactionEntity.fromJson(_tx(links: {
        'goalId': 'g1',
        'goalName': 'Du lịch',
        'relation': 'Refund',
        'relatedTransactionId': 't9',
        'isReversed': false,
        'refundedCents': 10000,
        'remainingRefundableCents': 25000,
        'duplicateStatus': 'Suspected',
        'duplicateOf': _dup(),
        'transferSuggestion': {
          'kind': 'WalletTopup',
          'pairedTransaction': {'id': 't7', 'amountCents': 100000, 'transactedAt': '2026-11-20T03:00:00Z', 'financialAccountId': _cash, 'financialAccountName': 'MoMo'},
          'candidateAccounts': [
            {'id': _cash, 'name': 'MoMo', 'accountType': 'EWallet'},
          ],
          'feeCents': 1000,
        },
        'groupFundLink': {'groupId': 'g', 'fundId': 'f', 'fundName': 'Quỹ trọ', 'kind': 'Expense', 'direction': 'out', 'entryDeleted': true},
        'suggestedRelatedTransactions': [
          {'transactionId': 't8', 'amountCents': 500000, 'refundedCents': 0, 'remainingRefundableCents': 500000, 'merchantName': 'Shopee', 'categoryName': 'Mua sắm', 'transactedAt': '2026-11-10T03:00:00Z'},
        ],
      }));

      final l = e.links;
      expect(l.goalName, 'Du lịch');
      expect(l.isRefundOrReversal, isTrue);
      expect(l.refundedCents, BigInt.from(10000));
      expect(l.duplicateStatus, 'suspected');
      expect(l.duplicateCandidate!.id, 't2');
      expect(l.transferSuggestion!.kind, 'WalletTopup');
      expect(l.transferSuggestion!.paired!.accountId, _cash);
      expect(l.transferSuggestion!.feeCents, BigInt.from(1000));
      expect(l.groupFundLink!.entryDeleted, isTrue);
      expect(l.suggestedRelated.single.merchantName, 'Shopee');
    });

    test('thiếu trường: coi như không có gì; nghi trùng đã bỏ qua (dismissed) không còn ứng viên', () {
      expect(TransactionEntity.fromJson(_tx()).links.duplicateCandidate, isNull);
      expect(TransactionEntity.fromJson(_tx()).links.isRefundOrReversal, isFalse);
      final dismissed = TransactionEntity.fromJson(_tx(links: {'duplicateStatus': 'Dismissed', 'duplicateOf': _dup()}));
      expect(dismissed.links.duplicateCandidate, isNull);
    });

    test('copyWith và withGroupId giữ nguyên liên kết (sửa giao dịch không làm mất gợi ý)', () {
      final e = TransactionEntity.fromJson(_tx(links: {'goalName': 'Du lịch'}));

      expect(e.copyWith(description: 'x').links.goalName, 'Du lịch');
      expect(e.withGroupId('grp').links.goalName, 'Du lịch');
    });
  });

  group('TransactionLinksRepository', () {
    test('mỗi thao tác gọi đúng phương thức, đường dẫn và nội dung', () async {
      final adapter = _adapter(_tx());
      final r = TransactionLinksRepository(apiClient: testApiClient(adapter));

      await r.getDetail('t1');
      await r.attachGoal('t1', 'g1');
      await r.detachGoal('t1');
      final share = await r.shareReceipt('t1');
      await r.notDuplicate('t1');
      await r.previewMerge('t1', 't2');
      await r.merge('t1', 't2');
      await r.previewConvertToTransfer('t1', _cash, pairedTransactionId: 't7');
      await r.convertToTransfer('t1', _cash, pairedTransactionId: 't7', clientRequestId: 'req-1');
      await r.notTransfer('t1');
      await r.createRecurring('t1', cadence: RecurringCadence.weekly);
      await r.linkRelated('t1', relatedTransactionId: 't8', relation: 'Reversal');
      await r.unlinkRelated('t1');
      await r.restoreFromFund('t1');

      expect([for (final q in adapter.requests) '${q.method} ${q.path}'], [
        'GET /api/v1/transactions/t1',
        'PUT /api/v1/transactions/t1/goal',
        'DELETE /api/v1/transactions/t1/goal',
        'POST /api/v1/transactions/t1/share-receipt',
        'POST /api/v1/transactions/t1/not-duplicate',
        'POST /api/v1/transactions/t1/merge/preview',
        'POST /api/v1/transactions/t1/merge',
        'POST /api/v1/transactions/t1/convert-to-transfer/preview',
        'POST /api/v1/transactions/t1/convert-to-transfer',
        'POST /api/v1/transactions/t1/not-transfer',
        'POST /api/v1/recurring-items/from-transaction/t1',
        'PUT /api/v1/transactions/t1/related',
        'DELETE /api/v1/transactions/t1/related',
        'POST /api/v1/transactions/t1/restore-from-fund',
      ]);
      expect(adapter.requests[1].data, {'goalId': 'g1'});
      expect(adapter.requests[5].data, {'withTransactionId': 't2'});
      expect(adapter.requests[7].data, {'counterAccountId': _cash, 'pairedTransactionId': 't7'});
      expect(adapter.requests[8].data, {'counterAccountId': _cash, 'pairedTransactionId': 't7', 'clientRequestId': 'req-1'});
      expect(adapter.requests[10].data, {'cadence': 'weekly'});
      expect(adapter.requests[11].data, {'relatedTransactionId': 't8', 'relation': 'Reversal'});
      expect(share.text, contains('35.000'));
    });

    test('xem trước đọc số dư từng ví, khoản phí và cảnh báo', () async {
      final r = TransactionLinksRepository(apiClient: testApiClient(_adapter(_tx())));

      final p = await r.previewMerge('t1', 't2');

      expect(p.balanceChanges.map((b) => b.accountName), ['Vietcombank', 'Ví tiền mặt']);
      expect(p.balanceChanges.first.afterCents, BigInt.from(965000));
      expect(p.fee!.amountCents, BigInt.from(1100));
      expect(p.warnings, ['Lưu ý của BE']);
    });
  });

  group('màn chi tiết: chung', () {
    testWidgets('giao dịch chưa đồng bộ (chỉ có ở máy): không có thẻ liên kết, không gọi API', (tester) async {
      final adapter = _adapter(_tx());
      await _pump(tester, adapter, entity: TransactionEntity.fromJson(_tx()).copyWith(isSynced: false));

      expect(_key('links-goal'), findsNothing);
      expect(_key('share-receipt'), findsNothing);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('không tải được chi tiết từ server: vẫn hiện giao dịch từ danh sách, không báo lỗi', (tester) async {
      await _pump(tester, _adapter(_tx(), detailStatus: 500));

      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
      expect(find.textContaining('35.000'), findsWidgets);
    });

    testWidgets('chia sẻ biên lai: lấy văn bản từ BE rồi mở khung chia sẻ của máy', (tester) async {
      final shared = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          shared.add(call);
          return null;
        },
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null));
      final adapter = _adapter(_tx());
      await _pump(tester, adapter);

      await tester.tap(_key('share-receipt'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/share-receipt']);
      expect(shared.single.method, 'share');
      expect(jsonEncode(shared.single.arguments), contains('Số tiền: 35.000'));
    });

    testWidgets('BE từ chối (422): hiện thông điệp của BE, màn không đóng', (tester) async {
      final adapter = _adapter(_tx(links: {'groupFundLink': {'groupId': 'g', 'fundId': 'f', 'fundName': 'Quỹ trọ', 'kind': 'Expense', 'direction': 'out', 'entryDeleted': true}}), failOn: '/restore-from-fund');
      await _pump(tester, adapter);

      await tester.tap(_key('restore-from-fund'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('mục tiêu', () {
    final goals = [SavingsGoalEntity(id: 'g1', title: 'Du lịch', targetAmountCents: BigInt.from(10000000), currentAmountCents: BigInt.zero)];

    testWidgets('chưa gắn: chọn mục tiêu gửi PUT /goal; tải lại danh sách sau đó', (tester) async {
      final adapter = _adapter(_tx());
      final (_, fakeTx) = await _pump(tester, adapter, goals: goals);

      await tester.tap(_key('attach-goal'));
      await tester.pumpAndSettle();
      await tester.tap(_key('goal-option-g1'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['PUT /api/v1/transactions/t1/goal']);
      expect(adapter.requests.singleWhere((r) => r.method == 'PUT').data, {'goalId': 'g1'});
      expect(fakeTx.loads, 1);
    });

    testWidgets('không có mục tiêu nào đang chạy: báo, không gọi API', (tester) async {
      final adapter = _adapter(_tx());
      await _pump(tester, adapter);

      await tester.tap(_key('attach-goal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa có mục tiêu tiết kiệm nào'), findsOneWidget);
      expect(_calls(adapter), isEmpty);
    });

    testWidgets('đã gắn: hiện tên mục tiêu, "Gỡ mục tiêu" gửi DELETE /goal', (tester) async {
      final adapter = _adapter(_tx(links: {'goalId': 'g1', 'goalName': 'Du lịch'}));
      await _pump(tester, adapter);

      expect(find.text('Mục tiêu: Du lịch'), findsOneWidget);
      await tester.tap(_key('detach-goal'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['DELETE /api/v1/transactions/t1/goal']);
    });

    testWidgets('chuyển ví không có hàng gắn mục tiêu', (tester) async {
      await _pump(tester, _adapter(_tx(type: 'Transfer')));

      expect(_key('links-goal'), findsNothing);
    });
  });

  group('giao dịch trùng', () {
    testWidgets('hiện giao dịch nghi trùng; "Không trùng" gửi POST not-duplicate', (tester) async {
      final adapter = _adapter(_tx(links: {'duplicateStatus': 'Suspected', 'duplicateOf': _dup()}));
      await _pump(tester, adapter);

      expect(find.text('Có thể trùng với một giao dịch khác'), findsOneWidget);
      expect(find.textContaining('Thông báo ngân hàng: 35.000'), findsOneWidget);
      await tester.tap(_key('not-duplicate'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/not-duplicate']);
    });

    testWidgets('nháp có ứng viên gợi ý (chưa có duplicateOf): vẫn hỏi', (tester) async {
      await _pump(tester, _adapter(_tx(status: 'Draft', links: {'suggestedDuplicates': [_dup(source: 'Manual')]})));

      expect(find.textContaining('Bạn nhập tay: 35.000'), findsOneWidget);
    });

    testWidgets('đã bấm "không trùng" (dismissed): không hỏi lại', (tester) async {
      await _pump(tester, _adapter(_tx(links: {'duplicateStatus': 'Dismissed', 'duplicateOf': _dup()})));

      expect(_key('links-duplicate'), findsNothing);
    });

    testWidgets('gộp: xem trước số dư rồi xác nhận mới POST merge; xong đóng màn', (tester) async {
      final adapter = _adapter(_tx(links: {'duplicateStatus': 'Suspected', 'duplicateOf': _dup()}));
      final (_, fakeTx) = await _pump(tester, adapter);

      await tester.tap(_key('merge-duplicate'));
      await tester.pumpAndSettle();
      expect(_calls(adapter), ['POST /api/v1/transactions/t1/merge/preview'], reason: 'chưa xác nhận thì chưa gộp thật');
      expect(find.text('Vietcombank: 1.000.000 ₫ → 965.000 ₫'), findsOneWidget);
      expect(find.text('Lưu ý của BE'), findsOneWidget);

      await tester.tap(_key('confirm-merge'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/merge/preview', 'POST /api/v1/transactions/t1/merge']);
      expect(adapter.requests.singleWhere((r) => r.path.endsWith('/merge')).data, {'withTransactionId': 't2'});
      expect(fakeTx.loads, 1);
      expect(find.text('trang danh sách'), findsOneWidget, reason: 'giao dịch đã gộp nên màn chi tiết đóng');
    });

    testWidgets('hủy ở bước xem trước: không gộp, màn ở lại', (tester) async {
      final adapter = _adapter(_tx(links: {'duplicateStatus': 'Suspected', 'duplicateOf': _dup()}));
      await _pump(tester, adapter);

      await tester.tap(_key('merge-duplicate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/merge/preview']);
      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
    });
  });

  group('chuyển ví', () {
    Map<String, dynamic> suggestion({bool paired = true, bool candidates = true}) => {
          'transferSuggestion': {
            'kind': 'WalletTopup',
            'pairedTransaction': paired
                ? {'id': 't7', 'amountCents': 100000, 'transactedAt': '2026-11-20T03:00:00Z', 'financialAccountId': _cash, 'financialAccountName': 'MoMo'}
                : null,
            'candidateAccounts': candidates
                ? [
                    {'id': _cash, 'name': 'MoMo', 'accountType': 'EWallet'}
                  ]
                : [],
            'feeCents': null,
          },
        };

    testWidgets('có chiều bên kia: xem trước rồi đổi, gửi đúng ví đối ứng, giao dịch ghép và mã yêu cầu; xong đóng màn', (tester) async {
      final adapter = _adapter(_tx(links: suggestion()));
      await _pump(tester, adapter);

      expect(find.textContaining('Nạp tiền vào ví điện tử'), findsOneWidget);
      expect(find.textContaining('Khớp với giao dịch 100.000'), findsOneWidget);
      await tester.tap(_key('convert-transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Phí giao dịch sẽ được ghi riêng: 1.100 ₫'), findsOneWidget);
      await tester.tap(_key('confirm-convert'));
      await tester.pumpAndSettle();

      final calls = _calls(adapter);
      expect(calls, ['POST /api/v1/transactions/t1/convert-to-transfer/preview', 'POST /api/v1/transactions/t1/convert-to-transfer']);
      final body = adapter.requests.singleWhere((r) => r.path.endsWith('/convert-to-transfer')).data as Map;
      expect(body['counterAccountId'], _cash);
      expect(body['pairedTransactionId'], 't7');
      expect((body['clientRequestId'] as String).length, greaterThan(10));
      expect(find.text('trang danh sách'), findsOneWidget);
    });

    testWidgets('chưa thấy chiều bên kia: chọn một ví trong danh sách gợi ý (không gửi pairedTransactionId)', (tester) async {
      final adapter = _adapter(_tx(links: suggestion(paired: false)));
      await _pump(tester, adapter);

      await tester.tap(_key('convert-transfer'));
      await tester.pumpAndSettle();
      await tester.tap(_key('counter-$_cash'));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-convert'));
      await tester.pumpAndSettle();

      final body = adapter.requests.singleWhere((r) => r.path.endsWith('/convert-to-transfer')).data as Map;
      expect(body, containsPair('counterAccountId', _cash));
      expect(body.containsKey('pairedTransactionId'), isFalse);
    });

    testWidgets('không có ví nào để gợi ý (rút ATM khi chưa có ví Tiền mặt): hướng dẫn tạo ví, không gọi API', (tester) async {
      final adapter = _adapter(_tx(links: suggestion(paired: false, candidates: false)));
      await _pump(tester, adapter);

      await tester.tap(_key('convert-transfer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa có ví phù hợp'), findsOneWidget);
      expect(_calls(adapter), isEmpty);
    });

    testWidgets('"Không phải" gửi POST not-transfer', (tester) async {
      final adapter = _adapter(_tx(links: suggestion()));
      await _pump(tester, adapter);

      await tester.tap(_key('not-transfer'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/not-transfer']);
    });

    testWidgets('giao dịch đã là chuyển ví thì không còn gợi ý chuyển ví', (tester) async {
      await _pump(tester, _adapter(_tx(type: 'Transfer', links: suggestion())));

      expect(_key('links-transfer'), findsNothing);
    });
  });

  group('sổ vay', () {
    final suggest = {
      'loanSuggestions': [
        {'loanId': 'L1', 'title': 'Vay anh Hòa', 'counterparty': 'Hòa', 'direction': 'Borrowed', 'remainingCents': 2000000, 'nameMatched': true, 'interestCents': 60000},
      ],
    };

    testWidgets('nháp có gợi ý khoản vay: Gắn = xác nhận kèm loanId', (tester) async {
      final adapter = _adapter(_tx(status: 'Draft', links: suggest));
      await _pump(tester, adapter);

      expect(find.text('Đây có phải tiền trả nợ cho khoản vay?'), findsOneWidget);
      expect(find.textContaining('lãi 60.000 ₫ tách riêng'), findsOneWidget);
      await tester.tap(find.descendant(of: _key('loan-option-L1'), matching: find.text('Gắn')));
      await tester.pumpAndSettle();

      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/transactions/t1/confirm'));
      expect(post.data, {'loanId': 'L1'});
    });

    testWidgets('giao dịch đã xác nhận: Gắn gửi repayments với transactionId', (tester) async {
      final adapter = _adapter(_tx(links: suggest));
      await _pump(tester, adapter);

      await tester.tap(find.descendant(of: _key('loan-option-L1'), matching: find.text('Gắn')));
      await tester.pumpAndSettle();

      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/loans/L1/repayments'));
      expect(post.data, {'transactionId': 't1'});
    });

    testWidgets('đã gắn: hiện tên khoản vay, không hỏi lại', (tester) async {
      await _pump(tester, _adapter(_tx(links: {'loanLink': {'loanId': 'L1', 'title': 'Vay anh Hòa', 'kind': 'Repayment'}})));

      expect(find.text('Thuộc khoản vay "Vay anh Hòa"'), findsOneWidget);
      expect(_key('links-loan-suggest'), findsNothing);
    });
  });

  group('hoàn tiền (chỉ gắn/gỡ liên kết)', () {
    final suggestions = {
      'suggestedRelatedTransactions': [
        {'transactionId': 't8', 'amountCents': 500000, 'refundedCents': 0, 'remainingRefundableCents': 500000, 'merchantName': 'Shopee', 'categoryName': 'Mua sắm', 'transactedAt': '2026-11-10T03:00:00Z'},
      ],
    };

    testWidgets('nháp tiền vào có gợi ý: chọn khoản chi gốc và loại "Hoàn tiền" gửi PUT related', (tester) async {
      final adapter = _adapter(_tx(type: 'Credit', status: 'Draft', links: suggestions));
      await _pump(tester, adapter);

      expect(find.text('Đây có phải tiền hoàn lại cho một khoản chi?'), findsOneWidget);
      await tester.tap(find.descendant(of: _key('related-option-t8'), matching: find.text('Chọn')));
      await tester.pumpAndSettle();
      await tester.tap(_key('relation-refund'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['PUT /api/v1/transactions/t1/related']);
      expect(adapter.requests.singleWhere((r) => r.method == 'PUT').data, {'relatedTransactionId': 't8', 'relation': 'Refund'});
    });

    testWidgets('chọn "Đảo giao dịch" gửi relation Reversal', (tester) async {
      final adapter = _adapter(_tx(type: 'Credit', status: 'Draft', links: suggestions));
      await _pump(tester, adapter);

      await tester.tap(find.descendant(of: _key('related-option-t8'), matching: find.text('Chọn')));
      await tester.pumpAndSettle();
      await tester.tap(_key('relation-reversal'));
      await tester.pumpAndSettle();

      expect(adapter.requests.singleWhere((r) => r.method == 'PUT').data, containsPair('relation', 'Reversal'));
    });

    testWidgets('đã là khoản hoàn: gỡ liên kết phải xác nhận rồi gửi DELETE related', (tester) async {
      final adapter = _adapter(_tx(type: 'Credit', links: {'relation': 'Refund', 'relatedTransactionId': 't8'}));
      await _pump(tester, adapter);

      expect(find.text('Đây là khoản hoàn tiền của một khoản chi'), findsOneWidget);
      await tester.tap(_key('unlink-related'));
      await tester.pumpAndSettle();
      expect(_calls(adapter), isEmpty, reason: 'chưa xác nhận');
      await tester.tap(_key('confirm-unlink'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['DELETE /api/v1/transactions/t1/related']);
    });

    testWidgets('trả lời "Thu nhập thường" ẩn câu hỏi mà không gọi BE', (tester) async {
      final adapter = _adapter(_tx(type: 'Credit', status: 'Draft', links: suggestions));
      await _pump(tester, adapter);

      await tester.tap(_key('related-dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('Đây có phải tiền hoàn lại cho một khoản chi?'), findsNothing);
      expect(_calls(adapter), isEmpty);
    });

    testWidgets('khoản chi còn hoàn được: "Ghi hoàn tiền" gửi POST refunds với số tiền nhập', (tester) async {
      final adapter = _adapter(_tx(links: {'refundedCents': 0, 'remainingRefundableCents': 25000}));
      await _pump(tester, adapter);

      await tester.tap(_key('record-refund'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('refund-amount'), '20000');
      await tester.tap(_key('confirm-refund'));
      await tester.pumpAndSettle();

      final post = adapter.requests.singleWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/transactions/t1/refunds'));
      expect(post.data, containsPair('amountCents', 20000));
      expect(post.data, containsPair('relation', 'Refund'));
    });

    testWidgets('khoản chi đã được hoàn một phần: chỉ hiện thông tin do BE tính', (tester) async {
      await _pump(tester, _adapter(_tx(links: {'refundedCents': 10000, 'remainingRefundableCents': 25000})));

      expect(find.text('Đã được hoàn 10.000 ₫'), findsOneWidget);
      expect(find.text('Còn có thể hoàn tối đa 25.000 ₫.'), findsOneWidget);
    });

    testWidgets('khoản chi đã bị đảo: báo đã đảo', (tester) async {
      await _pump(tester, _adapter(_tx(links: {'isReversed': true})));

      expect(find.text('Khoản chi này đã bị đảo'), findsOneWidget);
    });
  });

  group('khoản định kỳ', () {
    testWidgets('chọn chu kỳ rồi tạo: POST from-transaction gửi cadence, báo tên khoản và tải lại danh sách định kỳ', (tester) async {
      final adapter = _adapter(_tx());
      await _pump(tester, adapter);

      await tester.tap(_key('create-recurring'));
      await tester.pumpAndSettle();
      await tester.tap(_key('cadence-yearly'));
      await tester.pumpAndSettle();

      final req = adapter.requests.singleWhere((r) => r.path.contains('/recurring-items/'));
      expect('${req.method} ${req.path}', 'POST /api/v1/recurring-items/from-transaction/t1');
      expect(req.data, {'cadence': 'yearly'});
      expect(find.text('Đã tạo khoản định kỳ "Highlands".'), findsOneWidget);
      expect(_recurringLoads, 1);
    });

    testWidgets('đóng hộp chọn chu kỳ mà không chọn: không gọi API', (tester) async {
      final adapter = _adapter(_tx());
      await _pump(tester, adapter);

      await tester.tap(_key('create-recurring'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(adapter.requests.where((r) => r.path.contains('/recurring-items/')), isEmpty);
    });

    testWidgets('nháp, chuyển ví hoặc giao dịch không có tên lẫn mô tả: không có thẻ tạo khoản định kỳ', (tester) async {
      await _pump(tester, _adapter(_tx(status: 'Draft')));
      expect(_key('links-recurring'), findsNothing, reason: 'nháp');

      await _pump(tester, _adapter(_tx(type: 'Transfer')));
      expect(_key('links-recurring'), findsNothing, reason: 'chuyển ví');
    });

    testWidgets('không có tên nơi nhận lẫn mô tả: không có thẻ', (tester) async {
      await _pump(tester, _adapter(_tx(links: {'merchantName': null, 'description': ''})));

      expect(_key('links-recurring'), findsNothing);
    });

    testWidgets('BE từ chối (đã có khoản định kỳ cho người nhận này): hiện thông điệp, không tải lại danh sách', (tester) async {
      final adapter = _adapter(_tx(), failOn: '/from-transaction/t1');
      await _pump(tester, adapter);

      await tester.tap(_key('create-recurring'));
      await tester.pumpAndSettle();
      await tester.tap(_key('cadence-monthly'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('BE từ chối thao tác này.'), findsOneWidget);
      expect(_recurringLoads, 0);
    });
  });

  group('quỹ nhóm', () {
    Map<String, dynamic> fund({String kind = 'Expense', bool deleted = true}) => {
          'groupFundLink': {'groupId': 'g', 'fundId': 'f', 'fundName': 'Quỹ trọ', 'kind': kind, 'direction': 'out', 'entryDeleted': deleted},
        };

    testWidgets('dòng quỹ đã bị xóa (khoản chi): "Khôi phục khoản chi" gửi POST restore-from-fund', (tester) async {
      final adapter = _adapter(_tx(type: 'Transfer', links: fund()));
      await _pump(tester, adapter);

      expect(find.textContaining('Dòng quỹ "Quỹ trọ" đã bị người quản lý nhóm xóa'), findsOneWidget);
      await tester.tap(_key('restore-from-fund'));
      await tester.pumpAndSettle();

      expect(_calls(adapter), ['POST /api/v1/transactions/t1/restore-from-fund']);
    });

    testWidgets('loại khác khoản chi (đóng quỹ/rút quỹ): không có nút khôi phục', (tester) async {
      await _pump(tester, _adapter(_tx(type: 'Transfer', links: fund(kind: 'Contribution'))));

      expect(_key('links-fund-deleted'), findsOneWidget);
      expect(_key('restore-from-fund'), findsNothing);
    });

    testWidgets('dòng quỹ còn nguyên: chỉ ghi chú thuộc quỹ nào', (tester) async {
      await _pump(tester, _adapter(_tx(type: 'Transfer', links: fund(deleted: false))));

      expect(find.text('Thuộc quỹ nhóm "Quỹ trọ"'), findsOneWidget);
      expect(_key('restore-from-fund'), findsNothing);
    });
  });
}
