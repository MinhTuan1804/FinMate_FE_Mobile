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
}
