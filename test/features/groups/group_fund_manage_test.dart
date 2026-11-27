import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/screens/group_bill_detail_screen.dart';
import 'package:finmate/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:finmate/features/groups/presentation/screens/split_bill_widgets.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _fund({String name = 'Quỹ chung', String? note, int balance = 12850000, bool archived = false}) => {
      'id': 'gf1',
      'name': name,
      'note': note,
      'balanceCents': balance,
      'isNegative': false,
      'isArchived': archived,
      'archivedAt': archived ? '2026-11-20T03:00:00Z' : null,
    };

/// Người dùng hiện tại là `u1`: chủ dòng `ge1`; `ge2` là của `u2`.
Map<String, dynamic> _group({String role = 'Owner', List<String> perms = const ['ViewOverview', 'ViewActivity']}) => {
      ...(fixtureData('groups') as List)[0] as Map<String, dynamic>,
      'myRole': role,
      'myPermissions': perms,
    };

Map<String, dynamic> _bill({List<Map<String, dynamic>>? splits, String mode = 'Equal', String? note}) => {
      'id': 'b1',
      'groupId': 'g1',
      'title': 'Tiền điện tháng 11',
      'amountCents': 1000000,
      'paidByUserId': 'u1',
      'paidByName': 'Người dùng A',
      'occurredAt': '2026-11-20T10:18:44+00:00',
      'splitMode': mode,
      'note': note,
      'splitCount': 2,
      'splits': splits ??
          [
            {'userId': 'u1', 'displayName': 'Người dùng A', 'shareCents': 500000},
            {'userId': 'u2', 'displayName': 'Người dùng B', 'shareCents': 500000},
          ],
      'createdAt': '2026-11-20T10:18:44+00:00',
    };

RouteAdapter _adapter({
  Map<String, dynamic>? group,
  Map<String, dynamic>? fund,
  int? failStatus,
  String? failOn,
  Map<String, dynamic>? bill,
  int? billStatus,
}) =>
    RouteAdapter((o) {
      final path = o.path;
      if (failOn != null && path.endsWith(failOn) && failStatus != null) {
        return respondJson({
          'success': false,
          'error': {'code': 'GROUP_FUND_NOT_SETTLED', 'message': 'Quỹ còn số dư nên chưa lưu trữ được.'},
        }, status: failStatus);
      }
      if (path.contains('/bills/')) {
        return billStatus != null ? ResponseBody.fromString('', billStatus) : respondJson({'success': true, 'data': bill ?? _bill()});
      }
      if (path.endsWith('/bills')) return respondJson({'success': true, 'data': [bill ?? _bill()]});
      if (path.contains('/members')) return respondFixture('group_members');
      if (path.contains('/activities')) return respondFixture('group_activities');
      if (path.contains('/invitations')) return respondFixture('group_invitations');
      if (path.contains('/transactions')) return respondFixture('group_transactions');
      if (path.contains('/budgets')) return respondFixture('group_budgets');
      if (path.contains('/goals')) return respondFixture('group_goals');
      if (path == '/api/v1/categories') return respondFixture('categories');
      if (path.contains('/categories')) return respondFixture('group_categories');
      if (path.contains('/funds/gf1/entries/')) {
        // PATCH entry -> {entry, fund}; DELETE entry -> fund.
        if (o.method == 'DELETE') return respondJson({'success': true, 'data': fund ?? _fund()});
        return respondJson({
          'success': true,
          'data': {
            'entry': {
              'id': 'ge1',
              'kind': 'Expense',
              'amountCents': 500000,
              'transactedAt': '2026-11-10T09:15:00+00:00',
              'memberUserId': 'u1',
              'memberName': 'Người dùng A',
              'merchantName': 'Siêu thị WinMart',
            },
            'fund': fund ?? _fund(),
          },
        });
      }
      if (path.contains('/funds/') && path.contains('/summary')) return respondFixture('group_fund_summary');
      if (path.contains('/funds/') && path.contains('/entries')) return respondFixture('group_fund_entries');
      if (path.endsWith('/funds')) return respondJson({'success': true, 'data': [fund ?? _fund()]});
      if (path.contains('/funds/')) return respondJson({'success': true, 'data': fund ?? _fund()});
      if (path == '/api/v1/groups') return respondFixture('groups');
      return respondJson({'success': true, 'data': group ?? _group()});
    });

