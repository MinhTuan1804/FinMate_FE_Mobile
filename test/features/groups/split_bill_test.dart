import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/domain/group_fund.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/screens/create_bill_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_approvals_screen.dart';
import 'package:finmate/features/groups/presentation/screens/i4_members_screen.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _group({String role = 'Owner', String model = 'SplitBill'}) => {
      ...(fixtureData('groups') as List)[0] as Map<String, dynamic>,
      'myRole': role,
      'settlementModel': model,
      'myPermissions': ['ShareTransactions', 'InviteMembers'],
    };

Map<String, dynamic> _approval(String id, {String status = 'Pending', String kind = 'Bill'}) => {
      'id': id,
      'groupId': 'g1',
      'kind': kind,
      'status': status,
      'amountCents': 6000000,
      'title': 'Đặt cọc phòng',
      'requestedByUserId': 'u2',
      'requestedByName': 'Người dùng B',
      'createdAt': '2026-11-20T10:18:45+00:00',
      'decidedByUserId': null,
      'decidedAt': null,
      'decisionReason': null,
      'resultId': null,
    };

Map<String, dynamic> _bill() => {
      'id': 'b1',
      'groupId': 'g1',
      'title': 'Tiền điện tháng 11',
      'amountCents': 1000000,
      'paidByUserId': 'u1',
      'paidByName': 'Người dùng A',
      'occurredAt': '2026-11-20T10:18:44+00:00',
      'splitMode': 'Equal',
      'note': null,
      'splitCount': 2,
      'splits': [
        {'userId': 'u1', 'displayName': 'Người dùng A', 'shareCents': 500000},
        {'userId': 'u2', 'displayName': 'Người dùng B', 'shareCents': 500000},
      ],
      'createdAt': '2026-11-20T10:18:44+00:00',
    };

