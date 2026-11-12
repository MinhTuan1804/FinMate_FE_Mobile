import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import '../../fixtures/fixture.dart';

void main() {
  test('Category.fromJson đọc categories.json thật (11 danh mục, có food)', () {
    final list = (fixtureData('categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(11));
    final food = list.firstWhere((c) => c.slug == 'food');
    expect(food.name, 'Ăn uống');
    expect(food.isSystem, isTrue);
  });

  test('categoryIcon ánh xạ slug sang icon Lucide, mặc định là tag', () {
    expect(categoryIcon('food'), LucideIcons.utensils);
    expect(categoryIcon('transport'), LucideIcons.car);
    expect(categoryIcon('loan'), LucideIcons.handshake);
    expect(categoryIcon('không-tồn-tại'), LucideIcons.tag);
    expect(categoryIcon(null), LucideIcons.tag);
  });

  test('categoriesProvider: có người dùng thì tải từ API, chưa đăng nhập thì rỗng và không gọi API', () async {
    final adapter = RouteAdapter((o) => respondFixture('categories'));
    final userId = StateProvider<String?>((ref) => 'u1');
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
      categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(categoriesProvider.future), hasLength(11));

    container.read(userId.notifier).state = null;
    expect(await container.read(categoriesProvider.future), isEmpty);
    expect(adapter.requests, hasLength(1));
  });

  group('CategoriesRepository', () {
    test('createCategory gửi name + iconName, trả về danh mục mới', () async {
      final created = {...(fixtureData('categories') as List)[0] as Map<String, dynamic>, 'name': 'Thú cưng', 'isSystem': false};
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': created}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      final result = await repo.createCategory(name: 'Thú cưng', iconName: 'pets');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.data, {'name': 'Thú cưng', 'iconName': 'pets'});
      expect(result.name, 'Thú cưng');
    });

    test('createCategory không gửi iconName khi không có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('categories') as List)[0]}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      await repo.createCategory(name: 'Thú cưng');

      expect(adapter.requests.single.data, {'name': 'Thú cưng'});
    });

    test('updateCategory PATCH đúng path và body', () async {
      final updated = {...(fixtureData('categories') as List)[0] as Map<String, dynamic>, 'name': 'Di chuyển (sửa)'};
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': updated}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      final result = await repo.updateCategory(id: '97ce1e37-b3f6-4394-8ff7-b1dd50ddea83', name: 'Di chuyển (sửa)');

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, contains('/categories/97ce1e37-b3f6-4394-8ff7-b1dd50ddea83'));
      expect(result.name, 'Di chuyển (sửa)');
    });

    test('deleteCategory gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      await repo.deleteCategory('97ce1e37-b3f6-4394-8ff7-b1dd50ddea83');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/categories/97ce1e37-b3f6-4394-8ff7-b1dd50ddea83'));
    });
  });

  group('categoriesControllerProvider', () {
    test('create/update/delete làm categoriesProvider tải lại (invalidate)', () async {
      var listCalls = 0;
      final adapter = RouteAdapter((o) {
        if (o.method == 'GET') {
          listCalls++;
          return respondFixture('categories');
        }
        if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('categories') as List)[0]});
        if (o.method == 'PATCH') return respondJson({'success': true, 'data': (fixtureData('categories') as List)[0]});
        return respondJson({'success': true, 'data': null}); // DELETE
      });
      final userId = StateProvider<String?>((ref) => 'u1');
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);

      await container.read(categoriesProvider.future);
      expect(listCalls, 1);

      await container.read(categoriesControllerProvider).create(name: 'Thú cưng');
      expect(await container.read(categoriesProvider.future), hasLength(11));
      expect(listCalls, 2, reason: 'create phải invalidate để danh sách tải lại');

      await container.read(categoriesControllerProvider).update(id: '97ce1e37-b3f6-4394-8ff7-b1dd50ddea83', name: 'X');
      await container.read(categoriesProvider.future);
      expect(listCalls, 3);

      await container.read(categoriesControllerProvider).delete('97ce1e37-b3f6-4394-8ff7-b1dd50ddea83');
      await container.read(categoriesProvider.future);
      expect(listCalls, 4);
    });
  });
}
