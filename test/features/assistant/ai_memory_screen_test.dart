import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/domain/agent_memory.dart';
import 'package:finmate/features/assistant/presentation/screens/ai_memory_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _list(List<Map<String, dynamic>> data) => {'success': true, 'data': data, 'error': null, 'meta': null};

const _tone = {'key': 'communication_tone', 'value': 'Ngắn gọn, thân thiện', 'updatedAt': '2026-11-10T08:00:00Z'};

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: AiMemoryScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('AgentMemoryEntry.fromJson và 4 khóa hợp lệ', () {
    final e = AgentMemoryEntry.fromJson(_tone);
    expect(e.key, 'communication_tone');
    expect(e.value, 'Ngắn gọn, thân thiện');
    expect(agentMemorySlots.map((s) => s.key), [
      'preferred_method',
      'eating_out_weekends',
      'notification_quiet_hours',
      'communication_tone',
    ]);
  });

  testWidgets('hiện 4 sở thích với tên thân thiện, mục đã đặt hiện giá trị thật', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondJson(_list([_tone]))));

    expect(find.text('Giọng điệu trợ lý'), findsOneWidget);
    expect(find.text('Ngắn gọn, thân thiện'), findsOneWidget);
    expect(find.text('Giờ yên lặng của thông báo'), findsOneWidget);
    expect(find.text('Chưa đặt'), findsNWidgets(3));
  });

  testWidgets('đặt một sở thích gọi PUT /agent/memory/{key} với value', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PUT') return respondJson({}, status: 204);
      return respondJson(_list([]));
    });
    await _pump(tester, adapter);

    await tester.tap(find.byTooltip('Thêm: Giọng điệu trợ lý'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Ngắn gọn');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.path, '/api/v1/agent/memory/communication_tone');
    expect(put.data, {'value': 'Ngắn gọn'});
  });

  testWidgets('xóa một mục gọi DELETE, xóa tất cả gọi DELETE /agent/memory', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE') return respondJson({'success': true, 'data': 1});
      return respondJson(_list([_tone]));
    });
    await _pump(tester, adapter);

    await tester.tap(find.byTooltip('Xóa: Giọng điệu trợ lý'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE').single.path, '/api/v1/agent/memory/communication_tone');

    await tester.tap(find.byTooltip('Xóa toàn bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa hết'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE').last.path, '/api/v1/agent/memory');
  });

  testWidgets('nút Thêm ghi nhớ chỉ cho chọn sở thích chưa đặt rồi gọi PUT; đặt đủ 4 thì ẩn nút', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PUT') return respondJson({}, status: 204);
      return respondJson(_list([_tone]));
    });
    await _pump(tester, adapter);

    await tester.tap(find.text('Thêm ghi nhớ'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn sở thích muốn thêm'), findsOneWidget);
    // Giọng điệu đã đặt nên không còn trong danh sách chọn (chỉ còn trong thẻ phía sau).
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Giờ yên lặng của thông báo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '22:00 - 07:00');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(adapter.requests.singleWhere((r) => r.method == 'PUT').path, '/api/v1/agent/memory/notification_quiet_hours');
  });

  testWidgets('đã đặt đủ 4 sở thích thì không hiện nút Thêm ghi nhớ', (tester) async {
    final all = [
      for (final s in agentMemorySlots) {'key': s.key, 'value': 'x', 'updatedAt': '2026-11-10T08:00:00Z'},
    ];
    await _pump(tester, RouteAdapter((o) => respondJson(_list(all))));
    expect(find.text('Thêm ghi nhớ'), findsNothing);
  });

  testWidgets('ô tìm kiếm lọc theo tên hoặc nội dung; chip Đã đặt chỉ giữ mục có giá trị; không khớp thì báo trống', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondJson(_list([_tone]))));
    expect(find.text('Tất cả (4)'), findsOneWidget);
    expect(find.text('Đã đặt (1)'), findsOneWidget);
    expect(find.text('Chưa đặt (3)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('memory-filter-set')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa đặt'), findsNothing);
    expect(find.text('Ngắn gọn, thân thiện'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('memory-filter-all')));
    await tester.enterText(find.byKey(const ValueKey('memory-search')), 'yên lặng');
    await tester.pumpAndSettle();
    expect(find.text('Giờ yên lặng của thông báo'), findsOneWidget);
    expect(find.text('Giọng điệu trợ lý'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('memory-search')), 'không có gì khớp');
    await tester.pumpAndSettle();
    expect(find.text('Không có ghi nhớ phù hợp.'), findsOneWidget);
  });

  testWidgets('lỗi tải hiện thông điệp và Thử lại', (tester) async {
    var fail = true;
    final adapter = RouteAdapter((o) {
      if (fail) throwNetworkDown(o);
      return respondJson(_list([_tone]));
    });
    await _pump(tester, adapter);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Ngắn gọn, thân thiện'), findsOneWidget);
  });
}