void main() {
  Future<void> pump(WidgetTester tester, RouteAdapter adapter, Widget home, {GoRouter? router}) async {
    final api = testApiClient(adapter);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(api),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: api)),
      groupDebtsRepositoryProvider.overrideWithValue(GroupDebtsRepository(apiClient: api)),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router != null ? MaterialApp.router(routerConfig: router) : MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  group('GroupDebtsRepository', () {
    test('createBill: 201 là hóa đơn thật, 202 là yêu cầu chờ duyệt (không phải hóa đơn)', () async {
      var status = 201;
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': status == 201 ? _bill() : _approval('a1')}, status: status));
      final repo = GroupDebtsRepository(apiClient: testApiClient(adapter));

      final created = await repo.createBill(
        groupId: 'g1',
        title: 'Tiền điện',
        amountCents: BigInt.from(1000000),
        paidByUserId: 'u1',
        splitMode: 'Equal',
        splits: [GroupBillSplitInput(userId: 'u1', shareCents: BigInt.zero), GroupBillSplitInput(userId: 'u2', shareCents: BigInt.zero)],
      );
      expect(created.isPending, isFalse);
      expect(created.bill!.splitCount, 2);

      status = 202;
      final pending = await repo.createBill(
        groupId: 'g1',
        title: 'Đặt cọc',
        amountCents: BigInt.from(6000000),
        paidByUserId: 'u1',
        splitMode: 'Equal',
        splits: [GroupBillSplitInput(userId: 'u1', shareCents: BigInt.zero)],
      );
      expect(pending.isPending, isTrue);
      expect(pending.pending!.status, 'Pending');
      expect(adapter.requests.first.data, containsPair('splitMode', 'Equal'));
    });

    test('getBalances đọc số nợ ròng (âm = đang nợ) và lượt chuyển tối giản; Manual thì transfers null', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': true,
            'data': {
              'method': 'AiOptimized',
              'members': [
                {'userId': 'u1', 'displayName': 'A', 'isActive': true, 'netCents': 500000},
                {'userId': 'u2', 'displayName': 'B', 'isActive': true, 'netCents': -500000},
              ],
              'transfers': [
                {'fromUserId': 'u2', 'toUserId': 'u1', 'amountCents': 500000},
              ],
              'formerMembersNetCents': null,
            },
          }));
      final b = await GroupDebtsRepository(apiClient: testApiClient(adapter)).getBalances('g1');

      expect(b.netOf('u2'), BigInt.from(-500000));
      expect(b.transfersOf('u1').single.amountCents, BigInt.from(500000));

      final manual = GroupBalancesEntity.fromJson({'method': 'Manual', 'members': [], 'transfers': null});
      expect(manual.transfers, isNull);
    });
  });

  test('GroupFundsRepository.createEntry: HTTP 202 (chờ duyệt) trả null thay vì ném lỗi đọc dữ liệu', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': _approval('a9', kind: 'FundEntry')}, status: 202));
    final repo = GroupFundsRepository(apiClient: testApiClient(adapter));

    final entry = await repo.createEntry(
      groupId: 'g1',
      fundId: 'f1',
      kind: GroupFundEntryKind.expense,
      amountCents: BigInt.from(7000000),
      groupCategoryId: 'c1',
    );

    expect(entry, isNull);
  });

  group('CreateBillScreen', () {
    RouteAdapter billAdapter({int status = 201}) => RouteAdapter((o) {
          if (o.method == 'POST') return respondJson({'success': true, 'data': status == 201 ? _bill() : _approval('a1')}, status: status);
          if (o.path.endsWith('/members')) return respondFixture('group_members');
          return respondJson({'success': true, 'data': []});
        });

    testWidgets('chia đều: gửi Equal kèm người trả và các thành viên cùng chia', (tester) async {
      final adapter = billAdapter();
      final router = GoRouter(initialLocation: '/new', routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/new', builder: (_, __) => const CreateBillScreen(groupId: 'g1')),
      ]);
      await pump(tester, adapter, const SizedBox(), router: router);

      await tester.enterText(find.byKey(const ValueKey('bill-title')), 'Tiền điện tháng 11');
      await tester.enterText(find.byKey(const ValueKey('bill-amount')), '1000000');
      await tester.ensureVisible(find.byKey(const ValueKey('bill-submit')));
      await tester.tap(find.byKey(const ValueKey('bill-submit')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(req.data['title'], 'Tiền điện tháng 11');
      expect(req.data['amountCents'], 1000000);
      expect(req.data['paidByUserId'], 'u1');
      expect(req.data['splitMode'], 'Equal');
      expect((req.data['splits'] as List).map((s) => s['userId']), ['u1', 'u2']);
    });

    testWidgets('tùy chỉnh: tổng các phần khác số tiền thì báo lỗi và KHÔNG gọi server', (tester) async {
      final adapter = billAdapter();
      await pump(tester, adapter, const CreateBillScreen(groupId: 'g1'));

      await tester.enterText(find.byKey(const ValueKey('bill-title')), 'Mua đồ');
      await tester.enterText(find.byKey(const ValueKey('bill-amount')), '600000');
      await tester.tap(find.text('Tùy chỉnh'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('bill-share-u1')), '100000');
      await tester.enterText(find.byKey(const ValueKey('bill-share-u2')), '200000');
      await tester.ensureVisible(find.byKey(const ValueKey('bill-submit')));
      await tester.tap(find.byKey(const ValueKey('bill-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('bill-error')), findsOneWidget);
      expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('server trả 202: báo "chờ chủ nhóm duyệt", không báo đã chia', (tester) async {
      final adapter = billAdapter(status: 202);
      final router = GoRouter(initialLocation: '/new', routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/new', builder: (_, __) => const CreateBillScreen(groupId: 'g1')),
      ]);
      await pump(tester, adapter, const SizedBox(), router: router);

      await tester.enterText(find.byKey(const ValueKey('bill-title')), 'Đặt cọc');
      await tester.enterText(find.byKey(const ValueKey('bill-amount')), '6000000');
      await tester.ensureVisible(find.byKey(const ValueKey('bill-submit')));
      await tester.tap(find.byKey(const ValueKey('bill-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('chờ chủ nhóm duyệt'), findsOneWidget);
      expect(find.text('Đã chia hóa đơn.'), findsNothing);
    });
  });

  group('GroupApprovalsScreen', () {
    RouteAdapter approvalsAdapter({String role = 'Owner'}) => RouteAdapter((o) {
          if (o.path.endsWith('/approve')) return respondJson({'success': true, 'data': _approval('a1', status: 'Approved')});
          if (o.path.endsWith('/reject')) return respondJson({'success': true, 'data': _approval('a1', status: 'Rejected')});
          if (o.path.endsWith('/approvals')) return respondJson({'success': true, 'data': [_approval('a1')]});
          return respondJson({'success': true, 'data': _group(role: role)});
        });

    testWidgets('chủ nhóm thấy khoản chờ duyệt và duyệt được (POST approve)', (tester) async {
      final adapter = approvalsAdapter();
      await pump(tester, adapter, const GroupApprovalsScreen(groupId: 'g1'));

      expect(find.text('Đặt cọc phòng'), findsOneWidget);
      expect(find.text('Hóa đơn chia'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('approve-a1')));
      await tester.pumpAndSettle();

      expect(adapter.requests.where((r) => r.method == 'POST').single.path, '/api/v1/groups/g1/approvals/a1/approve');
    });

    testWidgets('từ chối kèm lý do: gửi POST reject với reason', (tester) async {
      final adapter = approvalsAdapter();
      await pump(tester, adapter, const GroupApprovalsScreen(groupId: 'g1'));

      await tester.tap(find.byKey(const ValueKey('reject-a1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('reject-reason')), 'Để báo giá khác');
      await tester.tap(find.byKey(const ValueKey('reject-confirm')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(req.path, '/api/v1/groups/g1/approvals/a1/reject');
      expect(req.data, {'reason': 'Để báo giá khác'});
    });

    testWidgets('người không phải chủ nhóm chỉ xem, không có nút duyệt/từ chối', (tester) async {
      await pump(tester, approvalsAdapter(role: 'Member'), const GroupApprovalsScreen(groupId: 'g1'));

      expect(find.text('Đặt cọc phòng'), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-a1')), findsNothing);
      expect(find.byKey(const ValueKey('reject-a1')), findsNothing);
    });
  });

  group('I4 sổ nợ', () {
    RouteAdapter debtAdapter({int tooSoon = 0}) => RouteAdapter((o) {
          if (o.path.endsWith('/remind-debt')) {
            if (tooSoon > 0) {
              return respondJson({
                'success': false,
                'data': null,
                'error': {'code': 'GROUP_REMINDER_COOLDOWN', 'message': 'Mọi người đều đã được nhắc gần đây. Hãy thử lại sau.', 'details': null},
              }, status: 429);
            }
            return respondJson({'success': true, 'data': {'sent': ['u2'], 'skipped': []}});
          }
          if (o.path.endsWith('/balances')) {
            return respondJson({
              'success': true,
              'data': {
                'method': 'AiOptimized',
                'members': [
                  {'userId': 'u1', 'displayName': 'Người dùng A', 'isActive': true, 'netCents': 500000},
                  {'userId': 'u2', 'displayName': 'Người dùng B', 'isActive': true, 'netCents': -500000},
                ],
                'transfers': [
                  {'fromUserId': 'u2', 'toUserId': 'u1', 'amountCents': 500000},
                ],
                'formerMembersNetCents': null,
              },
            });
          }
          if (o.path.endsWith('/members')) return respondFixture('group_members');
          if (o.path.contains('/funds')) return respondJson({'success': true, 'data': []});
          return respondJson({'success': true, 'data': _group()});
        });

    testWidgets('hiện tình trạng thanh toán, số nợ từng người và nhắc nợ gọi đúng API', (tester) async {
      final adapter = debtAdapter();
      await pump(tester, adapter, const I4MembersScreen(groupId: 'g1'));

      expect(find.text('Bạn đang ứng trước cho nhóm:'), findsOneWidget);
      expect(find.textContaining('+500.000'), findsOneWidget);
      expect(find.byKey(const ValueKey('net-u2')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('net-u2')), matching: find.text('Đang nợ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('net-u2')), matching: find.textContaining('500.000')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remind-u2')));
      await tester.pumpAndSettle();

      expect(adapter.requests.firstWhere((r) => r.method == 'POST').path, '/api/v1/groups/g1/members/u2/remind-debt');
      expect(find.textContaining('Đã gửi nhắc nợ cho 1 người'), findsOneWidget);
    });

    testWidgets('nhắc quá sớm (429): hiện đúng thông báo của server, không báo đã gửi', (tester) async {
      await pump(tester, debtAdapter(tooSoon: 1), const I4MembersScreen(groupId: 'g1'));

      await tester.tap(find.byKey(const ValueKey('remind-u2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã gửi nhắc nợ'), findsNothing);
      expect(find.textContaining('nhắc gần đây'), findsOneWidget);
    });
  });
}