Future<void> _pumpFundTab(WidgetTester tester, RouteAdapter adapter) async {
  final container = ProviderContainer(overrides: [
    currentUserIdProvider.overrideWith((ref) => 'u1'),
    apiClientProvider.overrideWithValue(testApiClient(adapter)),
    groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: GroupDetailScreen(groupId: 'g1'))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Quỹ chung').last);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

List<RequestOptions> _writes(RouteAdapter a) => [for (final r in a.requests) if (r.method != 'GET') r];

void main() {
  group('sửa và lưu trữ quỹ', () {
    testWidgets('chủ nhóm thấy tên quỹ và nút Sửa, Lưu trữ', (tester) async {
      await _pumpFundTab(tester, _adapter());

      expect(find.text('Quỹ chung'), findsWidgets);
      expect(_key('fund-header-name'), findsOneWidget);
      expect(_key('edit-fund'), findsOneWidget);
      expect(_key('archive-fund'), findsOneWidget);
    });

    testWidgets('thành viên không có quyền quản lý quỹ: thấy tên quỹ nhưng không có nút Sửa, Lưu trữ', (tester) async {
      await _pumpFundTab(tester, _adapter(group: _group(role: 'Member', perms: ['ViewOverview'])));

      expect(_key('fund-header-name'), findsOneWidget);
      expect(_key('edit-fund'), findsNothing);
      expect(_key('archive-fund'), findsNothing);
    });

    testWidgets('người có quyền ManageFunds (không phải chủ nhóm) quản lý được quỹ', (tester) async {
      await _pumpFundTab(tester, _adapter(group: _group(role: 'Member', perms: ['ViewOverview', 'ManageFunds'])));

      expect(_key('edit-fund'), findsOneWidget);
    });

    testWidgets('đổi cả tên và ghi chú: PATCH gửi cả hai; ghi chú mới hiện trên quỹ sau khi tải lại', (tester) async {
      final adapter = _adapter();
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('edit-fund'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('fund-name'), 'Quỹ sinh hoạt');
      await tester.enterText(_key('fund-note'), 'Tiền chợ');
      await tester.tap(_key('save-fund'));
      await tester.pumpAndSettle();

      final req = _writes(adapter).single;
      expect('${req.method} ${req.path}', 'PATCH /api/v1/groups/g1/funds/gf1');
      expect(req.data, {'name': 'Quỹ sinh hoạt', 'note': 'Tiền chợ'});
      expect(find.text('Đã cập nhật quỹ.'), findsOneWidget);
    });

    testWidgets('chỉ đổi ghi chú: chỉ gửi note; xóa trống ghi chú gửi chuỗi rỗng để xóa', (tester) async {
      final adapter = _adapter(fund: _fund(note: 'Cũ'));
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('edit-fund'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('fund-note'), '');
      await tester.tap(_key('save-fund'));
      await tester.pumpAndSettle();

      expect(_writes(adapter).single.data, {'note': ''});
    });

    testWidgets('không đổi gì hoặc để trống tên: không gọi API', (tester) async {
      final adapter = _adapter();
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('edit-fund'));
      await tester.pumpAndSettle();
      await tester.tap(_key('save-fund'));
      await tester.pumpAndSettle();
      expect(_writes(adapter), isEmpty);

      await tester.tap(_key('edit-fund'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('fund-name'), '   ');
      await tester.tap(_key('save-fund'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên quỹ.'), findsOneWidget);
      expect(_writes(adapter), isEmpty);
    });

    testWidgets('lưu trữ: hỏi xác nhận (nói rõ số dư và không hoàn tác), rồi POST archive', (tester) async {
      final adapter = _adapter(fund: _fund(balance: 0));
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('archive-fund'));
      await tester.pumpAndSettle();
      expect(find.textContaining('không thể bỏ lưu trữ'), findsOneWidget);
      expect(_writes(adapter), isEmpty, reason: 'chưa xác nhận');
      await tester.tap(_key('confirm-archive-fund'));
      await tester.pumpAndSettle();

      final req = _writes(adapter).single;
      expect('${req.method} ${req.path}', 'POST /api/v1/groups/g1/funds/gf1/archive');
      expect(find.textContaining('Đã lưu trữ quỹ'), findsOneWidget);
    });

    testWidgets('quỹ còn số dư: BE từ chối (422) và thông điệp của BE được hiện', (tester) async {
      final adapter = _adapter(failOn: '/archive', failStatus: 422);
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('archive-fund'));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-archive-fund'));
      await tester.pumpAndSettle();

      expect(find.text('Quỹ còn số dư nên chưa lưu trữ được.'), findsOneWidget);
    });
  });

  group('sửa và xóa dòng quỹ', () {
    testWidgets('dòng của mình có menu; dòng của người khác chỉ có menu khi mình là người quản lý quỹ', (tester) async {
      await _pumpFundTab(tester, _adapter(group: _group(role: 'Member', perms: ['ViewOverview'])));

      expect(_key('entry-menu-ge1'), findsOneWidget, reason: 'dòng của chính mình');
      expect(_key('entry-menu-ge2'), findsNothing, reason: 'dòng của người khác, không có quyền quản lý');
    });

    testWidgets('người quản lý quỹ thấy menu ở dòng của người khác với nhãn "Sửa ghi chú"', (tester) async {
      await _pumpFundTab(tester, _adapter(group: _group(role: 'Member', perms: ['ViewOverview', 'ManageFunds'])));

      await tester.tap(_key('entry-menu-ge2'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa ghi chú'), findsOneWidget);
    });

    testWidgets('chủ dòng sửa số tiền và ghi chú: PATCH chỉ gửi phần đã đổi', (tester) async {
      final adapter = _adapter();
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('entry-menu-ge1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-edit-ge1'));
      await tester.pumpAndSettle();
      expect(_key('entry-amount'), findsOneWidget);
      expect(_key('entry-merchant'), findsOneWidget, reason: 'dòng chi của chính mình sửa được nơi nhận');
      await tester.enterText(_key('entry-amount'), '500000');
      await tester.enterText(_key('entry-note'), 'Đã trừ khuyến mãi');
      await tester.tap(_key('save-entry'));
      await tester.pumpAndSettle();

      final req = _writes(adapter).single;
      expect('${req.method} ${req.path}', 'PATCH /api/v1/groups/g1/funds/gf1/entries/ge1');
      expect(req.data, {'amountCents': 500000, 'note': 'Đã trừ khuyến mãi'});
      expect(find.text('Đã cập nhật dòng quỹ.'), findsOneWidget);
    });

    testWidgets('người quản lý sửa dòng của người khác: không có ô số tiền, chỉ gửi ghi chú', (tester) async {
      final adapter = _adapter(group: _group(role: 'Member', perms: ['ViewOverview', 'ManageFunds']));
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('entry-menu-ge2'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-edit-ge2'));
      await tester.pumpAndSettle();
      expect(_key('entry-amount'), findsNothing, reason: 'BE không cho ai sửa số tiền dòng của người khác (403)');
      expect(_key('entry-merchant'), findsNothing);
      await tester.enterText(_key('entry-note'), 'Đóng quỹ tháng 10 (đã đối chiếu)');
      await tester.tap(_key('save-entry'));
      await tester.pumpAndSettle();

      final req = _writes(adapter).single;
      expect(req.path, '/api/v1/groups/g1/funds/gf1/entries/ge2');
      expect(req.data, {'note': 'Đóng quỹ tháng 10 (đã đối chiếu)'});
    });

    testWidgets('số tiền không hợp lệ: báo lỗi, không gọi API', (tester) async {
      final adapter = _adapter();
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('entry-menu-ge1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-edit-ge1'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('entry-amount'), '0');
      await tester.tap(_key('save-entry'));
      await tester.pumpAndSettle();

      expect(find.text('Nhập số tiền lớn hơn 0.'), findsOneWidget);
      expect(_writes(adapter), isEmpty);
    });

    testWidgets('xóa dòng của mình: nói rõ giao dịch cá nhân gắn kèm bị xóa; xác nhận rồi DELETE', (tester) async {
      final adapter = _adapter();
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('entry-menu-ge1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-delete-ge1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ví của bạn được hoàn lại'), findsOneWidget);
      expect(_writes(adapter), isEmpty);
      await tester.tap(_key('confirm-delete-entry'));
      await tester.pumpAndSettle();

      final req = _writes(adapter).single;
      expect('${req.method} ${req.path}', 'DELETE /api/v1/groups/g1/funds/gf1/entries/ge1');
      expect(find.text('Đã xóa dòng quỹ.'), findsOneWidget);
    });

    testWidgets('người quản lý xóa dòng của người khác: nói rõ chỉ xóa dòng quỹ, giao dịch cá nhân giữ nguyên', (tester) async {
      await _pumpFundTab(tester, _adapter(group: _group(role: 'Member', perms: ['ViewOverview', 'ManageFunds'])));

      await tester.tap(_key('entry-menu-ge2'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-delete-ge2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('giao dịch cá nhân của người ghi vẫn được giữ nguyên'), findsOneWidget);
    });

    testWidgets('quỹ đã lưu trữ (422): thông điệp của BE được hiện, màn không đổi', (tester) async {
      final adapter = _adapter(failOn: '/entries/ge1', failStatus: 422);
      await _pumpFundTab(tester, adapter);

      await tester.tap(_key('entry-menu-ge1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('entry-delete-ge1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-delete-entry'));
      await tester.pumpAndSettle();

      expect(find.text('Quỹ còn số dư nên chưa lưu trữ được.'), findsOneWidget, reason: 'thông điệp BE trả về được hiện nguyên văn');
    });
  });

  group('GroupFundsRepository', () {
    test('updateFund, archiveFund, updateEntry, deleteEntry gọi đúng phương thức, đường dẫn và nội dung', () async {
      final adapter = _adapter();
      final r = GroupFundsRepository(apiClient: testApiClient(adapter));

      await r.updateFund(groupId: 'g1', fundId: 'gf1', name: 'A');
      final archived = await r.archiveFund(groupId: 'g1', fundId: 'gf1');
      final entry = await r.updateEntry(groupId: 'g1', fundId: 'gf1', entryId: 'ge1', amountCents: BigInt.from(500000));
      final fund = await r.deleteEntry(groupId: 'g1', fundId: 'gf1', entryId: 'ge1');

      expect([for (final q in adapter.requests) '${q.method} ${q.path}'], [
        'PATCH /api/v1/groups/g1/funds/gf1',
        'POST /api/v1/groups/g1/funds/gf1/archive',
        'PATCH /api/v1/groups/g1/funds/gf1/entries/ge1',
        'DELETE /api/v1/groups/g1/funds/gf1/entries/ge1',
      ]);
      expect(adapter.requests[0].data, {'name': 'A'}, reason: 'trường không đổi không được gửi');
      expect(adapter.requests[2].data, {'amountCents': 500000});
      expect(archived.id, 'gf1');
      expect(entry.amountCents, BigInt.from(500000));
      expect(fund.balanceCents, BigInt.from(12850000));
    });
  });

  group('chi tiết hóa đơn nhóm', () {
    Future<GoRouter?> pump(WidgetTester tester, RouteAdapter adapter, {bool fromList = false}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: fromList ? '/' : '/groups/g1/bills/b1',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: GroupBillsTab(groupId: 'g1', canShare: false)))),
          GoRoute(path: '/groups/:groupId/bills/:billId', builder: (_, s) => GroupBillDetailScreen(groupId: s.pathParameters['groupId']!, billId: s.pathParameters['billId']!)),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'u1'),
          apiClientProvider.overrideWithValue(testApiClient(adapter)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('hiện hóa đơn: tên, số tiền, người trả, cách chia và phần của từng người', (tester) async {
      await pump(tester, _adapter(bill: _bill(note: 'Chia đều cho cả nhà')));

      expect(find.text('Tiền điện tháng 11'), findsOneWidget);
      expect(tester.widget<Text>(_key('bill-amount')).data, contains('1.000.000'));
      expect(find.text('Người dùng A trả'), findsOneWidget);
      expect(find.textContaining('Chia đều'), findsWidgets);
      expect(find.text('Chia đều cho cả nhà'), findsOneWidget);
      expect(find.text('Người dùng A (người trả)'), findsOneWidget);
      expect(find.text('Người dùng B'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsNWidgets(2));
    });

    testWidgets('chia tùy chỉnh: ghi "Chia tùy chỉnh"', (tester) async {
      await pump(tester, _adapter(bill: _bill(mode: 'Custom')));

      expect(find.textContaining('Chia tùy chỉnh'), findsOneWidget);
    });

    testWidgets('BE không trả phần chia (chế độ chỉ xem tóm tắt): báo rõ, không bịa số', (tester) async {
      await pump(tester, _adapter(bill: _bill(splits: const [])));

      expect(_key('bill-no-splits'), findsOneWidget);
    });

    testWidgets('404 (không được xem hóa đơn này): hiện lỗi và nút Thử lại', (tester) async {
      await pump(tester, _adapter(billStatus: 404));

      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('bấm một hóa đơn trong danh sách mở chi tiết', (tester) async {
      final adapter = _adapter();
      await pump(tester, adapter, fromList: true);

      await tester.tap(_key('bill-b1'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết hóa đơn'), findsOneWidget);
      expect(adapter.requests.any((r) => r.path == '/api/v1/groups/g1/bills/b1'), isTrue);
    });

    test('GroupDebtsRepository.getBill gọi GET /groups/{id}/bills/{billId}', () async {
      final adapter = _adapter();
      final bill = await GroupDebtsRepository(apiClient: testApiClient(adapter)).getBill('g1', 'b1');

      expect(adapter.requests.single.path, '/api/v1/groups/g1/bills/b1');
      expect(bill.splits.length, 2);
      expect(bill, isA<GroupBillEntity>());
    });
  });
}
