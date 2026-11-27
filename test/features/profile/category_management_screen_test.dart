import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/profile/presentation/screens/category_management_screen.dart';

const _system = Category(id: 's1', name: 'Di chuyển', slug: 'transport');
const _mine = Category(id: 'm1', name: 'Cà phê', slug: 'ca-phe', iconName: 'coffee', isSystem: false);

class _FakeCategoriesController implements CategoriesController {
  final deleted = <String>[];
  @override
  Future<void> delete(String id) async => deleted.add(id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Object? extraOpened;

  Future<void> pump(WidgetTester tester, Future<List<Category>> Function() load, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    extraOpened = null;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const CategoryManagementScreen()),
      GoRoute(
        path: '/profile/categories/form',
        builder: (_, state) {
          extraOpened = state.extra ?? 'NEW';
          return const Text('FORM_PAGE');
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'u1'),
        categoriesProvider.overrideWith((ref) => load()),
        allCategoriesProvider.overrideWith((ref) => load()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('gom thành danh mục của bạn và hệ thống, đếm đúng ở hai tab', (tester) async {
    await pump(tester, () async => [_system, _mine]);

    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Tự tạo (1)'), findsOneWidget);
    expect(find.text('Danh mục của bạn'), findsOneWidget);
    expect(find.text('Danh mục hệ thống'), findsOneWidget);
    expect(find.text('Chưa cài đặt hạn mức'), findsNWidgets(2));

    await tester.tap(find.text('Tự tạo (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Danh mục hệ thống'), findsNothing);
    expect(find.text('Cà phê'), findsOneWidget);
  });

  testWidgets('danh mục hệ thống: chạm mở hộp đặt hạn mức (không mở form sửa), để trống thì báo lỗi', (tester) async {
    await pump(tester, () async => [_system]);

    await tester.tap(find.byKey(const ValueKey('category-s1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-limit-input')), findsOneWidget);
    expect(find.text('FORM_PAGE'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-limit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-limit-input')), findsNothing);
  });

  testWidgets('ẩn danh mục: hàng hệ thống có nút ẩn (trừ "Khác"); danh mục đã ẩn nằm nhóm "Đã ẩn" với nút hiện lại và không tính vào đếm', (tester) async {
    const other = Category(id: 's2', name: 'Khác', slug: 'other');
    const hiddenFood = Category(id: 's3', name: 'Ăn uống', slug: 'food', isHidden: true);
    await pump(tester, () async => [_system, other, hiddenFood, _mine]);

    expect(find.byKey(const ValueKey('hide-category-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hide-category-s2')), findsNothing);
    expect(find.byKey(const ValueKey('hide-category-m1')), findsNothing);
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Đã ẩn'), findsOneWidget);
    expect(find.byKey(const ValueKey('show-category-s3')), findsOneWidget);

    await tester.tap(find.text('Tự tạo (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Đã ẩn'), findsNothing);
  });

  testWidgets('tìm kiếm lọc theo tên; chỉ danh mục tự tạo mở được màn sửa tên/biểu tượng', (tester) async {
    await pump(tester, () async => [_system, _mine]);

    await tester.tap(find.byKey(const ValueKey('category-s1')));
    await tester.pumpAndSettle();
    expect(find.text('FORM_PAGE'), findsNothing, reason: 'danh mục hệ thống không sửa tên/biểu tượng được');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('category-search')), 'cà');
    await tester.pumpAndSettle();
    expect(find.text('Di chuyển'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-m1')));
    await tester.pumpAndSettle();
    expect(find.text('FORM_PAGE'), findsOneWidget);
    expect(extraOpened, _mine);
  });

  testWidgets('hiện hạn mức gợi ý (khi chưa có hạn mức thật), dấu yêu thích; màu nhận diện tô nền icon', (tester) async {
    final colored = Category(
      id: 'm2', name: 'Ăn trưa', slug: 'an-trua', iconName: 'utensils', isSystem: false,
      color: '#F0C8A0', suggestedBudgetCents: BigInt.from(1500000), isFavorite: true,
    );
    await pump(tester, () async => [_system, _mine, colored]);

    expect(find.text('Hạn mức gợi ý: 1.500.000 ₫/tháng'), findsOneWidget);
    expect(find.byKey(const ValueKey('favorite-m2')), findsNothing);
    final row = find.descendant(of: find.byKey(const ValueKey('category-m2')), matching: find.byType(Container));
    final tinted = tester.widgetList<Container>(row).map((c) => c.decoration).whereType<BoxDecoration>().any((d) => d.color == const Color(0xFFF0C8A0).withValues(alpha: 0.35));
    expect(tinted, isTrue, reason: 'nền icon lấy màu danh mục');
  });

  testWidgets('nút thêm mở form tạo mới', (tester) async {
    await pump(tester, () async => [_system]);

    await tester.ensureVisible(find.byKey(const ValueKey('add-category-bottom')));
    await tester.tap(find.byKey(const ValueKey('add-category-bottom')));
    await tester.pumpAndSettle();
    expect(extraOpened, 'NEW');
  });

  testWidgets('lỗi tải hiện thông điệp và Thử lại; 320dp không tràn', (tester) async {
    var fail = true;
    await pump(tester, () async {
      if (fail) throw NetworkException();
      return [_system];
    }, width: 320);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Di chuyển'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vuốt danh mục tự tạo để xóa: hỏi xác nhận, hủy thì không xóa; danh mục hệ thống không vuốt được', (tester) async {
    final fake = _FakeCategoriesController();
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'u1'),
        categoriesProvider.overrideWith((ref) async => [_system, _mine]),
        allCategoriesProvider.overrideWith((ref) async => [_system, _mine]),
        categoriesControllerProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: CategoryManagementScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dismiss-s1')), findsNothing);
    await tester.drag(find.byKey(const ValueKey('dismiss-m1')), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Xóa "Cà phê"?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(fake.deleted, isEmpty);

    await tester.drag(find.byKey(const ValueKey('dismiss-m1')), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-category')));
    await tester.pumpAndSettle();
    expect(fake.deleted, ['m1']);
  });
}
