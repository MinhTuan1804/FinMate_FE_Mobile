import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/profile/presentation/screens/category_form_screen.dart';
import '../../fixtures/fixture.dart';

/// Màn H13: tên, loại chi/thu, biểu tượng, màu (bảng màu từ server), nhóm cha, hạn mức gợi ý, yêu thích.
void main() {
  const mine = Category(id: 'm1', name: 'Cà phê', slug: 'ca-phe', iconName: 'coffee', isSystem: false);
  final foodId = ((fixtureData('categories') as List).cast<Map<String, dynamic>>().firstWhere((c) => c['slug'] == 'food'))['id'] as String;

  const palette = {
    'palette': [
      {'key': 'a', 'hex': '#AAAAAA', 'name': 'Màu A'},
      {'key': 'b', 'hex': '#BBBBBB', 'name': 'Màu B'},
    ],
    'kinds': ['expense', 'income'],
  };

  Future<RouteAdapter> pump(WidgetTester tester, {Category? editing, bool optionsFail = false}) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE') return respondJson({}, status: 204);
      if (o.method == 'GET' && o.path.endsWith('/categories/options')) {
        return optionsFail ? respondJson({'success': false, 'data': null}, status: 500) : respondJson({'success': true, 'data': palette});
      }
      if (o.method == 'GET') return respondFixture('categories');
      return respondJson({'success': true, 'data': (fixtureData('categories') as List).first});
    });
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/form', builder: (_, __) => CategoryFormScreen(editing: editing)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    router.push('/form');
    await tester.pumpAndSettle();
    return adapter;
  }

  Finder parentDropdown() => find.byWidgetPredicate((w) => w is DropdownButtonFormField);

  testWidgets('tạo mới: thiếu tên báo lỗi; có tên và icon thì POST kèm màu đầu bảng và loại chi tiêu rồi quay lại', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên danh mục.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byKey(const ValueKey('category-name')), '  Du lịch  ');
    await tester.tap(find.byKey(const ValueKey('icon-plane')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/api/v1/categories');
    expect(post.data, {'name': 'Du lịch', 'iconName': 'plane', 'color': '#AAAAAA', 'kind': 'expense'});
    expect(find.byType(CategoryFormScreen), findsNothing);
  });

  testWidgets('bảng màu lấy từ server: hiện đúng các màu, chọn màu đổi tên màu và xem trước', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('color-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('color-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('color-coral')), findsNothing, reason: 'không dùng bảng mặc định khi server trả bảng riêng');
    expect(find.text('Màu A'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('color-b')));
    await tester.pumpAndSettle();

    expect(find.text('Màu B'), findsOneWidget);
    final preview = tester.widget<Container>(find.byKey(const ValueKey('category-preview')));
    expect((preview.decoration as BoxDecoration).border!.top.color, const Color(0xFFBBBBBB));
  });

  testWidgets('không tải được bảng màu: dùng bảng mặc định, màn hình vẫn lưu được', (tester) async {
    final adapter = await pump(tester, optionsFail: true);

    expect(find.byKey(const ValueKey('color-honey')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Mặc định');
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'POST').data, containsPair('color', '#F4A5A5'));
  });

  testWidgets('đủ các trường: loại, màu, nhóm cha, hạn mức gợi ý và yêu thích đều được gửi đúng', (tester) async {
    final adapter = await pump(tester);

    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Cà phê & Gặp gỡ');
    await tester.tap(find.byKey(const ValueKey('icon-coffee')));
    await tester.tap(find.byKey(const ValueKey('color-b')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(parentDropdown());
    await tester.tap(parentDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-budget')), '1500000');
    await tester.pumpAndSettle();
    expect(find.text('1.500.000'), findsOneWidget, reason: 'tự thêm dấu chấm phần nghìn');
    await tester.ensureVisible(find.byKey(const ValueKey('category-favorite')));
    await tester.tap(find.byKey(const ValueKey('category-favorite')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'POST').data, {
      'name': 'Cà phê & Gặp gỡ',
      'iconName': 'coffee',
      'color': '#BBBBBB',
      'kind': 'expense',
      'parentCategoryId': foodId,
      'suggestedBudgetCents': 1500000,
      'isFavorite': true,
    });
  });

  testWidgets('đổi sang Khoản thu nhập: gửi kind income và bỏ nhóm cha đã chọn trước đó', (tester) async {
    final adapter = await pump(tester);

    await tester.ensureVisible(parentDropdown());
    await tester.tap(parentDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-kind-income')));
    await tester.tap(find.byKey(const ValueKey('category-kind-income')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Lương thêm');
    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    final data = adapter.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(data['kind'], 'income');
    expect(data.containsKey('parentCategoryId'), isFalse, reason: 'nhóm cha thuộc loại cũ nên bị bỏ khi đổi loại');
  });

  testWidgets('hạn mức quá lớn bị chặn, không gọi API', (tester) async {
    final adapter = await pump(tester);

    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Quá lớn');
    await tester.ensureVisible(find.byKey(const ValueKey('category-budget')));
    await tester.enterText(find.byKey(const ValueKey('category-budget')), '9999999999999');
    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(find.text('Hạn mức không hợp lệ.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('sửa: điền sẵn tên, PATCH đúng id và gửi đủ trạng thái (bỏ nhóm cha và hạn mức bằng giá trị riêng)', (tester) async {
    final adapter = await pump(tester, editing: mine);

    expect(find.widgetWithText(TextFormField, 'Cà phê'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Cà phê sáng');
    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/api/v1/categories/m1');
    expect(patch.data, {
      'name': 'Cà phê sáng',
      'iconName': 'coffee',
      'kind': 'expense',
      'parentCategoryId': kNoParentId,
      'suggestedBudgetCents': 0,
      'isFavorite': false,
    });
  });

  testWidgets('sửa danh mục đã có màu, nhóm, hạn mức, yêu thích: điền sẵn đúng và giữ nguyên khi lưu', (tester) async {
    final full = Category(
      id: 'm2', name: 'Ăn trưa', slug: 'an-trua', iconName: 'utensils', isSystem: false,
      color: '#BBBBBB', kind: 'expense', parentCategoryId: foodId, suggestedBudgetCents: BigInt.from(500000), isFavorite: true,
    );
    final adapter = await pump(tester, editing: full);

    expect(find.text('Màu B'), findsOneWidget);
    expect(find.text('500.000'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('category-favorite'))).value, isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'PATCH').data, {
      'name': 'Ăn trưa',
      'iconName': 'utensils',
      'color': '#BBBBBB',
      'kind': 'expense',
      'parentCategoryId': foodId,
      'suggestedBudgetCents': 500000,
      'isFavorite': true,
    });
  });

  testWidgets('sửa: chọn "Không chọn nhóm" và xóa hạn mức thì gửi giá trị bỏ nhóm cha và hạn mức', (tester) async {
    final full = Category(
      id: 'm2', name: 'Ăn trưa', slug: 'an-trua', iconName: 'utensils', isSystem: false,
      parentCategoryId: foodId, suggestedBudgetCents: BigInt.from(500000),
    );
    final adapter = await pump(tester, editing: full);

    await tester.ensureVisible(parentDropdown());
    await tester.tap(parentDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không chọn nhóm').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-budget')), '');
    await tester.ensureVisible(find.byKey(const ValueKey('category-save')));
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    final data = adapter.requests.singleWhere((r) => r.method == 'PATCH').data as Map;
    expect(data['parentCategoryId'], kNoParentId);
    expect(data['suggestedBudgetCents'], 0);
  });

  testWidgets('xóa danh mục: hỏi xác nhận rồi gọi DELETE', (tester) async {
    final adapter = await pump(tester, editing: mine);

    await tester.ensureVisible(find.byKey(const ValueKey('category-delete')));
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'DELETE').path, '/api/v1/categories/m1');
    expect(find.byType(CategoryFormScreen), findsNothing);
  });

  testWidgets('tạo mới không có nút xóa', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('category-delete')), findsNothing);
  });
}
