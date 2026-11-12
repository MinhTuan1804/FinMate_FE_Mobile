import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/subscriptions/data/subscriptions_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('SubscriptionsRepository', () {
    test('listPlans trả đúng danh sách, giá tính bằng BigInt, gói free giá null', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_plans'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      final plans = await repo.listPlans();

      expect(adapter.to('/api/v1/subscriptions/plans').single.method, 'GET');
      expect(plans, hasLength(2));
      expect(plans[0].code, 'free');
      expect(plans[0].monthlyPriceCents, isNull);
      expect(plans[1].code, 'pro');
      expect(plans[1].monthlyPriceCents, BigInt.from(4900000));
      expect(plans[1].features, hasLength(2));
      expect(plans[1].features[1].monthlyLimit, 200);
    });

    test('getMine trả gói hiện tại + lượt dùng từng chức năng', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_me'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      final mine = await repo.getMine();

      expect(mine.planCode, 'free');
      expect(mine.isFree, isTrue);
      expect(mine.expiresAt, isNull);
      expect(mine.features, hasLength(2));
      expect(mine.features[0].used, 5);
      expect(mine.features[1].enabled, isFalse);
    });

    test('listOrders trả đúng cycle/status PascalCase nguyên văn và amountCents BigInt', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_orders'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      final orders = await repo.listOrders();

      expect(orders, hasLength(2));
      expect(orders[0].cycle, 'Monthly');
      expect(orders[0].status, 'Paid');
      expect(orders[0].isPaid, isTrue);
      expect(orders[0].amountCents, BigInt.from(4900000));
      expect(orders[1].status, 'Pending');
      expect(orders[1].isPaid, isFalse);
      expect(orders[1].paidAt, isNull);
    });

    test('listOrders rỗng trả danh sách rỗng', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_orders_empty'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      expect(await repo.listOrders(), isEmpty);
    });

    test('createWebSession gửi đúng planId và trả url/expiresAt', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_web_session'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      final link = await repo.createWebSession(planId: '22222222-2222-2222-2222-222222222222');

      final req = adapter.to('/api/v1/subscriptions/web-session').single;
      expect(req.method, 'POST');
      expect(req.data, {'planId': '22222222-2222-2222-2222-222222222222'});
      expect(link.url, 'https://billing.finmate.vn/subscribe?code=abc123');
    });

    test('createWebSession không truyền planId thì không gửi field planId', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_web_session'));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      await repo.createWebSession();

      final req = adapter.to('/api/v1/subscriptions/web-session').single;
      expect(req.data, {});
    });

    test('BE tắt tính năng đăng ký gói thì ném BusinessRuleException đúng message', () async {
      final adapter = RouteAdapter((o) => respondFixture('subscriptions_error_disabled', status: 400));
      final repo = SubscriptionsRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.createWebSession(),
        throwsA(isA<BusinessRuleException>()
            .having((e) => e.code, 'code', 'SUBSCRIPTION_DISABLED')
            .having((e) => e.message, 'message', 'Tính năng đăng ký gói hiện chưa được bật.')),
      );
    });
  });
}
