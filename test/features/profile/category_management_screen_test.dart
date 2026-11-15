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

  testWidgets('tìm kiếm lọc theo tên; chỉ danh mục tự tạo mở được màn sửa', (tester) async {
    await pump(tester, () async => [_system, _mine]);

    await tester.tap(find.byKey(const ValueKey('category-s1')));
    await tester.pumpAndSettle();
    expect(find.text('FORM_PAGE'), findsNothing, reason: 'danh mục hệ thống không sửa được');

    await tester.enterText(find.byKey(const ValueKey('category-search')), 'cà');
    await tester.pumpAndSettle();
    expect(find.text('Di chuyển'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-m1')));
    await tester.pumpAndSettle();
    expect(find.text('FORM_PAGE'), findsOneWidget);
    expect(extraOpened, _mine);
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
}
