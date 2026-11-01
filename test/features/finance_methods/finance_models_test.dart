import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'fake_finance_repository.dart';

void main() {
  group('đọc phản hồi thật của backend', () {
    test('khảo sát: câu hỏi, đáp án và điều kiện hiển thị', () {
      final survey = pendingSurvey();

      expect(survey.status, 'pending');
      expect(survey.questions, isNotEmpty);
      expect(survey.questions.every((q) => q.options.length >= 2), isTrue);
      expect(survey.questions.any((q) => q.showIf != null), isTrue, reason: 'khảo sát thật có câu chỉ hỏi khi câu trước trả lời theo cách nào đó');
    });

    test('gợi ý: cách chính, lý do và bố cục trang chủ', () {
      final recommendation = sampleRecommendation();

      expect(recommendation.primary.method.code, isNotEmpty);
      expect(recommendation.primary.reason, isNotEmpty);
      expect(recommendation.primary.method.homeLayout, isNotEmpty);
      expect(['ai', 'rule_fallback'], contains(recommendation.source));
    });

    test('mỗi cách trong danh mục có bố cục; cách chỉ theo dõi không có khối tiền khả dụng', () {
      final catalog = sampleCatalog();
      List<String> typesOf(String code) => catalog.firstWhere((m) => m.code == code).homeLayout.map((b) => b.type).toList();

      expect(catalog.every((m) => m.homeLayout.isNotEmpty), isTrue);
      expect(typesOf('minimal_tracking'), isNot(contains(HomeBlock.spendable)));
      expect(typesOf('debt_repayment'), isNot(contains(HomeBlock.spendable)));
      expect(typesOf('category_budget'), [HomeBlock.spendable, HomeBlock.params, HomeBlock.params, HomeBlock.goals]);
    });

    test('ngân sách theo nhóm: khối chia thu nhập trỏ tới đúng ba tham số phần trăm', () {
      final method = sampleCatalog().firstWhere((m) => m.code == 'category_budget');
      final allocation = method.homeLayout.singleWhere((b) => b.isAllocation);

      expect(allocation.keys, ['needs_pct', 'wants_pct', 'goals_pct']);
      for (final key in allocation.keys!) {
        expect(method.params.singleWhere((p) => p.key == key).isPercent, isTrue, reason: '$key phải là tham số kiểu percent');
      }
    });

    test('cách đang dùng: giá trị hiệu lực của mọi tham số', () {
      final userMethod = sampleUserMethod();

      expect(userMethod.isPrimary, isTrue);
      for (final param in userMethod.method.params) {
        expect(userMethod.effective.containsKey(param.key), isTrue, reason: param.key);
      }
    });

    test('tiền khả dụng: thu nhập là số nguyên và không có mục tiêu thì danh sách rỗng', () {
      final spendable = sampleSpendable();

      expect(spendable.incomeCents, 20000000);
      expect(spendable.spendableCents, 20000000);
      expect(spendable.goals, isEmpty);
    });

    test('mẫu mục tiêu gợi ý', () {
      expect(sampleSuggestions(), isNotEmpty);
      expect(sampleSuggestions().first.templateCode, isNotEmpty);
    });
  });

  group('các hũ (phản hồi thật của backend)', () {
    test('mỗi hũ có số được chia, đã chi, còn lại và mức; chi ngoài hũ được tách riêng', () {
      final set = jarSetsFixture().single;

      expect(set.incomeCents, 20000000);
      expect(set.unassignedSpentCents, 500000);
      expect(set.jars.map((j) => j.key), ['needs_pct', 'wants_pct', 'goals_pct']);
      final wants = set.jars.singleWhere((j) => j.key == 'wants_pct');
      expect((wants.allocationPct, wants.allocatedCents, wants.spentCents, wants.usedPct, wants.level), (30, 6000000, 5400000, 90, Jar.levelT2));
      expect(wants.remainingCents, 600000);
      expect(set.jars.first.categories, isNotEmpty);
      expect(set.jars.last.categories, isEmpty, reason: 'hũ chưa gán danh mục luôn là 0 đã chi');
    });

    test('hũ gắn với đúng cách người dùng đang dùng và khối "jars" nằm trong bố cục của cách đó', () {
      final userMethod = userMethodWithJars();

      expect(jarSetsFixture().single.userMethodId, userMethod.id);
      expect(userMethod.method.homeLayout.map((b) => b.type), contains(HomeBlock.jars));
    });

    test('chưa khai thu nhập: số được chia, còn lại và % đã dùng là null, không phải 0', () {
      final jar = Jar.fromJson({'key': 'a', 'label': 'A', 'allocationPct': 50, 'allocatedCents': null, 'spentCents': 10, 'remainingCents': null, 'usedPct': null, 'level': 'none', 'categories': []});

      expect((jar.allocatedCents, jar.remainingCents, jar.usedPct), (null, null, null));
    });
  });

  group('cách quản lý bị admin tắt', () {
    test('người đang dùng vẫn nhận được cách đó, đánh dấu không còn cung cấp và vẫn đủ dữ liệu để hiển thị', () {
      final methods = unavailableUserMethods();

      expect(methods, hasLength(1));
      expect(methods.single.method.available, isFalse);
      expect(methods.single.method.homeLayout, isNotEmpty, reason: 'trang chủ của cách đó vẫn vẽ được như cũ');
      expect(methods.single.effective, isNotEmpty);
    });

    test('cách còn cung cấp và backend cũ chưa có trường này đều coi là còn cung cấp', () {
      expect(sampleUserMethod().method.available, isTrue);
      expect(FinanceMethod.fromJson({'code': 'x'}).available, isTrue);
    });
  });

  group('ngưỡng cảnh báo (phản hồi thật của backend)', () {
    test('chưa có gì: theo mặc định hệ thống, chưa có ngưỡng cá nhân', () {
      final settings = thresholdsFixture('system');

      expect(settings.source, AlertThresholdSettings.sourceSystem);
      expect(settings.effective, settings.systemDefault);
      expect(settings.personal, isNull);
      expect(settings.followsMethod, isFalse);
    });

    test('đã đặt ngưỡng cá nhân: ngưỡng hiệu lực chính là ngưỡng cá nhân', () {
      final settings = thresholdsFixture('personal');

      expect(settings.source, AlertThresholdSettings.sourcePersonal);
      expect(settings.effective, const ThresholdPair(50, 80));
      expect(settings.personal, settings.effective);
    });

    test('đang dùng cách quản lý có ngưỡng: theo cách đó, ngưỡng cá nhân vẫn được giữ', () {
      final settings = thresholdsFixture('method');

      expect(settings.followsMethod, isTrue);
      expect(settings.methodCode, 'category_budget');
      expect(settings.methodName, isNotEmpty);
      expect(settings.effective, isNot(settings.personal), reason: 'ngưỡng cá nhân bị cách quản lý che chứ không bị xóa');
      expect(settings.personal, const ThresholdPair(50, 80));
    });

    test('ThresholdPair.isValid: cùng quy tắc với backend (1 ≤ T1 < T2 ≤ 99)', () {
      expect(ThresholdPair.isValid(70, 90), isTrue);
      expect(ThresholdPair.isValid(1, 2), isTrue);
      expect(ThresholdPair.isValid(98, 99), isTrue);
      expect(ThresholdPair.isValid(90, 70), isFalse);
      expect(ThresholdPair.isValid(80, 80), isFalse);
      expect(ThresholdPair.isValid(0, 50), isFalse);
      expect(ThresholdPair.isValid(50, 100), isFalse);
    });
  });

  group('ParamDef.format', () {
    ParamDef def(String type) => ParamDef(key: 'k', label: 'L', type: type, defaultValue: 0, min: 0, max: 1, userEditable: true);

    test('theo kiểu của tham số', () {
      expect(def('percent').format(70), '70%');
      expect(def('minutes').format(1320), '22:00');
      expect(def('minutes').format(65), '01:05');
      expect(def('cents').format(1000000), '1.000.000 ₫');
      expect(def('int').format(3), '3');
    });
  });

  group('điều kiện hiển thị (showIf)', () {
    const gated = {
      'all': [
        {
          'question': 'q1',
          'in': ['A'],
        },
      ],
    };
    const exclusion = {
      'all': [
        {
          'question': 'q1',
          'not_in': ['A'],
        },
      ],
    };

    test('câu trước chưa trả lời: in sai, not_in đúng', () {
      expect(showIfHolds(gated, {}), isFalse);
      expect(showIfHolds(exclusion, {}), isTrue);
    });

    test('theo đáp án của câu trước', () {
      expect(showIfHolds(gated, {'q1': 'A'}), isTrue);
      expect(showIfHolds(gated, {'q1': 'B'}), isFalse);
      expect(showIfHolds(exclusion, {'q1': 'A'}), isFalse);
    });

    test('cấu hình hỏng thì HIỆN câu, không làm mất câu khảo sát', () {
      expect(showIfHolds(null, {}), isTrue);
      expect(showIfHolds({'all': 'sai'}, {}), isTrue);
      expect(showIfHolds({'all': [<String, dynamic>{}]}, {}), isTrue);
    });

    test('câu ẩn không đưa đáp án cũ của nó vào điều kiện của câu sau', () {
      SurveyQuestion question(String code, Map<String, dynamic>? showIf) => SurveyQuestion(
            code: code,
            group: 'g',
            text: code,
            showIf: showIf,
            options: const [SurveyOption(code: 'A', text: 'a'), SurveyOption(code: 'B', text: 'b')],
          );
      final questions = [
        question('q1', null),
        question('q2', gated),
        question('q3', {
          'all': [
            {
              'question': 'q2',
              'in': ['A'],
            },
          ],
        }),
      ];

      // q1=B nên q2 ẩn; dù còn đáp án cũ q2=A thì q3 cũng phải ẩn theo.
      expect(visibleQuestions(questions, {'q1': 'B', 'q2': 'A'}).map((q) => q.code), ['q1']);
      expect(visibleQuestions(questions, {'q1': 'A', 'q2': 'A'}).map((q) => q.code), ['q1', 'q2', 'q3']);
    });
  });

  group('bố cục trang chủ', () {
    test('khối không có loại bị bỏ; loại lạ vẫn đọc được để lớp vẽ tự bỏ qua', () {
      final method = FinanceMethod.fromJson({
        'code': 'x',
        'homeLayout': [
          {'type': ''},
          {'type': 'hologram'},
          {'type': 'params', 'title': 'T', 'keys': ['a'], 'display': 'allocation'},
          'khong-phai-object',
        ],
      });

      expect(method.homeLayout.map((b) => b.type), ['hologram', 'params']);
      expect(method.homeLayout.last.isAllocation, isTrue);
      expect(method.homeLayout.last.keys, ['a']);
    });

    test('backend cũ chưa có homeLayout thì rỗng, không lỗi', () {
      expect(FinanceMethod.fromJson({'code': 'x'}).homeLayout, isEmpty);
    });
  });
}
