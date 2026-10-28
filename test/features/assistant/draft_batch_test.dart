import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import '../../fixtures/fixture.dart';

/// Câu nhiều danh mục chỉ cần xác nhận MỘT lần: một thẻ gộp "Lưu tất cả", ghi cả nhóm ở máy trong một lần (được tất cả hoặc không gì).
class _Repo extends AssistantRepository {
  _Repo() : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async => ChatReply.fromJson(fixtureData('chat_confirm_multi') as Map<String, dynamic>);
}

DraftTransaction draft(int cents, String? slug, {String? account = 'acc-1', List<String> missing = const [], TransactionType type = TransactionType.expense, String desc = 'món'}) => DraftTransaction(
      amountCents: BigInt.from(cents),
      type: type,
      description: desc,
      categorySlug: slug,
      suggestedAccountId: account,
      missingFields: missing,
    );

const _categories = [
  Category(id: 'cat-food', name: 'Ăn uống', slug: 'food'),
  Category(id: 'cat-transport', name: 'Di chuyển', slug: 'transport'),
  Category(id: 'cat-income', name: 'Thu nhập', slug: 'income'),
];

void main() {
  late List<List<DraftSave>> batches; // mỗi lần gọi saveAll
  late int syncs;
  late int dataChanged;
  late bool failSaveAll;
  late bool categoriesLoaded;

  AssistantController controller() {
    final saver = DraftSaver(
      categoryIdOf: (slug) => categoriesLoaded ? 'cat-$slug' : null,
      save: (d, {required categoryId, required accountId, required clientRequestId}) async => throw StateError('thẻ gộp phải dùng saveAll'),
      saveAll: (items) async {
        if (failSaveAll) throw Exception('ghi đĩa lỗi');
        batches.add(items);
      },
      syncNow: () async => syncs++,
    );
    return AssistantController(repository: _Repo(), saver: saver, onDataChanged: () => dataChanged++);
  }

  setUp(() {
    batches = [];
    syncs = 0;
    dataChanged = 0;
    failSaveAll = false;
    categoriesLoaded = true;
  });

  group('một thẻ gộp cho câu nhiều khoản', () {
    test('câu nhiều khoản hiện MỘT thẻ gộp, không phải mỗi khoản một thẻ nháp', () async {
      final c = controller();
      await c.send('ăn cơm 20k, uống nước 10k, đổ xăng 50k'); // phản hồi thật của BE (fixture chat_confirm_multi)

      expect(c.state.messages.whereType<DraftCard>(), isEmpty);
      final batch = c.state.messages.whereType<DraftBatchCard>().single;
      expect(batch.drafts.map((d) => d.amountCents), [BigInt.from(20000), BigInt.from(10000), BigInt.from(50000)]);
      expect(batch.requestIds.toSet(), hasLength(3)); // mỗi khoản một mã chống trùng, giữ nguyên khi thử lại
    });

    test('Lưu tất cả: MỘT lần ghi ở máy cho cả nhóm, mỗi khoản một giao dịch theo danh mục của nó, rồi đồng bộ ngầm', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);
      final batch = c.state.messages.whereType<DraftBatchCard>().single;

      await c.confirmBatch(batch.id);
      await pumpEventQueue();

      expect(batches, hasLength(1));
      expect(batches.single.map((i) => (i.draft.amountCents, i.categoryId, i.accountId, i.requestId)), [
        (BigInt.from(40000), 'cat-food', 'acc-1', batch.requestIds[0]),
        (BigInt.from(70000), 'cat-transport', 'acc-1', batch.requestIds[1]),
      ]);
      final after = c.state.messages.whereType<DraftBatchCard>().single;
      expect(after.resolved, isTrue);
      expect(after.resolvedSummary, contains('2 giao dịch'));
      expect(syncs, 1);
      expect(dataChanged, 2); // sau khi ghi ở máy, và sau khi đồng bộ ngầm xong
      expect(c.state.isSending, isFalse);
    });

    test('chưa tải được danh mục của một khoản: không ghi gì, nói rõ, thử lại được', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;
      categoriesLoaded = false;

      await c.confirmBatch(id);

      expect(batches, isEmpty);
      expect(c.state.messages.whereType<DraftBatchCard>().single.error, contains('danh mục'));

      categoriesLoaded = true;
      await c.confirmBatch(id);
      expect(batches, hasLength(1));
      expect(c.state.messages.whereType<DraftBatchCard>().single.resolved, isTrue);
    });

    test('ghi ở máy lỗi: không khoản nào được coi là đã lưu, bấm lại dùng đúng các mã cũ', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);
      final batch = c.state.messages.whereType<DraftBatchCard>().single;
      failSaveAll = true;

      await c.confirmBatch(batch.id);

      expect(c.state.messages.whereType<DraftBatchCard>().single.resolved, isFalse);
      expect(c.state.messages.whereType<DraftBatchCard>().single.error, isNotNull);
      expect(dataChanged, 0);

      failSaveAll = false;
      await c.confirmBatch(batch.id);

      expect(batches.single.map((i) => i.requestId), batch.requestIds);
      expect(c.state.messages.whereType<DraftBatchCard>().single.resolved, isTrue);
    });

    test('còn khoản thiếu danh mục thì không lưu gì và nói rõ', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, null, missing: ['category'])]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;

      await c.confirmBatch(id);

      expect(batches, isEmpty);
      expect(c.state.messages.whereType<DraftBatchCard>().single.error, contains('bổ sung'));
    });

    test('chọn danh mục ngay trên thẻ: khoản thiếu được điền và thẻ sẵn sàng để Lưu tất cả', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, null, missing: ['category'])]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;
      expect(c.state.messages.whereType<DraftBatchCard>().single.allComplete, isFalse);

      c.setBatchCategory(id, 1, 'transport');

      final batch = c.state.messages.whereType<DraftBatchCard>().single;
      expect(batch.drafts[1].categorySlug, 'transport');
      expect(batch.drafts[1].missingFields, isEmpty);
      expect(batch.allComplete, isTrue);
      await c.confirmBatch(id);
      expect(batches.single.map((i) => i.categoryId), ['cat-food', 'cat-transport']);
    });

    test('sửa một dòng ngay trên thẻ: số tiền, ghi chú và danh mục; các dòng khác giữ nguyên', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food', desc: 'ăn phở'), draft(70000, 'transport', desc: 'đổ xăng')]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;

      c.updateBatchDraft(id, 0, amountCents: BigInt.from(45000), description: 'ăn phở bò', categorySlug: 'transport');

      final batch = c.state.messages.whereType<DraftBatchCard>().single;
      expect((batch.drafts[0].amountCents, batch.drafts[0].description, batch.drafts[0].categorySlug), (BigInt.from(45000), 'ăn phở bò', 'transport'));
      expect(batch.drafts[1].amountCents, BigInt.from(70000));
      await c.confirmBatch(id);
      expect(batches.single.map((i) => i.draft.amountCents), [BigInt.from(45000), BigInt.from(70000)]);
      expect(batches.single.map((i) => i.requestId), batch.requestIds); // sửa không đổi mã chống trùng
    });

    test('số tiền sửa không hợp lệ (0, âm, không phải số) bị bỏ qua, giữ số cũ', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;

      c.updateBatchDraft(id, 0, amountCents: BigInt.zero);
      c.updateBatchDraft(id, 0, amountCents: BigInt.from(-5));

      expect(c.state.messages.whereType<DraftBatchCard>().single.drafts[0].amountCents, BigInt.from(40000));
    });

    test('khoản thu dùng danh mục thu nhập', () async {
      final c = controller();
      c.addBatch([draft(12000000, null, type: TransactionType.income), draft(20000, 'food')]);

      await c.confirmBatch(c.state.messages.whereType<DraftBatchCard>().single.id);

      expect(batches.single.map((i) => i.categoryId), ['cat-income', 'cat-food']);
    });

    test('chuyển tiền giữa hai ví tách riêng thành thẻ nháp, các khoản còn lại vẫn gộp được', () async {
      final c = controller();
      final transfer = DraftTransaction(kind: DraftKind.transfer, amountCents: BigInt.from(1000), type: TransactionType.transfer, missingFields: const ['accounts']);

      c.addBatch([draft(40000, 'food'), transfer, draft(70000, 'transport')]);

      final m = c.state.messages;
      expect(m.map((e) => e.runtimeType), [DraftBatchCard, DraftCard]);
      expect(m.whereType<DraftBatchCard>().single.drafts, hasLength(2));
      expect(m.whereType<DraftBatchCard>().single.allComplete, isTrue);
      expect(m.whereType<DraftCard>().single.draft.kind, DraftKind.transfer);
    });

    test('một khoản thường và một chuyển tiền: hai thẻ nháp riêng, không có thẻ gộp một dòng', () async {
      final c = controller();
      final transfer = DraftTransaction(kind: DraftKind.transfer, amountCents: BigInt.from(1000), type: TransactionType.transfer);

      c.addBatch([draft(40000, 'food'), transfer]);

      expect(c.state.messages.map((e) => e.runtimeType), [DraftCard, DraftCard]);
    });

    test('Sửa từng khoản: thẻ gộp đổi thành các thẻ nháp riêng', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);

      c.splitBatch(c.state.messages.whereType<DraftBatchCard>().single.id);

      expect(c.state.messages.whereType<DraftBatchCard>(), isEmpty);
      expect(c.state.messages.whereType<DraftCard>().map((m) => m.draft.amountCents), [BigInt.from(40000), BigInt.from(70000)]);
    });

    test('đang lưu thì bấm lần nữa không lưu hai lần', () async {
      final c = controller();
      c.addBatch([draft(40000, 'food'), draft(70000, 'transport')]);
      final id = c.state.messages.whereType<DraftBatchCard>().single.id;

      final first = c.confirmBatch(id);
      await c.confirmBatch(id);
      await first;

      expect(batches, hasLength(1));
    });
  });

  group('thẻ gộp trên màn hình', () {
    Future<AssistantController> pump(WidgetTester tester, List<DraftTransaction> drafts) async {
      final c = controller();
      c.addBatch(drafts);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          assistantControllerProvider.overrideWith((ref) => c),
          categoriesProvider.overrideWith((ref) async => _categories),
        ],
        child: Consumer(builder: (context, ref, _) {
          final batch = ref.watch(assistantControllerProvider).messages.whereType<DraftBatchCard>().single;
          return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DraftBatchCardView(card: batch))));
        }),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('hiện từng khoản kèm danh mục, tổng, và MỘT nút Lưu tất cả', (tester) async {
      await pump(tester, [draft(40000, 'food', desc: 'ăn phở'), draft(70000, 'transport', desc: 'đổ xăng')]);

      expect(find.text('Xác nhận 2 khoản'), findsOneWidget);
      expect(find.textContaining('Ăn uống'), findsOneWidget);
      expect(find.textContaining('Di chuyển'), findsOneWidget);
      expect(find.textContaining('110.000'), findsOneWidget);
      expect(find.byKey(const ValueKey('batch-save')), findsOneWidget);
    });

    testWidgets('khoản chi có dấu trừ, khoản thu có dấu cộng, tổng là thu trừ chi', (tester) async {
      await pump(tester, [
        draft(1000000, 'food', desc: 'xem phim'),
        draft(10000000, 'income', type: TransactionType.income, desc: 'mẹ cho'),
        draft(2000000, 'food', desc: 'đi chơi'),
      ]);

      expect(find.text('-1.000.000 ₫'), findsOneWidget);
      expect(find.text('+10.000.000 ₫'), findsOneWidget);
      expect(find.text('-2.000.000 ₫'), findsOneWidget);
      expect(find.text('+7.000.000 ₫'), findsOneWidget); // 10 - 1 - 2, không phải cộng gộp 13 triệu
    });

    testWidgets('chỉ toàn khoản chi thì tổng âm', (tester) async {
      await pump(tester, [draft(40000, 'food'), draft(70000, 'transport')]);

      expect(find.text('-110.000 ₫'), findsOneWidget);
    });

    testWidgets('bấm Lưu tất cả một lần là lưu hết và thẻ chuyển sang đã ghi', (tester) async {
      await pump(tester, [draft(40000, 'food'), draft(70000, 'transport')]);

      await tester.tap(find.byKey(const ValueKey('batch-save')));
      await tester.pumpAndSettle();

      expect(batches, hasLength(1));
      expect(find.textContaining('Đã ghi 2 giao dịch'), findsOneWidget);
      expect(find.byKey(const ValueKey('batch-save')), findsNothing);
    });

    testWidgets('bấm vào một dòng để sửa số tiền và ghi chú rồi lưu: thẻ cập nhật dòng và tổng', (tester) async {
      await pump(tester, [draft(40000, 'food', desc: 'ăn phở'), draft(70000, 'transport', desc: 'đổ xăng')]);

      await tester.tap(find.byKey(const ValueKey('batch-row-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-amount')), '45.000');
      await tester.enterText(find.byKey(const ValueKey('edit-note')), 'ăn phở bò');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('ăn phở bò'), findsOneWidget);
      expect(find.textContaining('45.000'), findsOneWidget);
      expect(find.textContaining('115.000'), findsOneWidget); // tổng mới
    });

    testWidgets('sửa số tiền thành không hợp lệ thì báo lỗi và không đóng khung', (tester) async {
      await pump(tester, [draft(40000, 'food'), draft(70000, 'transport')]);

      await tester.tap(find.byKey(const ValueKey('batch-row-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-amount')), 'abc');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('edit-save')), findsOneWidget);
      expect(find.textContaining('số tiền'), findsWidgets);
    });

    testWidgets('khoản thiếu danh mục có nút Chọn danh mục; chọn xong thì Lưu tất cả hiện ra', (tester) async {
      await pump(tester, [draft(40000, 'food'), draft(70000, null, missing: ['category'])]);
      expect(find.byKey(const ValueKey('batch-save')), findsNothing);
      expect(find.byKey(const ValueKey('batch-pick-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('batch-pick-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pick-income')), findsNothing); // khoản chi không được chọn danh mục thu nhập
      await tester.tap(find.byKey(const ValueKey('pick-transport')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('batch-pick-1')), findsNothing);
      expect(find.byKey(const ValueKey('batch-save')), findsOneWidget);
    });
  });
}
