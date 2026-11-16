import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_colors.dart';
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

  test('Category.fromJson đọc màu, loại, nhóm cha, hạn mức gợi ý và yêu thích; thiếu thì dùng mặc định', () {
    final full = Category.fromJson({
      'id': 'c1', 'name': 'Cà phê', 'slug': 'ca-phe', 'iconName': 'coffee', 'isSystem': false,
      'color': '#F0C8A0', 'kind': 'income', 'parentCategoryId': 'p1', 'suggestedBudgetCents': 1500000, 'isFavorite': true,
    });
    expect(full.color, '#F0C8A0');
    expect(full.kind, 'income');
    expect(full.parentCategoryId, 'p1');
    expect(full.suggestedBudgetCents, BigInt.from(1500000));
    expect(full.isFavorite, isTrue);

    final old = Category.fromJson({'id': 'c2', 'name': 'Cũ', 'slug': 'cu'});
    expect(old.color, isNull);
    expect(old.kind, 'expense');
    expect(old.parentCategoryId, isNull);
    expect(old.suggestedBudgetCents, isNull);
    expect(old.isFavorite, isFalse);
  });

  test('CategoryOptions.fromJson đọc bảng màu; bảng mặc định có 8 màu và mã hợp lệ', () {
    final options = CategoryOptions.fromJson({
      'palette': [
        {'key': 'honey', 'hex': '#F0C8A0', 'name': 'Cam mật ong'},
      ],
      'kinds': ['expense', 'income'],
    });
    expect(options.palette.single.name, 'Cam mật ong');
    expect(CategoryOptions.fallback.palette, hasLength(8));
    expect(CategoryOptions.fallback.palette.every((c) => RegExp(r'^#[0-9A-F]{6}$').hasMatch(c.hex)), isTrue);
  });

  test('parseHexColor đọc #RRGGBB, sai dạng thì null; sameHexColor không phân biệt hoa thường', () {
    expect(parseHexColor('#F0C8A0'), const Color(0xFFF0C8A0));
    expect(parseHexColor('f0c8a0'), const Color(0xFFF0C8A0));
    expect(parseHexColor('#12345'), isNull);
    expect(parseHexColor('#GGGGGG'), isNull);
    expect(parseHexColor(null), isNull);
    expect(sameHexColor('#f0c8a0', '#F0C8A0'), isTrue);
    expect(sameHexColor('#F0C8A0', '#8FB3E0'), isFalse);
    expect(sameHexColor(null, '#F0C8A0'), isFalse);
  });

  test('categoryOptionsProvider: lấy bảng màu từ server; lỗi mạng thì dùng bảng mặc định, không ném', () async {
    final good = RouteAdapter((o) => respondJson({
          'success': true,
          'data': {'palette': [{'key': 'a', 'hex': '#AAAAAA', 'name': 'A'}], 'kinds': ['expense', 'income']},
        }));
    final containerGood = ProviderContainer(overrides: [categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(good)))]);
    addTearDown(containerGood.dispose);
    expect((await containerGood.read(categoryOptionsProvider.future)).palette.single.key, 'a');
    expect(good.requests.single.path, '/api/v1/categories/options');

    final bad = RouteAdapter((o) => respondJson({'success': false, 'data': null}, status: 500));
    final containerBad = ProviderContainer(overrides: [categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(bad)))]);
    addTearDown(containerBad.dispose);
    expect((await containerBad.read(categoryOptionsProvider.future)).palette, hasLength(8));
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

    test('createCategory gửi thêm màu, loại, nhóm cha, hạn mức gợi ý (đồng) và yêu thích khi có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('categories') as List)[0]}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      await repo.createCategory(
        name: 'Cà phê', iconName: 'coffee', color: '#F0C8A0', kind: 'income', parentCategoryId: 'p1', suggestedBudgetCents: BigInt.from(1500000), isFavorite: true,
      );

      expect(adapter.requests.single.data, {
        'name': 'Cà phê', 'iconName': 'coffee', 'color': '#F0C8A0', 'kind': 'income', 'parentCategoryId': 'p1', 'suggestedBudgetCents': 1500000, 'isFavorite': true,
      });
    });

    test('updateCategory: null = không gửi (giữ nguyên); kNoParentId và 0 để bỏ nhóm cha và hạn mức', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('categories') as List)[0]}));
      final repo = CategoriesRepository(apiClient: testApiClient(adapter));

      await repo.updateCategory(id: 'c1', name: 'Chỉ tên');
      await repo.updateCategory(id: 'c1', name: 'Bỏ hết', parentCategoryId: kNoParentId, suggestedBudgetCents: BigInt.zero, isFavorite: false);

      expect(adapter.requests[0].data, {'name': 'Chỉ tên'});
      expect(adapter.requests[1].data, {'name': 'Bỏ hết', 'parentCategoryId': '00000000-0000-0000-0000-000000000000', 'suggestedBudgetCents': 0, 'isFavorite': false});
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
