import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart';
import 'package:finmate/features/assistant/data/local_first_chat.dart';
import 'package:finmate/features/assistant/data/pending_message_store.dart';
import 'package:finmate/features/assistant/domain/agent_answer.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/data/loans_repository.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/data_refresh.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

/// Một tin nhắn trong hội thoại; [id] tăng dần trong phiên
sealed class ChatMessage {
  final int id;
  const ChatMessage(this.id);
}

class UserText extends ChatMessage {
  final String text;
  const UserText(super.id, this.text);
}

/// Ảnh hóa đơn người dùng vừa gửi để quét
class ImageNote extends ChatMessage {
  final String path;
  const ImageNote(super.id, this.path);
}

class AssistantText extends ChatMessage {
  final String text;
  const AssistantText(super.id, this.text);
}

class SavedCard extends ChatMessage {
  final TransactionEntity tx;
  const SavedCard(super.id, this.tx);
}

class SummaryCard extends ChatMessage {
  final ChatSummary summary;
  const SummaryCard(super.id, this.summary);
}

class DraftCard extends ChatMessage {
  final DraftTransaction draft;
  final bool resolved;
  final String? resolvedSummary;

  const DraftCard(
    super.id,
    this.draft, {
    this.resolved = false,
    this.resolvedSummary,
  });
}

/// Câu có nhiều khoản (nhiều danh mục): MỘT thẻ để xác nhận một lần ("Lưu tất cả"), mỗi khoản vẫn là một giao dịch theo danh mục của nó
class DraftBatchCard extends ChatMessage {
  final List<DraftTransaction> drafts;

  /// Mã chống trùng của từng khoản, tạo một lần và dùng lại khi thử lại để server/máy không ghi hai lần
  final List<String> requestIds;

  /// Đã ghi ở máy (cả nhóm cùng lúc)
  final String? resolvedSummary;
  final String? error;

  const DraftBatchCard(
    super.id,
    this.drafts,
    this.requestIds, {
    this.resolvedSummary,
    this.error,
  });

  bool get resolved => resolvedSummary != null;

  /// Mọi khoản đủ thông tin để lưu thẳng (thiếu danh mục hoặc ví thì phải bổ sung trước)
  bool get allComplete => drafts.every(isSavableAsIs);

  static bool isSavableAsIs(DraftTransaction d) =>
      d.kind != DraftKind.transfer &&
      (d.amountCents ?? BigInt.zero) > BigInt.zero &&
      d.type != null &&
      d.suggestedAccountId != null &&
      d.missingFields.isEmpty &&
      (d.categorySlug != null || d.type == TransactionType.income);

  DraftBatchCard copyWith({
    List<DraftTransaction>? drafts,
    String? resolvedSummary,
    String? error,
    bool clearError = false,
  }) => DraftBatchCard(
    id,
    drafts ?? this.drafts,
    requestIds,
    resolvedSummary: resolvedSummary ?? this.resolvedSummary,
    error: clearError ? null : (error ?? this.error),
  );
}

enum ItemCardStatus { saving, created, undone, failed, needsCategory, declined, needsConfirm }

/// Ngân sách nói tới một nhóm mà tài khoản này chưa có: [name] là tên người dùng nói. Thẻ hỏi có tạo nhóm luôn không rồi mới đặt ngân sách.
class MissingCategory implements Exception {
  final String name;

  const MissingCategory(this.name);
}

/// Kết quả tạo một ngân sách / khoản định kỳ / khoản vay nợ từ câu chat: [summary] là câu "Đã lưu..." và [undo] xóa (hoặc trả về như cũ) đúng thứ vừa tạo.
class ItemOutcome {
  final String summary;
  final Future<void> Function() undo;

  /// Đổi số tiền của chính thứ vừa tạo (câu nối tiếp "đổi thành 3 triệu", "thêm 300k nữa"); trả câu báo kết quả. null = loại này chưa sửa được từ chat.
  final Future<String> Function(BigInt cents)? update;

  const ItemOutcome(this.summary, this.undo, {this.update});
}

/// Một mục ĐÃ CÓ (ngân sách / khoản định kỳ / khoản vay nợ) tìm thấy theo tên để sửa hoặc xóa bằng chat.
class NamedItem {
  final String kind;

  /// Mô tả cho người dùng, ví dụ `ngân sách Ăn uống 2.000.000 ₫/tháng`
  final String label;
  final BigInt amountCents;

  /// Đổi số tiền, trả câu báo kết quả; null = loại này chưa sửa được từ chat
  final Future<String> Function(BigInt cents)? update;
  final Future<void> Function() delete;

  const NamedItem({required this.kind, required this.label, required this.amountCents, this.update, required this.delete});
}

/// Việc vừa tạo trong phiên này: để hiểu câu nối tiếp ("xóa cái đó", "đổi thành 3 triệu", "còn di chuyển 1 triệu"). Chỉ nằm trong bộ nhớ của phiên, mất khi đóng app hoặc đăng xuất.
class _RecentItem {
  ChatItemDraft draft;
  final ItemOutcome outcome;
  final int cardId;

  _RecentItem(this.draft, this.outcome, this.cardId);
}

/// Thẻ báo kết quả của câu lệnh tạo ngân sách / khoản định kỳ / khoản vay nợ. Câu đủ thông tin thì app tạo ngay; thẻ hiện "Đã lưu" kèm "Hoàn tác".
class ItemCard extends ChatMessage {
  final ChatItemDraft item;
  final ItemCardStatus status;
  final String? summary;
  final String? error;

  const ItemCard(
    super.id,
    this.item, {
    this.status = ItemCardStatus.saving,
    this.summary,
    this.error,
    this.missingCategory,
    this.question,
  });

  /// Tên nhóm chưa có (khi [status] là needsCategory)
  final String? missingCategory;

  /// Câu hỏi xác nhận (khi [status] là needsConfirm), ví dụ ghi lần trả nợ
  final String? question;

  ItemCard copyWith({ItemCardStatus? status, String? summary, String? error, String? missingCategory, String? question}) => ItemCard(
    id,
    item,
    status: status ?? this.status,
    summary: summary ?? this.summary,
    error: error ?? this.error,
    missingCategory: missingCategory ?? this.missingCategory,
    question: question ?? this.question,
  );
}

enum GoalCardStatus { pending, saving, created, cancelled }

/// Câu đặt mục tiêu tiết kiệm. Câu lệnh đủ số tiền và hạn thì app tạo ngay (thẻ hiện "Đã tạo" kèm nút "Hoàn tác" theo [goalId]); thiếu một trong hai thì
/// thẻ chờ: người dùng sửa rồi bấm "Tạo mục tiêu" (app gọi `POST /saving-goals`)
class GoalDraftCard extends ChatMessage {
  final GoalDraft goal;
  final GoalCardStatus status;
  final String? error;

  /// Id mục tiêu đã tạo (có khi [status] là created); dùng để hoàn tác
  final String? goalId;

  const GoalDraftCard(
    super.id,
    this.goal, {
    this.status = GoalCardStatus.pending,
    this.error,
    this.goalId,
  });

  GoalDraftCard copyWith({
    GoalDraft? goal,
    GoalCardStatus? status,
    String? error,
    String? goalId,
    bool clearError = false,
  }) => GoalDraftCard(
    id,
    goal ?? this.goal,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    goalId: goalId ?? this.goalId,
  );
}

enum PurchaseCardStatus { pending, checking, assessed, cancelled }

/// Câu "mua X được không?": thẻ khoản ĐỊNH mua. Không ghi gì; thẻ tự gọi backend (`POST /forecast/purchase-check`) và hiện kết luận ngay trên thẻ.
/// Lỗi thì thẻ về `pending` kèm lý do để bấm "Thử lại".
class PurchaseCard extends ChatMessage {
  final PurchaseDraft purchase;
  final PurchaseCardStatus status;
  final PurchaseAssessment? assessment;
  final String? error;

  const PurchaseCard(
    super.id,
    this.purchase, {
    this.status = PurchaseCardStatus.pending,
    this.assessment,
    this.error,
  });

  PurchaseCard copyWith({
    PurchaseCardStatus? status,
    PurchaseAssessment? assessment,
    String? error,
    bool clearError = false,
  }) => PurchaseCard(
    id,
    purchase,
    status: status ?? this.status,
    assessment: assessment ?? this.assessment,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Câu trả lời của AI Financial Agent (`POST /agent/ask`): kết luận, các mệnh đề, bằng chứng ("Vì sao?") và thẻ đề xuất.
/// Agent chỉ đề xuất; [applied] là các thẻ đề xuất người dùng đã bấm áp dụng, [applying] là thẻ đang gọi API, [error] là lỗi của lần áp dụng gần nhất.
class AgentCard extends ChatMessage {
  final AgentAnswer answer;
  final Set<int> applied;
  final int? applying;
  final String? error;

  const AgentCard(
    super.id,
    this.answer, {
    this.applied = const {},
    this.applying,
    this.error,
  });

  AgentCard copyWith({
    Set<int>? applied,
    int? applying,
    bool clearApplying = false,
    String? error,
    bool clearError = false,
  }) => AgentCard(
    id,
    answer,
    applied: applied ?? this.applied,
    applying: clearApplying ? null : (applying ?? this.applying),
    error: clearError ? null : (error ?? this.error),
  );
}

class ErrorNote extends ChatMessage {
  final String message;

  /// Nội dung tin nhắn để gửi lại
  final String? retryText;

  const ErrorNote(super.id, this.message, {this.retryText});
}

class AssistantState {
  final List<ChatMessage> messages;
  final bool isSending;
  /// Đang chờ AI Financial Agent (có thể mất vài chục giây): màn hình đổi dòng chờ để người dùng không tưởng app treo.
  final bool isAskingAgent;
  final String? selectedAccountId;

  /// Số ảnh hoá đơn đang chờ hoặc đang quét (tách khỏi [isSending] để chat văn bản không bị khoá)
  final int pendingScans;

  const AssistantState({
    this.pendingScans = 0,
    this.messages = const [],
    this.isSending = false,
    this.isAskingAgent = false,
    this.selectedAccountId,
  });

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isAskingAgent,
    String? selectedAccountId,
    int? pendingScans,
    bool clearAccount = false,
  }) {
    return AssistantState(
      pendingScans: pendingScans ?? this.pendingScans,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isAskingAgent: isAskingAgent ?? this.isAskingAgent,
      selectedAccountId: clearAccount
          ? null
          : (selectedAccountId ?? this.selectedAccountId),
    );
  }
}

/// Số ảnh hoá đơn quét cùng lúc tối đa trên toàn controller
const receiptScanConcurrency = 3;

/// Lịch sử chỉ giữ trong phiên và bị xóa khi đổi người dùng/đăng xuất
final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
      ref.watch(currentUserIdProvider);
      final controller = AssistantController(
        repository: ref.watch(assistantRepositoryProvider),
        local: ref.watch(localFirstChatProvider)
            ? LocalFirstChat.fromRef(ref)
            : null,
        saver: DraftSaver.fromRef(ref),
        pending: ref.watch(pendingMessageStoreProvider),
        createGoal: (name, target, deadline) => ref
            .read(planningControllerProvider.notifier)
            .createSavingsGoal(
              title: name,
              targetAmountCents: target,
              targetDate: deadline,
            ),
        deleteGoal: (id) => ref.read(planningControllerProvider.notifier).cancelSavingsGoal(id),
        // Thẻ `change_goal_deadline` của agent: giữ tên và số tiền, chỉ đổi hạn
        changeGoalDeadline: (id, deadline) async {
          final planning = ref.read(planningControllerProvider.notifier);
          var goals = ref.read(planningControllerProvider).valueOrNull?.savingsGoals ?? const [];
          var goal = goals.where((g) => g.id == id).firstOrNull;
          if (goal == null) {
            await planning.loadPlanningData(silent: true);
            goals = ref.read(planningControllerProvider).valueOrNull?.savingsGoals ?? const [];
            goal = goals.where((g) => g.id == id).firstOrNull;
          }
          if (goal == null) throw StateError('Không tìm thấy mục tiêu này (có thể bạn đã xóa), hãy tạo lại mục tiêu.');
          await planning.updateGoal(id: id, name: goal.title, targetCents: goal.targetAmountCents, deadline: deadline);
        },
        // Thẻ đề xuất `set_budget_limit` của agent: đổi mã nhóm (slug) sang nhóm của chính người dùng rồi tạo/sửa hạn mức tháng
        setBudgetLimit: (slug, limitCents) async {
          final categories = await ref.read(categoriesProvider.future);
          final category = categories.where((c) => c.slug == slug).firstOrNull;
          if (category == null) {
            throw StateError('Bạn chưa có nhóm này (hoặc đã ẩn), hãy bật lại nhóm rồi thử lại.');
          }
          await ref
              .read(planningControllerProvider.notifier)
              .createOrUpdateBudget(categoryId: category.id, limitAmountCents: limitCents);
        },
        findItems: (op) => _findNamedItems(ref, op),
        repayLoan: (item) async {
          final loan = await ref
              .read(loansRepositoryProvider)
              .repay(loanId: item.loanId!, amountCents: item.amountCents, financialAccountId: item.accountId);
          ref.invalidate(loansProvider);
          final who = item.counterparty ?? '';
          final left = loan.remainingCents;
          final paid = formatVnd(item.amountCents);
          return item.direction == 'lend'
              ? 'Đã ghi: $who trả bạn $paid. ${left <= BigInt.zero ? 'Khoản này đã trả hết.' : '$who còn nợ bạn ${formatVnd(left)}.'}'
              : 'Đã ghi: bạn trả $who $paid. ${left <= BigInt.zero ? 'Khoản này đã trả hết.' : 'Bạn còn nợ $who ${formatVnd(left)}.'}';
        },
        createItem: (item, {createCategory = false}) => switch (item.kind) {
          ChatItemDraft.budget => _createBudgetItem(ref, item, createCategory: createCategory),
          ChatItemDraft.recurring => _createRecurringItem(ref, item),
          ChatItemDraft.loan => _createLoanItem(ref, item),
          ChatItemDraft.budgetTotal => _createBudgetTotalItem(ref, item),
          _ => throw StateError('Loại này app chưa tạo được từ chat.'),
        },
        onDataChanged: () {
          refreshDerivedData(ref);
          ref.invalidate(transactionControllerProvider);
        },
      );
      Future.microtask(
        controller.retryPending,
      ); // câu giữ lại từ lần mất mạng trước (kể cả trước khi tắt app)
      return controller;
    });

/// So tên không phân biệt hoa thường và dấu: người dùng gõ "thu cung" vẫn khớp nhóm "Thú cưng".
String _foldName(String text) {
  const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buffer = StringBuffer();
  for (final unit in text.toLowerCase().trim().runes) {
    final char = String.fromCharCode(unit);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Đặt hạn mức tháng cho một nhóm của CHÍNH tài khoản này (mỗi tài khoản có danh mục riêng): ưu tiên khớp theo tên người dùng nói, rồi theo nhóm mặc định hệ thống nhận ra.
/// Chưa có nhóm thì ném [MissingCategory] để hỏi người dùng; đồng ý ([createCategory]) thì tạo nhóm rồi đặt ngân sách (hoàn tác xóa cả hai).
/// Nhóm đã có ngân sách thì đổi hạn mức (hoàn tác trả về mức cũ).
Future<ItemOutcome> _createBudgetItem(Ref ref, ChatItemDraft item, {bool createCategory = false}) async {
  final all = (await ref.read(allCategoriesProvider.future)).where((c) => c.kind == 'expense').toList();
  final said = item.name;
  var category = said == null ? null : all.where((c) => _foldName(c.name) == _foldName(said)).firstOrNull;
  category ??= item.categorySlug == null ? null : all.where((c) => c.slug == item.categorySlug).firstOrNull;
  if (category != null && category.isHidden) {
    throw StateError('Bạn đã ẩn nhóm "${category.name}", hãy bật lại nhóm rồi thử lại.');
  }
  var createdCategoryId = '';
  if (category == null) {
    if (said == null || said.isEmpty) throw StateError('Mình chưa biết ngân sách này cho nhóm nào.');
    if (!createCategory) throw MissingCategory(said);
    category = await ref.read(categoriesControllerProvider).create(name: said, kind: 'expense');
    createdCategoryId = category.id;
  }
  final target = category;
  final planning = ref.read(planningControllerProvider.notifier);
  List<dynamic> budgetsOf() => ref.read(planningControllerProvider).valueOrNull?.categoryBudgets ?? const [];
  final previous = budgetsOf().where((b) => b.categoryId == target.id).firstOrNull;
  await planning.createOrUpdateBudget(categoryId: target.id, limitAmountCents: item.amountCents);
  final summary = previous == null
      ? '${createdCategoryId.isEmpty ? '' : 'Đã tạo nhóm ${target.name}. '}Đã đặt ngân sách ${target.name} ${formatVnd(item.amountCents)}/tháng.'
      : 'Đã đổi hạn mức ngân sách ${target.name} từ ${formatVnd(previous.limitAmountCents)} thành ${formatVnd(item.amountCents)}/tháng.';
  return ItemOutcome(summary, () async {
    if (previous != null) {
      await planning.createOrUpdateBudget(categoryId: target.id, limitAmountCents: previous.limitAmountCents);
      return;
    }
    final created = budgetsOf().where((b) => b.categoryId == target.id).firstOrNull;
    if (created != null) await planning.deleteBudget(created.id);
    if (createdCategoryId.isNotEmpty) await ref.read(categoriesControllerProvider).delete(createdCategoryId);
  }, update: (cents) async {
    await planning.createOrUpdateBudget(categoryId: target.id, limitAmountCents: cents);
    return 'Đã đổi hạn mức ngân sách ${target.name} thành ${formatVnd(cents)}/tháng.';
  });
}

/// Thêm khoản chi định kỳ (hóa đơn, gói đăng ký); hoàn tác hủy khoản đó.
Future<ItemOutcome> _createRecurringItem(Ref ref, ChatItemDraft item) async {
  final due = item.nextDue;
  if (due == null) throw StateError('Thiếu ngày thanh toán tiếp theo.');
  final repository = ref.read(recurringItemsRepositoryProvider);
  final cadence = RecurringCadence.values.where((c) => c.name == item.cadence).firstOrNull ?? RecurringCadence.monthly;
  final name = item.name ?? 'Khoản định kỳ';
  final inflow = item.direction == 'inflow';
  final created = await repository.createItem(
    direction: inflow ? RecurringDirection.inflow : RecurringDirection.outflow,
    name: name,
    amountCents: item.amountCents,
    cadence: cadence,
    nextDueDate: due,
  );
  ref.invalidate(recurringItemsControllerProvider);
  return ItemOutcome(
    'Đã lưu khoản ${inflow ? 'thu' : 'chi'} định kỳ "$name": ${formatVnd(item.amountCents)} ${cadence.label.toLowerCase()}, lần tới ${DateFormat('dd/MM/yyyy').format(due)}.',
    () async {
      await repository.cancel(created.id);
      ref.invalidate(recurringItemsControllerProvider);
    },
    update: (cents) async {
      await repository.updateItem(id: created.id, amountCents: cents);
      ref.invalidate(recurringItemsControllerProvider);
      return 'Đã đổi số tiền khoản "$name" thành ${formatVnd(cents)}.';
    },
  );
}

/// Ghi một khoản vay/nợ ("bạn An nợ tôi 700k" = mình cho vay); hoàn tác xóa khoản đó.
Future<ItemOutcome> _createLoanItem(Ref ref, ChatItemDraft item) async {
  final who = item.counterparty;
  if (who == null || who.isEmpty) throw StateError('Thiếu tên người trong khoản vay nợ.');
  final repository = ref.read(loansRepositoryProvider);
  final lend = item.direction == 'lend';
  final loan = await repository.createLoan(
    type: lend ? LoanType.lend : LoanType.borrow,
    title: item.name ?? (lend ? 'Cho $who vay' : 'Vay $who'),
    counterparty: who,
    principalCents: item.amountCents,
  );
  ref.invalidate(loansProvider);
  return ItemOutcome(
    lend ? 'Đã ghi: $who nợ bạn ${formatVnd(item.amountCents)}.' : 'Đã ghi: bạn nợ $who ${formatVnd(item.amountCents)}.',
    () async {
      await repository.deleteLoan(loan.id);
      ref.invalidate(loansProvider);
    },
    update: (cents) async {
      await repository.updateLoan(
        id: loan.id,
        type: lend ? LoanType.lend : LoanType.borrow,
        title: loan.title,
        counterparty: who,
        principalCents: cents,
      );
      ref.invalidate(loansProvider);
      return lend ? 'Đã sửa: $who nợ bạn ${formatVnd(cents)}.' : 'Đã sửa: bạn nợ $who ${formatVnd(cents)}.';
    },
  );
}

/// Khớp tên không phân biệt hoa thường và dấu; một tên chứa tên kia cũng khớp ("Netflix" với "Gói Netflix").
bool _nameMatches(String candidate, String said) {
  final a = _foldName(candidate);
  final b = _foldName(said);
  return b.isNotEmpty && a.isNotEmpty && (a == b || a.contains(b) || b.contains(a));
}

/// Các mục đã có của CHÍNH người dùng khớp tên trong câu sửa/xóa: ngân sách nhóm, khoản định kỳ đang chạy, khoản vay nợ (theo loại câu nói; `any` thì tìm cả ba).
Future<List<NamedItem>> _findNamedItems(Ref ref, ChatItemDraft op) async {
  final said = op.name ?? '';
  final found = <NamedItem>[];
  final all = op.kind == ChatItemDraft.any;

  if (all || op.kind == ChatItemDraft.budget) {
    final planning = ref.read(planningControllerProvider.notifier);
    var budgets = ref.read(planningControllerProvider).valueOrNull?.categoryBudgets ?? const [];
    if (budgets.isEmpty) {
      await planning.loadPlanningData(silent: true);
      budgets = ref.read(planningControllerProvider).valueOrNull?.categoryBudgets ?? const [];
    }
    final categories = await ref.read(allCategoriesProvider.future);
    final slugId = op.categorySlug == null ? null : categories.where((c) => c.slug == op.categorySlug).firstOrNull?.id;
    for (final b in budgets) {
      if (_nameMatches(b.category, said) || (slugId != null && b.categoryId == slugId)) {
        found.add(
          NamedItem(
            kind: ChatItemDraft.budget,
            label: 'ngân sách ${b.category} ${formatVnd(b.limitAmountCents)}/tháng',
            amountCents: b.limitAmountCents,
            update: (cents) async {
              await planning.createOrUpdateBudget(categoryId: b.categoryId, limitAmountCents: cents);
              return 'Đã đổi hạn mức ngân sách ${b.category} thành ${formatVnd(cents)}/tháng.';
            },
            delete: () => planning.deleteBudget(b.id),
          ),
        );
      }
    }
  }

  if (all || op.kind == ChatItemDraft.recurring) {
    final repository = ref.read(recurringItemsRepositoryProvider);
    for (final r in await repository.getItems(status: RecurringStatus.active)) {
      if (_nameMatches(r.name, said)) {
        found.add(
          NamedItem(
            kind: ChatItemDraft.recurring,
            label: 'khoản định kỳ "${r.name}" ${formatVnd(r.amountCents)} ${r.cadence.label.toLowerCase()}',
            amountCents: r.amountCents,
            update: (cents) async {
              await repository.updateItem(id: r.id, amountCents: cents);
              ref.invalidate(recurringItemsControllerProvider);
              return 'Đã đổi số tiền khoản "${r.name}" thành ${formatVnd(cents)}.';
            },
            delete: () async {
              await repository.cancel(r.id);
              ref.invalidate(recurringItemsControllerProvider);
            },
          ),
        );
      }
    }
  }

  if (all || op.kind == ChatItemDraft.loan) {
    final repository = ref.read(loansRepositoryProvider);
    for (final l in await repository.getLoans()) {
      if (_nameMatches(l.counterparty, said) || _nameMatches(l.title, said)) {
        found.add(
          NamedItem(
            kind: ChatItemDraft.loan,
            label: 'khoản ${l.type == LoanType.lend ? '${l.counterparty} nợ bạn' : 'bạn nợ ${l.counterparty}'} ${formatVnd(l.principalCents)}',
            amountCents: l.principalCents,
            update: (cents) async {
              await repository.updateLoan(
                id: l.id,
                type: l.type,
                title: l.title,
                counterparty: l.counterparty,
                principalCents: cents,
                interestRateYear: l.interestRateYear,
                dueDate: l.dueDate,
                startDate: l.startDate,
              );
              ref.invalidate(loansProvider);
              return 'Đã sửa khoản vay nợ với ${l.counterparty} thành ${formatVnd(cents)}.';
            },
            delete: () async {
              await repository.deleteLoan(l.id);
              ref.invalidate(loansProvider);
            },
          ),
        );
      }
    }
  }
  return found;
}

/// Đặt ngân sách TỔNG của tháng (không gắn nhóm). Đã có thì đổi hạn mức (hoàn tác trả về mức cũ), chưa có thì tạo (hoàn tác xóa).
Future<ItemOutcome> _createBudgetTotalItem(Ref ref, ChatItemDraft item) async {
  final planning = ref.read(planningControllerProvider.notifier);
  dynamic overall() => ref.read(planningControllerProvider).valueOrNull?.overallBudget;
  final previous = overall();
  await planning.createOrUpdateBudget(categoryId: null, limitAmountCents: item.amountCents);
  final summary = previous == null
      ? 'Đã đặt ngân sách tổng ${formatVnd(item.amountCents)}/tháng.'
      : 'Đã đổi ngân sách tổng từ ${formatVnd(previous.limitAmountCents)} thành ${formatVnd(item.amountCents)}/tháng.';
  return ItemOutcome(
    summary,
    () async {
      if (previous != null) {
        await planning.createOrUpdateBudget(categoryId: null, limitAmountCents: previous.limitAmountCents);
        return;
      }
      final created = overall();
      if (created != null) await planning.deleteBudget(created.id);
    },
    update: (cents) async {
      await planning.createOrUpdateBudget(categoryId: null, limitAmountCents: cents);
      return 'Đã đổi ngân sách tổng thành ${formatVnd(cents)}/tháng.';
    },
  );
}

class _FailedVoice {
  final String path;
  final String requestId;

  const _FailedVoice(this.path, this.requestId);
}

class _FailedSend {
  final String text;
  final String requestId;
  final DraftSource source;

  const _FailedSend(this.text, this.requestId, this.source);
}

/// `intent` của server cho câu kế hoạch/dự báo: app hỏi AI Financial Agent thay vì chat trả lời
const _askAgentIntent = 'ask_agent';

/// `intent` của server cho câu chat không hiểu
const _outOfScopeIntent = 'out_of_scope';

/// `intent` của server khi nó vừa hỏi giá một khoản định mua
const _purchaseNeedsAmount = 'purchase_needs_amount';

/// `intent` của server cho câu tạo ngân sách / khoản định kỳ / vay nợ (có `item` khi đủ thông tin, không thì `replyText` là câu hỏi lại)
const _createItemIntent = 'create_item';

/// `intent` của server khi người dùng xin giải thích con số của câu trả lời vừa rồi ("vì sao ô số dư ra 14,5 triệu?"): app đọc bằng chứng của chính câu trả lời đó, không gọi AI
const _explainIntent = 'explain_numbers';

/// Câu trả lời cho câu hỏi lại thường ngắn; dài hơn mức này thì coi là câu mới, không ghép vào câu dở
const _maxFollowUpLength = 40;

/// Số việc vừa tạo được nhớ trong một phiên
const _maxRecentItems = 5;

/// Tin chỉ có một số tiền ("15tr", "15 triệu", "800k", "1.500.000đ"): có thể là câu trả lời cho câu hỏi giá vừa rồi
final _bareAmount = RegExp(
  r'^\d[\d.,]*\s*(?:k|nghìn|ngàn|tr|triệu|trieu|củ|cu|m|đ|d|vnd|₫)?$',
  caseSensitive: false,
  unicode: true,
);

class AssistantController extends StateNotifier<AssistantState> {
  final AssistantRepository repository;

  /// Gọi khi chatbot đã ghi một giao dịch (số dư, báo cáo, danh sách cần tải lại)
  final VoidCallback? onDataChanged;

  /// Có thì chat chạy kiểu local-first (server chỉ hiểu câu, app quyết định và ghi ở máy); null = đường cũ qua `POST /transactions/chat`
  final LocalFirstChat? local;

  /// Ghi các khoản của thẻ gộp khi người dùng bấm "Lưu tất cả"
  final DraftSaver? saver;

  /// Hàng chờ cho câu chưa phân tích được vì mất mạng; null = mất mạng thì hiện thẻ lỗi như trước
  final PendingMessageStore? pending;

  /// Tạo mục tiêu tiết kiệm (gọi `POST /saving-goals`), trả id mục tiêu; null = app không tạo được mục tiêu
  final Future<String?> Function(
    String name,
    BigInt targetCents,
    DateTime? deadline,
  )?
  createGoal;

  /// Hủy mục tiêu vừa tạo (nút "Hoàn tác"); null = không hoàn tác được
  final Future<void> Function(String goalId)? deleteGoal;

  /// Đổi hạn một mục tiêu đã có sang [deadline] (thẻ `change_goal_deadline` của agent); null = thẻ không áp dụng được
  final Future<void> Function(String goalId, DateTime deadline)? changeGoalDeadline;

  /// Câu lệnh đặt mục tiêu ĐỦ số tiền và hạn thì tạo ngay rồi tư vấn khả thi (người dùng đã ra lệnh rõ, hoàn tác được); thiếu một trong hai thì vẫn hiện thẻ xác nhận để người dùng điền nốt
  final bool autoCreateGoals;

  /// Đặt hạn mức tháng của một nhóm (theo slug) khi người dùng bấm thẻ đề xuất của agent; null = thẻ đề xuất không áp dụng được
  final Future<void> Function(String categorySlug, BigInt limitCents)? setBudgetLimit;

  /// Tạo ngân sách / khoản định kỳ / khoản vay nợ mà câu chat đã nói đủ thông tin; null = app không tạo được (trả lời hướng dẫn thêm ở tab Kế hoạch)
  final Future<ItemOutcome> Function(ChatItemDraft item, {bool createCategory})? createItem;

  /// Ghi một lần trả nợ vào khoản vay có sẵn (`POST /loans/{id}/repayments`) rồi trả câu báo kết quả; null = app không ghi được
  final Future<String> Function(ChatItemDraft item)? repayLoan;

  /// Tìm trong dữ liệu CỦA NGƯỜI DÙNG các mục khớp tên mà câu "xóa ngân sách ăn uống" / "đổi khoản Netflix thành 300k" nói tới; null = app không tìm được
  final Future<List<NamedItem>> Function(ChatItemDraft op)? findItems;
  final Map<int, NamedItem> _pendingDelete = {};
  final Map<int, Future<void> Function()> _itemUndo = {};

  /// Các việc vừa tạo (tối đa [_maxRecentItems]), mới nhất ở cuối; việc mới nhất được gửi kèm mỗi tin chat làm ngữ cảnh
  final List<_RecentItem> _recent = [];

  Map<String, dynamic>? _itemContext() => _recent.lastOrNull?.draft.toContextJson();

  /// Câu tạo ngân sách / khoản định kỳ / vay nợ mà bot vừa hỏi lại phần thiếu. Server không nhớ gì giữa hai tin, nên tin kế tiếp (ngắn: "hằng tháng", "ngày 5", "ăn uống") được ghép vào sau câu này rồi phân tích lại.
  String? _askedItem;
  Timer? _retryTimer;
  bool _retrying = false;

  /// Câu hỏi mua vừa được bot hỏi lại giá ("có nên mua iphone?"). Server không nhớ gì giữa hai tin, nên nếu tin kế tiếp chỉ là số tiền
  /// ("15tr") thì app ghép câu này vào trước khi gửi; tin nào khác thì bỏ nhớ.
  String? _askedPurchase;

  /// Mã các câu được giữ lại ngay trong phiên này (bong bóng của người dùng đã hiện sẵn); câu giữ từ lần chạy trước thì chưa có
  final Set<String> _heldThisSession = {};
  final Set<String> _shownOnce =
      {}; // câu cũ đã hiện lại một lần (vẫn mất mạng thì lần thử sau không hiện nữa)

  final Map<int, _FailedSend> _failed = {};
  final Map<int, String> _failedScans = {};
  final Map<int, _FailedVoice> _failedVoices = {};
  int _nextId = 0;

  /// [retryEvery]: chu kỳ tự phân tích lại các câu đang chờ (null = không tự chạy, test gọi [retryPending] trực tiếp)
  AssistantController({
    required this.repository,
    this.onDataChanged,
    this.local,
    this.saver,
    this.pending,
    this.createGoal,
    this.deleteGoal,
    this.changeGoalDeadline,
    this.autoCreateGoals = true,
    this.setBudgetLimit,
    this.createItem,
    this.repayLoan,
    this.findItems,
    Duration? retryEvery = const Duration(seconds: 30),
  }) : super(const AssistantState()) {
    if (pending != null && retryEvery != null) {
      _retryTimer = Timer.periodic(retryEvery, (_) => retryPending());
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    // Ảnh còn chờ sẽ không bao giờ chạy: trả các lời hứa để người gọi không treo
    for (final (_, c) in _scanQueue) {
      c.complete();
    }
    _scanQueue.clear();
    super.dispose();
  }

  void _add(ChatMessage message) {
    if (!mounted) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Gửi một tin nhắn cho chatbot. Mỗi tin nhắn có một `clientRequestId` riêng, dùng lại khi gửi lại.
  Future<void> send(
    String text, {
    DraftSource source = DraftSource.chat,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final asked = _askedPurchase;
    _askedPurchase = null;
    final askedItem = _askedItem;
    _askedItem = null;
    _add(UserText(_nextId++, trimmed));
    final outgoing = asked != null && _bareAmount.hasMatch(trimmed)
        ? '$asked $trimmed'
        : askedItem != null && trimmed.length <= _maxFollowUpLength && !trimmed.contains('?')
        ? '$askedItem, $trimmed'
        : trimmed;
    if (await _deliver(outgoing, const Uuid().v4(), source)) {
      unawaited(retryPending());
    }
  }

  /// Gửi lại tin nhắn bị lỗi bằng đúng `clientRequestId` cũ để backend không tạo trùng
  Future<void> retry(int errorMessageId) async {
    final voice = _failedVoices.remove(errorMessageId);
    if (voice != null) {
      if (state.isSending) return;
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != errorMessageId).toList(),
      );
      await _deliverVoice(voice.path, voice.requestId);
      return;
    }
    final scanPath = _failedScans.remove(errorMessageId);
    if (scanPath != null) {
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != errorMessageId).toList(),
      );
      // Xếp lại vào hàng đợi, không thêm ImageNote (ảnh vẫn nằm ở tin cũ)
      final again = _enqueueScan(scanPath);
      _pumpScans();
      await again;
      return;
    }
    final failed = _failed.remove(errorMessageId);
    if (failed == null || state.isSending) return;

    state = state.copyWith(
      messages: state.messages.where((m) => m.id != errorMessageId).toList(),
    );
    await _deliver(failed.text, failed.requestId, failed.source);
  }

  /// Trả false khi mất mạng (câu được giữ lại để phân tích sau, hoặc đã nằm sẵn trong hàng chờ), true khi đã có kết quả hay lỗi để hiện.
  Future<bool> _deliver(
    String text,
    String requestId,
    DraftSource source, {
    bool fromQueue = false,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      final local = this.local;
      if (local != null) {
        final analysis = await repository.analyze(text);
        if (!mounted) return true;
        _askedPurchase = analysis.intent == _purchaseNeedsAmount ? text : null;
        await _decideLocally(local, analysis, text, requestId, source);
      } else {
        final reply = await repository.chat(
          text,
          accountId: state.selectedAccountId,
          clientRequestId: requestId,
          itemContext: _itemContext(),
        );
        if (!mounted) return true;
        _askedPurchase = reply.intent == _purchaseNeedsAmount ? text : null;
        _askedItem = reply.intent == _createItemIntent && reply.action == ChatAction.reply ? text : null;
        if (reply.intent == _explainIntent) {
          _explainLastAnswer();
        } else if (_wantsAgent(reply)) {
          await _answerWithAgent(text, reply, source);
        } else {
          await _present(reply, source);
        }
      }
      return true;
    } catch (e) {
      final store = pending;
      if (e is NetworkException && store != null) {
        if (!fromQueue) {
          await store.addText(requestId, text, source);
          _heldThisSession.add(requestId);
          _add(AssistantText(_nextId++, _heldNotice));
        }
        return false;
      }
      final id = _nextId++;
      _failed[id] = _FailedSend(text, requestId, source);
      _add(ErrorNote(id, errorMessage(e), retryText: text));
      return true;
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  static const _heldNotice =
      'Đang không có mạng. Mình giữ câu này trên máy và sẽ phân tích khi có mạng lại.';

  /// Phân tích lại các câu đã giữ lại vì mất mạng, theo thứ tự, bằng đúng mã chống trùng cũ. Dừng ngay khi vẫn mất mạng (câu sau không
  /// được vượt mặt câu trước). Chạy tự động theo chu kỳ, khi mở app, và sau mỗi lần gửi thành công.
  Future<void> retryPending() async {
    final store = pending;
    if (store == null || _retrying || state.isSending) return;
    _retrying = true;
    try {
      for (final item in await store.all()) {
        if (!mounted) return;
        if (item.kind == PendingKind.text &&
            !_heldThisSession.contains(item.id) &&
            !_shownOnce.contains(item.id)) {
          _shownOnce.add(item.id);
          _add(
            UserText(_nextId++, item.content),
          ); // câu giữ từ lần chạy trước: hiện lại câu gốc trước kết quả
        }
        final reached = item.kind == PendingKind.text
            ? await _deliver(
                item.content,
                item.id,
                item.source,
                fromQueue: true,
              )
            : await _deliverVoice(item.content, item.id, fromQueue: true);
        if (!reached) return;
        await store.remove(item.id);
      }
    } finally {
      _retrying = false;
    }
  }

  /// Gửi tệp ghi âm: backend đổi giọng thành chữ (STT) rồi chạy đúng luồng chat; câu nghe được hiện như tin của người dùng
  Future<void> sendVoice(String path) async {
    if (state.isSending) return;
    if (await _deliverVoice(path, const Uuid().v4())) unawaited(retryPending());
  }

  Future<bool> _deliverVoice(
    String path,
    String requestId, {
    bool fromQueue = false,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      final local = this.local;
      if (local != null) {
        final voice = await repository.analyzeVoice(path);
        if (!mounted) return true;
        _add(UserText(_nextId++, voice.transcript));
        await _decideLocally(
          local,
          voice.analysis,
          voice.transcript,
          requestId,
          DraftSource.voice,
        );
      } else {
        final voice = await repository.voiceChat(
          path,
          accountId: state.selectedAccountId,
          clientRequestId: requestId,
        );
        if (!mounted) return true;
        _add(UserText(_nextId++, voice.transcript));
        if (_wantsAgent(voice.chat)) {
          await _answerWithAgent(voice.transcript, voice.chat, DraftSource.voice);
        } else {
          await _present(voice.chat, DraftSource.voice);
        }
      }
      return true;
    } catch (e) {
      final store = pending;
      if (e is NetworkException && store != null) {
        if (!fromQueue) {
          await store.addVoice(requestId, path);
          _add(AssistantText(_nextId++, _heldNotice));
        }
        return false;
      }
      final id = _nextId++;
      _failedVoices[id] = _FailedVoice(path, requestId);
      _add(ErrorNote(id, errorMessage(e), retryText: path));
      return true;
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  /// Server đã hiểu câu: quyết định ghi ngay, nháp, trả lời hay hỏi tổng bằng dữ liệu trên máy
  Future<void> _decideLocally(
    LocalFirstChat local,
    ChatAnalysis analysis,
    String text,
    String requestId,
    DraftSource source,
  ) async {
    final decision = await local.decider.decide(
      analysis,
      accountId: state.selectedAccountId,
      now: DateTime.now(),
      source: source,
    );
    if (!mounted) return;
    switch (decision) {
      case SaveNow(:final draft, :final notes):
        final categoryId = local.saver.categoryIdOf(draft.categorySlug!);
        final accountId = draft.suggestedAccountId;
        if (categoryId == null || accountId == null) {
          _add(
            DraftCard(_nextId++, draft),
          ); // chưa có danh mục của server hoặc ví: để người dùng xem và lưu
        } else {
          final tx = await local.saver.save(
            draft,
            categoryId: categoryId,
            accountId: accountId,
            clientRequestId: requestId,
          );
          if (!mounted) return;
          _add(SavedCard(_nextId++, tx));
          onDataChanged?.call();
        }
        _addNotes(notes);
      case Drafts(:final drafts, :final replyText, :final notes):
        if (replyText != null) _add(AssistantText(_nextId++, replyText));
        addBatch(drafts);
        _addNotes(notes);
      case Reply(:final text, :final notes):
        _add(AssistantText(_nextId++, text));
        _addNotes(notes);
      case GoalDecision(:final goal, :final replyText, :final notes):
        await _presentGoal(goal, serverText: replyText);
        _addNotes(notes);
      case NeedSummary():
        final reply = await repository.chat(
          text,
          accountId: state.selectedAccountId,
          clientRequestId: requestId,
        );
        if (!mounted) return;
        await _present(reply, source);
    }
  }

  /// Một khoản: thẻ nháp như thường. Nhiều khoản: MỘT thẻ gộp để xác nhận một lần. Chuyển tiền giữa hai ví cần chọn ví nên luôn là thẻ nháp riêng.
  void addBatch(List<DraftTransaction> drafts) {
    final transfers = [
      for (final d in drafts)
        if (d.kind == DraftKind.transfer) d,
    ];
    final others = [
      for (final d in drafts)
        if (d.kind != DraftKind.transfer) d,
    ];
    if (others.length == 1) {
      _add(DraftCard(_nextId++, others.single));
    } else if (others.length > 1) {
      _add(
        DraftBatchCard(_nextId++, others, [
          for (final _ in others) const Uuid().v4(),
        ]),
      );
    }
    for (final t in transfers) {
      _add(DraftCard(_nextId++, t));
    }
  }

  DraftBatchCard? _batch(int messageId) => state.messages
      .whereType<DraftBatchCard>()
      .where((m) => m.id == messageId)
      .firstOrNull;

  /// Chat có chuyển câu này sang AI Financial Agent không: server gắn `ask_agent` cho câu kế hoạch/dự báo ("nếu thu nhập giảm 30% thì sao",
  /// "bao lâu đủ tiền mua nhà"), và `out_of_scope` cho câu chat không hiểu (agent có lời từ chối và tra tri thức tốt hơn câu "chỉ giúp ghi chi tiêu").
  /// Một ô nhập cho cả hai: người dùng không phải chọn chế độ.
  static bool _wantsAgent(ChatReply reply) =>
      reply.action == ChatAction.reply && (reply.intent == _askAgentIntent || reply.intent == _outOfScopeIntent);

  /// Hỏi agent (`POST /agent/ask`) và thêm [AgentCard]; không ghi giao dịch. Agent lỗi (429 vượt hạn mức, 503 AI không dùng được...):
  /// câu chat không hiểu thì giữ lời đáp cũ của chat, câu kế hoạch thì hiện lỗi thành một dòng của trợ lý.
  Future<void> _answerWithAgent(String question, ChatReply chatReply, DraftSource source) async {
    state = state.copyWith(isAskingAgent: true);
    try {
      final answer = await repository.askAgent(question);
      if (!mounted) return;
      _add(AgentCard(_nextId++, answer));
    } catch (e) {
      if (!mounted) return;
      if (chatReply.intent == _outOfScopeIntent) {
        await _present(chatReply, source);
      } else {
        _add(AssistantText(_nextId++, errorMessage(e)));
      }
    } finally {
      if (mounted) state = state.copyWith(isAskingAgent: false);
    }
  }

  AgentCard? _agentCard(int messageId) =>
      state.messages.whereType<AgentCard>().where((m) => m.id == messageId).firstOrNull;

  /// Việc phía sau nút của một thẻ đề xuất; null nếu app không làm được loại này (thiếu hàm, hoặc loại lạ). Mỗi loại một việc:
  /// đặt hạn mức tháng; mở thẻ mục tiêu để người dùng sửa và xác nhận; kiểm tra lại khoản mua với giá thấp hơn; hẹn nhắc đúng ngày.
  /// Không việc nào tự ghi tiền: thẻ mục tiêu vẫn cần bấm "Tạo mục tiêu", kiểm tra mua chỉ đọc.
  Future<void> Function()? _actionRunner(AgentSuggestedAction a) {
    switch (a.kind) {
      case AgentSuggestedAction.setBudgetLimit:
        final setLimit = setBudgetLimit;
        return setLimit == null ? null : () => setLimit(a.categorySlug!, a.amountVnd!);
      case AgentSuggestedAction.createGoal:
        final create = createGoal;
        if (create == null) return null;
        return () async {
          final due = a.date!;
          final goal = GoalDraft(
            name: 'Mục tiêu tiết kiệm',
            nameIsDefault: true,
            targetCents: a.amountVnd!,
            deadline: DateTime(due.year, due.month, due.day, 23, 59, 59),
          );
          // Người dùng đã bấm nút nên tạo luôn (không bắt xác nhận lần hai); thẻ "Đã tạo" kèm "Hoàn tác" hiện trong chat
          final goalId = await create(goal.name, goal.targetCents, goal.deadline);
          _add(GoalDraftCard(_nextId++, goal, status: GoalCardStatus.created, goalId: goalId));
        };
      case AgentSuggestedAction.changeGoalDeadline:
        final change = changeGoalDeadline;
        if (change == null) return null;
        return () async {
          final due = a.date!;
          await change(a.targetId!, DateTime(due.year, due.month, due.day, 23, 59, 59));
        };
      case AgentSuggestedAction.lowerAmountTo:
        return () async {
          final id = _nextId++;
          _add(PurchaseCard(id, PurchaseDraft(amountCents: a.amountVnd!)));
          unawaited(assessPurchase(id));
        };
      case AgentSuggestedAction.waitUntil:
        return () async {
          await repository.schedulePurchaseReminder(a.date!);
        };
      default:
        return null;
    }
  }

  /// Bấm một thẻ đề xuất của agent; mỗi thẻ áp dụng một lần. Lỗi thì thẻ giữ nguyên để bấm lại, kèm lý do. Agent không bao giờ tự làm việc này.
  Future<void> applyAgentAction(int messageId, int index) async {
    final card = _agentCard(messageId);
    if (card == null || card.applying != null) return;
    if (index < 0 || index >= card.answer.suggestedActions.length || card.applied.contains(index)) return;
    final action = card.answer.suggestedActions[index];
    final run = action.canApply ? _actionRunner(action) : null;
    if (run == null) return;
    _replace(card.copyWith(applying: index, clearError: true));
    try {
      await run();
      if (!mounted) return;
      final latest = _agentCard(messageId) ?? card;
      _replace(latest.copyWith(applied: {...latest.applied, index}, clearApplying: true));
    } catch (e) {
      if (!mounted) return;
      final latest = _agentCard(messageId) ?? card;
      _replace(latest.copyWith(clearApplying: true, error: e is StateError ? e.message : errorMessage(e)));
    }
  }

  void _replace(ChatMessage updated) {
    if (!mounted) return;
    state = state.copyWith(
      messages: [
        for (final m in state.messages) m.id == updated.id ? updated : m,
      ],
    );
  }

  /// Chọn danh mục cho một khoản còn thiếu ngay trên thẻ gộp
  void setBatchCategory(int messageId, int index, String slug) {
    final batch = _batch(messageId);
    if (batch == null || index < 0 || index >= batch.drafts.length) return;
    final drafts = [...batch.drafts];
    drafts[index] = drafts[index].copyWith(
      categorySlug: slug,
      missingFields: [
        for (final f in drafts[index].missingFields)
          if (f != 'category') f,
      ],
    );
    _replace(batch.copyWith(drafts: drafts, clearError: true));
  }

  /// Sửa một dòng ngay trên thẻ gộp (số tiền, ghi chú, danh mục). Số tiền không hợp lệ (<= 0) bị bỏ qua, mã chống trùng giữ nguyên.
  void updateBatchDraft(
    int messageId,
    int index, {
    BigInt? amountCents,
    String? description,
    String? categorySlug,
  }) {
    final batch = _batch(messageId);
    if (batch == null || index < 0 || index >= batch.drafts.length) return;
    final old = batch.drafts[index];
    final validAmount = amountCents != null && amountCents > BigInt.zero
        ? amountCents
        : null;
    final drafts = [...batch.drafts];
    drafts[index] = old.copyWith(
      amountCents: validAmount,
      description: description,
      categorySlug: categorySlug,
      missingFields: categorySlug == null
          ? null
          : [
              for (final f in old.missingFields)
                if (f != 'category') f,
            ],
    );
    _replace(batch.copyWith(drafts: drafts, clearError: true));
  }

  /// "Lưu tất cả": ghi cả nhóm ở máy trong MỘT lần (được tất cả hoặc không gì; mất mạng hay không đều xong ngay), rồi đồng bộ lên server ngầm.
  /// Bấm lại sau lỗi dùng đúng các mã chống trùng cũ.
  Future<void> confirmBatch(int messageId) async {
    final batch = _batch(messageId);
    final saver = this.saver;
    if (batch == null || saver == null || batch.resolved || state.isSending) {
      return;
    }
    if (!batch.allComplete) {
      _replace(
        batch.copyWith(
          error:
              'Còn khoản cần bổ sung thông tin, hãy chọn danh mục hoặc bấm "Sửa từng khoản".',
        ),
      );
      return;
    }
    final items = <DraftSave>[];
    for (var i = 0; i < batch.drafts.length; i++) {
      final draft = batch.drafts[i];
      final categoryId = saver.categoryIdOf(draft.categorySlug ?? 'income');
      if (categoryId == null) {
        _replace(
          batch.copyWith(
            error: 'Chưa tải được danh mục, bạn thử lại sau ít giây nhé.',
          ),
        );
        return;
      }
      items.add(
        DraftSave(
          draft,
          categoryId,
          draft.suggestedAccountId!,
          batch.requestIds[i],
        ),
      );
    }
    state = state.copyWith(isSending: true);
    try {
      await saver.saveAll(items);
      if (!mounted) return;
      final total = batch.drafts.fold<BigInt>(
        BigInt.zero,
        (a, d) => a + d.amountCents!,
      );
      _replace(
        batch.copyWith(
          resolvedSummary: savedSummary(
            batch.drafts.length,
            total,
            commonDay(batch.drafts.map((d) => d.transactedAt)),
          ),
          clearError: true,
        ),
      );
      onDataChanged?.call();
      for (final draft in batch.drafts) {
        final slug = draft.categorySlug;
        if (local != null &&
            slug != null &&
            draft.source != DraftSource.receipt &&
            (draft.description ?? '').trim().isNotEmpty) {
          local!.remember(
            draft.merchantName,
            draft.description,
            slug,
          ); // đã xác nhận: nhớ riêng ở máy
        }
      }
      // Đồng bộ lên server ngầm: người dùng không phải chờ, và mất mạng thì hàng đợi giữ nguyên cho lần sau
      saver.syncNow().then(
        (_) => mounted ? onDataChanged?.call() : null,
        onError: (_) {},
      );
    } catch (e) {
      _replace(batch.copyWith(error: errorMessage(e)));
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  /// "Sửa từng khoản": đổi thẻ gộp thành các thẻ nháp riêng
  void splitBatch(int messageId) {
    final batch = _batch(messageId);
    if (batch == null) return;
    final cards = <ChatMessage>[
      for (final d in batch.drafts) DraftCard(_nextId++, d),
    ];
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == messageId) ...cards else m,
      ],
    );
  }

  void _addNotes(List<String> notes) {
    for (final note in notes) {
      _add(AssistantText(_nextId++, note));
    }
  }

  Future<void> _present(ChatReply reply, DraftSource source) async {
    switch (reply.action) {
      case ChatAction.saved:
        _add(SavedCard(_nextId++, reply.transaction!));
        onDataChanged?.call();
      case ChatAction.summary:
        _add(SummaryCard(_nextId++, reply.summary!));
      case ChatAction.confirm:
        final drafts = reply.drafts.isEmpty ? [reply.draft!] : reply.drafts;
        // Nhiều khoản trong một câu: lời báo của BE rồi mỗi khoản một thẻ, người dùng rà soát và lưu từng khoản.
        if (reply.replyText != null) {
          _add(
            AssistantText(_nextId++, reply.replyText!),
          ); // lời nhắn của server (nhiều khoản, vế thiếu tiền, tổng không khớp)
        }
        addBatch([for (final d in drafts) d.copyWith(source: source)]);
      case ChatAction.reply:
        _add(AssistantText(_nextId++, reply.replyText ?? ''));
      case ChatAction.goal:
        await _presentGoal(reply.goal!, serverText: reply.replyText);
      case ChatAction.item:
        switch (reply.item!.operation) {
          case 'create':
            await _presentItem(reply.item!);
          case 'repay':
            _askRepay(reply.item!);
          case 'update_named' || 'delete_named':
            await _applyNamed(reply.item!);
          default:
            await _applyItemOperation(reply.item!);
        }
      case ChatAction.purchase:
        // Hỏi "mua X được không?" là xin kết luận: không bắt người dùng bấm thêm, thẻ tự gọi đánh giá và hiện kết quả. Lời của server ("bấm Đánh giá nhé") bỏ qua.
        final id = _nextId++;
        _add(PurchaseCard(id, reply.purchase!));
        unawaited(assessPurchase(id));
    }
  }

  /// Câu lệnh đã đủ thông tin (người dùng ra lệnh rõ, hoàn tác được): tạo ngay rồi hiện "Đã lưu" kèm "Hoàn tác". Lỗi thì thẻ báo lý do, không để lại gì.
  Future<void> _presentItem(ChatItemDraft item) async {
    final creator = createItem;
    if (creator == null) {
      _add(AssistantText(_nextId++, 'Mình hiểu rồi nhưng chưa tạo được mục này từ chat. Bạn thêm giúp mình ở tab Kế hoạch nhé.'));
      return;
    }
    final id = _nextId++;
    final card = ItemCard(id, item);
    _add(card);
    try {
      final outcome = await creator(item);
      _itemUndo[id] = outcome.undo;
      _remember(item, outcome, id);
      if (!mounted) return;
      _replace(card.copyWith(status: ItemCardStatus.created, summary: outcome.summary));
      onDataChanged?.call();
    } on MissingCategory catch (e) {
      if (mounted) _replace(card.copyWith(status: ItemCardStatus.needsCategory, missingCategory: e.name));
    } catch (e) {
      if (mounted) _replace(card.copyWith(status: ItemCardStatus.failed, error: e is StateError ? e.message : errorMessage(e)));
    }
  }

  /// Người dùng đồng ý tạo nhóm còn thiếu: tạo nhóm rồi đặt ngân sách đúng như câu đã nói. Lỗi thì thẻ báo lý do và vẫn bấm lại được.
  Future<void> confirmNewCategory(int messageId) async {
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == messageId).firstOrNull;
    final creator = createItem;
    if (card == null || creator == null || card.status != ItemCardStatus.needsCategory) return;
    _replace(card.copyWith(status: ItemCardStatus.saving));
    try {
      final outcome = await creator(card.item, createCategory: true);
      _itemUndo[messageId] = outcome.undo;
      _remember(card.item, outcome, messageId);
      if (!mounted) return;
      _replace(card.copyWith(status: ItemCardStatus.created, summary: outcome.summary));
      onDataChanged?.call();
    } catch (e) {
      if (mounted) {
        _replace(card.copyWith(status: ItemCardStatus.needsCategory, error: e is StateError ? e.message : errorMessage(e)));
      }
    }
  }

  /// Người dùng không muốn tạo nhóm mới: không tạo gì cả.
  void declineNewCategory(int messageId) {
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == messageId).firstOrNull;
    if (card != null && card.status == ItemCardStatus.needsCategory) _replace(card.copyWith(status: ItemCardStatus.declined));
  }

  /// Giải thích các con số của câu trả lời agent GẦN NHẤT bằng chính bằng chứng của nó (mỗi số có mô tả, nguồn); không gọi AI và không tính lại, nên không thể lệch với con số đã hiện.
  void _explainLastAnswer() {
    final answer = state.messages.whereType<AgentCard>().lastOrNull?.answer;
    final numbers = (answer?.evidence ?? const <AgentEvidence>[]).where((e) => e.valueVnd != null && e.text.isNotEmpty).take(8).toList();
    if (answer == null || numbers.isEmpty) {
      _add(AssistantText(_nextId++, 'Mình chưa có con số nào để giải thích. Bạn hỏi mình về mục tiêu hay chi tiêu trước, rồi hỏi lại "số này tính thế nào" nhé.'));
      return;
    }
    String source(String s) => switch (s) {
      'confirmed' => 'từ giao dịch đã xác nhận',
      'user_entered' => 'do bạn nhập hoặc khai',
      'document' => 'từ tài liệu',
      _ => 'ước tính',
    };
    final lines = [for (final e in numbers) '• ${e.text}: ${formatVnd(e.valueVnd!)} (${source(e.source)})'];
    final note = answer.preliminaryNote;
    _add(AssistantText(_nextId++, 'Các con số trong câu trả lời vừa rồi được tính như sau:\n${lines.join('\n')}${note == null ? '' : '\n\n$note'}'));
  }

  /// Sửa / xóa một mục đã có theo tên. Không thấy hoặc nhiều mục khớp thì nói rõ, không đoán. Sửa số tiền thì làm ngay (có Hoàn tác về số cũ); xóa thì hỏi xác nhận trước vì xóa không khôi phục được.
  Future<void> _applyNamed(ChatItemDraft op) async {
    final finder = findItems;
    final said = op.name ?? '';
    if (finder == null) {
      _add(AssistantText(_nextId++, 'Mình hiểu rồi nhưng chưa sửa được mục này từ chat. Bạn sửa giúp mình ở tab Kế hoạch nhé.'));
      return;
    }
    try {
      final found = await finder(op);
      if (found.isEmpty) {
        _add(AssistantText(_nextId++, 'Mình không thấy mục nào tên "$said" trong ngân sách, khoản định kỳ hay khoản vay nợ của bạn.'));
        return;
      }
      if (found.length > 1) {
        _add(AssistantText(_nextId++, 'Mình thấy ${found.length} mục khớp "$said": ${found.map((f) => f.label).join('; ')}. Bạn nói rõ hơn giúp mình nhé.'));
        return;
      }
      final item = found.single;
      final id = _nextId++;
      if (op.operation == 'delete_named') {
        _pendingDelete[id] = item;
        _add(ItemCard(id, op, status: ItemCardStatus.needsConfirm, question: 'Xóa ${item.label}?'));
        return;
      }
      final update = item.update;
      if (update == null) {
        _add(AssistantText(_nextId++, 'Mục này mình chưa sửa được từ chat. Bạn sửa giúp mình ở tab Kế hoạch nhé.'));
        return;
      }
      final previous = item.amountCents;
      final summary = await update(op.amountCents);
      _itemUndo[id] = () async {
        await update(previous);
      };
      _add(ItemCard(id, op, status: ItemCardStatus.created, summary: summary));
      onDataChanged?.call();
    } catch (e) {
      _add(AssistantText(_nextId++, 'Chưa làm được: ${e is StateError ? e.message : errorMessage(e)}'));
    }
  }

  /// Câu trả nợ khớp một khoản vay có sẵn: hỏi xác nhận trước khi ghi (lần trả không hoàn tác được và ghi cả giao dịch ví).
  void _askRepay(ChatItemDraft item) {
    final who = item.counterparty ?? '';
    final amount = formatVnd(item.amountCents);
    final remaining = item.remainingCents;
    final after = remaining == null ? '' : ' Khoản vay ${formatVnd(remaining)} sẽ còn ${formatVnd(remaining - item.amountCents)}.';
    final wallet = item.accountId == null ? ' Mình chỉ giảm nợ, không ghi giao dịch vào ví.' : ' Mình cũng ghi giao dịch tương ứng vào ví.';
    final lend = item.direction == 'lend';
    _add(
      ItemCard(
        _nextId++,
        item,
        status: ItemCardStatus.needsConfirm,
        question: '${lend ? '$who trả bạn' : 'Bạn trả $who'} $amount.$after$wallet Ghi lần trả này?',
      ),
    );
  }

  /// Người dùng đồng ý: ghi lần trả vào khoản vay. Lỗi thì thẻ báo lý do và vẫn bấm lại được.
  Future<void> confirmRepayment(int messageId) async {
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == messageId).firstOrNull;
    final repay = repayLoan;
    final pendingDelete = _pendingDelete[messageId];
    if (card == null || card.status != ItemCardStatus.needsConfirm || (repay == null && pendingDelete == null)) return;
    _replace(card.copyWith(status: ItemCardStatus.saving));
    if (pendingDelete != null) {
      try {
        await pendingDelete.delete();
        _pendingDelete.remove(messageId);
        if (!mounted) return;
        _replace(card.copyWith(status: ItemCardStatus.undone, summary: 'Đã xóa ${pendingDelete.label}.'));
        onDataChanged?.call();
      } catch (e) {
        if (mounted) _replace(card.copyWith(status: ItemCardStatus.needsConfirm, error: e is StateError ? e.message : errorMessage(e)));
      }
      return;
    }
    try {
      final summary = await repay!(card.item);
      if (!mounted) return;
      _replace(card.copyWith(status: ItemCardStatus.undone, summary: summary));
      onDataChanged?.call();
    } catch (e) {
      if (mounted) _replace(card.copyWith(status: ItemCardStatus.needsConfirm, error: e is StateError ? e.message : errorMessage(e)));
    }
  }

  void declineRepayment(int messageId) {
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == messageId).firstOrNull;
    if (card != null && card.status == ItemCardStatus.needsConfirm) {
      final isDelete = _pendingDelete.remove(messageId) != null;
      _replace(card.copyWith(status: ItemCardStatus.declined, summary: isDelete ? 'Mình không xóa gì cả.' : 'Mình không ghi lần trả này.'));
    }
  }

  void _remember(ChatItemDraft item, ItemOutcome outcome, int cardId) {
    _recent.add(_RecentItem(item, outcome, cardId));
    if (_recent.length > _maxRecentItems) _recent.removeAt(0);
  }

  /// Câu nối tiếp việc VỪA tạo: xóa, đổi số tiền hoặc cộng thêm. Chỉ áp lên việc gần nhất cùng loại; không chắc thì hỏi lại, không đoán.
  Future<void> _applyItemOperation(ChatItemDraft op) async {
    final last = _recent.lastOrNull;
    if (last == null || last.draft.kind != op.kind) {
      _add(AssistantText(_nextId++, 'Mình chưa rõ bạn muốn sửa mục nào. Bạn nói rõ hơn giúp mình nhé.'));
      return;
    }
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == last.cardId).firstOrNull;
    try {
      if (op.operation == 'delete') {
        await last.outcome.undo();
        _recent.remove(last);
        _itemUndo.remove(last.cardId);
        if (card != null) _replace(card.copyWith(status: ItemCardStatus.undone));
        _add(AssistantText(_nextId++, 'Đã xóa mục vừa tạo.'));
      } else {
        final update = last.outcome.update;
        if (update == null) {
          _add(AssistantText(_nextId++, 'Mục này mình chưa sửa được từ chat. Bạn sửa giúp mình ở tab Kế hoạch nhé.'));
          return;
        }
        final cents = op.operation == 'add' ? last.draft.amountCents + op.amountCents : op.amountCents;
        final summary = await update(cents);
        last.draft = last.draft.withAmount(cents);
        if (card != null) _replace(card.copyWith(summary: summary));
        _add(AssistantText(_nextId++, summary));
      }
      onDataChanged?.call();
    } catch (e) {
      _add(AssistantText(_nextId++, 'Chưa làm được: ${e is StateError ? e.message : errorMessage(e)}'));
    }
  }

  /// "Hoàn tác" thẻ tạo ngân sách / khoản định kỳ / vay nợ; lỗi thì thẻ giữ nguyên kèm lý do để bấm lại.
  Future<void> undoItem(int messageId) async {
    final card = state.messages.whereType<ItemCard>().where((m) => m.id == messageId).firstOrNull;
    final undo = _itemUndo[messageId];
    if (card == null || undo == null || card.status != ItemCardStatus.created) return;
    try {
      await undo();
      _itemUndo.remove(messageId);
      _recent.removeWhere((r) => r.cardId == messageId);
      if (!mounted) return;
      _replace(card.copyWith(status: ItemCardStatus.undone));
      onDataChanged?.call();
    } catch (e) {
      if (mounted) _replace(card.copyWith(error: e is StateError ? e.message : errorMessage(e)));
    }
  }

  PurchaseCard? _purchaseCard(int messageId) => state.messages
      .whereType<PurchaseCard>()
      .where((m) => m.id == messageId)
      .firstOrNull;

  /// "Đánh giá": gọi backend đúng một lần cho mỗi lần bấm; lỗi thì thẻ về trạng thái chờ kèm lý do để bấm lại. Không bao giờ ghi giao dịch.
  Future<void> assessPurchase(int messageId) async {
    final card = _purchaseCard(messageId);
    if (card == null ||
        card.status == PurchaseCardStatus.checking ||
        card.status == PurchaseCardStatus.cancelled) {
      return;
    }
    _replace(
      card.copyWith(status: PurchaseCardStatus.checking, clearError: true),
    );
    try {
      final assessment = await repository.purchaseCheck(card.purchase);
      if (!mounted) return;
      _replace(
        card.copyWith(
          status: PurchaseCardStatus.assessed,
          assessment: assessment,
          clearError: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        _replace(
          card.copyWith(
            status: PurchaseCardStatus.pending,
            error: errorMessage(e),
          ),
        );
      }
    }
  }

  void cancelPurchase(int messageId) {
    final card = _purchaseCard(messageId);
    if (card == null || card.status == PurchaseCardStatus.checking) return;
    _replace(
      card.copyWith(status: PurchaseCardStatus.cancelled, clearError: true),
    );
  }

  GoalDraftCard? _goalCard(int messageId) => state.messages
      .whereType<GoalDraftCard>()
      .where((m) => m.id == messageId)
      .firstOrNull;

  /// Sửa thẻ mục tiêu ngay trên thẻ: tên (trống thì giữ tên cũ), số tiền (phải lớn hơn 0), hạn ([clearDeadline] = không hạn)
  void updateGoal(
    int messageId, {
    String? name,
    BigInt? targetCents,
    DateTime? deadline,
    bool clearDeadline = false,
  }) {
    final card = _goalCard(messageId);
    if (card == null || card.status != GoalCardStatus.pending) return;
    final cleanName = name?.trim();
    _replace(
      card.copyWith(
        goal: card.goal.copyWith(
          name: cleanName != null && cleanName.isNotEmpty ? cleanName : null,
          targetCents: targetCents != null && targetCents > BigInt.zero
              ? targetCents
              : null,
          deadline: deadline,
          clearDeadline: clearDeadline,
        ),
        clearError: true,
      ),
    );
  }

  /// "Tạo mục tiêu": gọi `POST /saving-goals` đúng một lần. Lỗi thì thẻ về trạng thái chờ kèm lý do để bấm lại; không bao giờ tự tạo khi chưa bấm.
  Future<void> confirmGoal(int messageId) async {
    final card = _goalCard(messageId);
    final create = createGoal;
    if (card == null ||
        create == null ||
        card.status != GoalCardStatus.pending) {
      return;
    }
    final deadline = card.goal.deadline;
    if (deadline != null && !deadline.isAfter(DateTime.now())) {
      _replace(
        card.copyWith(error: 'Hạn phải ở tương lai, bạn chọn lại ngày nhé.'),
      );
      return;
    }
    _replace(card.copyWith(status: GoalCardStatus.saving, clearError: true));
    try {
      final goalId = await create(card.goal.name, card.goal.targetCents, deadline);
      if (!mounted) return;
      _replace(card.copyWith(status: GoalCardStatus.created, goalId: goalId, clearError: true));
    } catch (e) {
      if (mounted) {
        _replace(
          card.copyWith(status: GoalCardStatus.pending, error: errorMessage(e)),
        );
      }
    }
  }

  void cancelGoal(int messageId) {
    final card = _goalCard(messageId);
    if (card == null || card.status != GoalCardStatus.pending) return;
    _replace(card.copyWith(status: GoalCardStatus.cancelled, clearError: true));
  }

  /// Hiện câu đặt mục tiêu. Đủ số tiền và hạn (còn ở tương lai) thì hỏi agent mục tiêu có KHẢ THI không TRƯỚC khi tạo:
  /// khả thi thì app tạo ngay (người dùng đã ra lệnh rõ, hoàn tác được) rồi hiện phân tích; chưa khả thi, hoặc chưa đánh giá được (agent lỗi, thiếu dữ liệu),
  /// thì KHÔNG tạo: hiện phân tích kèm phương án (vd kéo dài hạn) và thẻ xác nhận để người dùng quyết định (tạo theo hạn đã nêu, tạo phương án khác, hay bỏ).
  /// Thiếu số tiền hoặc hạn, hoặc hạn do AI đọc hộ, thì chỉ có thẻ xác nhận như trước.
  bool _canAutoCreate(GoalDraft goal) {
    final deadline = goal.deadline;
    // AI đọc hộ hạn/tên (luật không hiểu câu): người dùng soát ngày rồi tự bấm tạo, không tự tạo
    return autoCreateGoals &&
        !goal.aiAssisted &&
        createGoal != null &&
        goal.targetCents > BigInt.zero &&
        deadline != null &&
        deadline.isAfter(DateTime.now());
  }

  /// [serverText] là lời của server kèm thẻ ("Bạn kiểm tra rồi bấm Tạo mục tiêu nhé"): chỉ đúng khi thẻ chờ xác nhận, nên bỏ khi app tạo ngay
  Future<void> _presentGoal(GoalDraft goal, {String? serverText}) async {
    if (!_canAutoCreate(goal)) {
      if (serverText != null) _add(AssistantText(_nextId++, serverText));
      _add(GoalDraftCard(_nextId++, goal));
      return;
    }

    final answer = await _assessGoal(goal);
    if (!mounted) return;
    final assessed = answer != null && answer.isAnswered && answer.evidenceById(_goalPlanEvidenceId) != null;
    if (assessed && answer.verdict == _feasibleVerdict) {
      final id = _nextId++;
      _add(GoalDraftCard(id, goal));
      await confirmGoal(id);
      final created = _goalCard(id);
      if (!mounted || created == null || created.status != GoalCardStatus.created) return; // lỗi tạo: thẻ chờ kèm lý do để bấm lại
      _add(AgentCard(_nextId++, answer));
      return;
    }

    _add(AssistantText(
      _nextId++,
      assessed
          ? 'Mình chưa tạo mục tiêu này vì với số liệu hiện tại nó chưa khả thi. Đây là phân tích của mình; bạn có thể tạo luôn theo hạn bạn nêu, hoặc chọn phương án khác bên dưới.'
          : 'Mình chưa đánh giá được độ khả thi của mục tiêu này lúc này nên chưa tạo. Bạn xem lại rồi bấm Tạo mục tiêu nếu muốn.',
    ));
    if (answer != null) _add(AgentCard(_nextId++, answer));
    _add(GoalDraftCard(_nextId++, goal));
  }

  /// Id của bằng chứng số tiền mục tiêu mà công cụ `goal_plan` luôn trả: có nó mới chắc câu trả lời là đánh giá ĐÚNG mục tiêu này, không phải công cụ khác
  static const _goalPlanEvidenceId = 'goal_target';
  static const _feasibleVerdict = 'feasible';

  /// Hỏi agent mục tiêu có khả thi không (công cụ `goal_plan`: mỗi tháng cần góp bao nhiêu, chưa khả thi thì kéo dài bao lâu). Lỗi (429, 503, mất mạng...) trả null.
  Future<AgentAnswer?> _assessGoal(GoalDraft goal) async {
    // Số tháng theo lịch (19/11/2026 → 19/11/2029 là đúng 36 tháng); chia ngày cho 30 cho ra 37 vì mỗi năm dư 5–6 ngày.
    final now = DateTime.now();
    final end = goal.deadline!;
    final months = ((end.year - now.year) * 12 + end.month - now.month + (end.day > now.day ? 1 : 0)).clamp(1, 600);
    state = state.copyWith(isAskingAgent: true);
    try {
      return await repository.assessGoal(goal.targetCents, months);
    } catch (_) {
      return null;
    } finally {
      if (mounted) state = state.copyWith(isAskingAgent: false);
    }
  }

  /// "Hoàn tác" mục tiêu vừa được tạo từ câu lệnh: hủy mục tiêu đó (coi như xóa). Lỗi thì thẻ giữ nguyên kèm lý do để bấm lại.
  Future<void> undoGoal(int messageId) async {
    final card = _goalCard(messageId);
    final cancel = deleteGoal;
    final goalId = card?.goalId;
    if (card == null || cancel == null || goalId == null || card.status != GoalCardStatus.created) return;
    try {
      await cancel(goalId);
      if (!mounted) return;
      _replace(card.copyWith(status: GoalCardStatus.cancelled, clearError: true));
    } catch (e) {
      if (mounted) _replace(card.copyWith(error: errorMessage(e)));
    }
  }

  /// Gửi ảnh hóa đơn vào chat để quét; kết quả là thẻ nháp cần xác nhận
  Future<void> scanReceipt(String path) => scanReceipts([path]);

  /// Ảnh chờ quét. ponytail: hàng đợi trong bộ nhớ, mất khi đóng màn chat
  final List<(String, Completer<void>)> _scanQueue = [];
  int _activeScans = 0;

  /// Gửi nhiều ảnh cùng lúc: mỗi ảnh một [ImageNote] ngay, quét song song tối đa [receiptScanConcurrency] ảnh trên toàn controller
  /// (kể cả qua nhiều lần gọi). Không đặt `isSending` nên vẫn chat văn bản được. Hoàn tất khi mọi ảnh của lần gọi này đã xong.
  Future<void> scanReceipts(List<String> paths) {
    if (paths.isEmpty || !mounted) return Future.value();
    final done = <Future<void>>[];
    for (final path in paths) {
      _add(ImageNote(_nextId++, path));
      done.add(_enqueueScan(path));
    }
    _pumpScans();
    return Future.wait(done);
  }

  Future<void> _enqueueScan(String path) {
    final completer = Completer<void>();
    _scanQueue.add((path, completer));
    state = state.copyWith(pendingScans: state.pendingScans + 1);
    return completer.future;
  }

  void _pumpScans() {
    while (_activeScans < receiptScanConcurrency && _scanQueue.isNotEmpty) {
      final (path, completer) = _scanQueue.removeAt(0);
      _activeScans++;
      _scan(path).whenComplete(() {
        _activeScans--;
        if (mounted) {
          state = state.copyWith(pendingScans: state.pendingScans - 1);
          _pumpScans();
        }
        completer.complete();
      });
    }
  }

  Future<void> _scan(String path) async {
    try {
      final scan = await repository.scanReceipt(path);
      if (!mounted) return;
      if (!scan.success || scan.draft.amountCents == null) {
        _add(
          AssistantText(
            _nextId++,
            'Không đọc được hóa đơn. Bạn thử chụp rõ hơn hoặc nhập tay.',
          ),
        );
      } else if (scan.orders.length > 1) {
        // Màn hình danh sách đơn: MỘT thẻ gộp để xác nhận một lần (mỗi đơn vẫn là một giao dịch giữ tên cửa hàng của nó), không chỉ đơn đầu
        final cut = scan.incompleteOrders > 0
            ? ' Còn ${scan.incompleteOrders} đơn bị cắt ở mép ảnh, bạn kéo xuống chụp thêm phần đó nhé.'
            : '';
        _add(
          AssistantText(
            _nextId++,
            'Mình thấy ${scan.orders.length} đơn trong ảnh. Bạn kiểm tra rồi bấm Lưu tất cả nhé.$cut',
          ),
        );
        addBatch([
          for (final order in scan.orders)
            order.copyWith(suggestedAccountId: state.selectedAccountId),
        ]);
      } else {
        _add(DraftCard(_nextId++, scan.draft));
      }
    } catch (e) {
      // Màn chat đã đóng trong lúc ảnh đang quét: không ghi gì nữa
      if (!mounted) return;
      final id = _nextId++;
      _failedScans[id] = path;
      _add(ErrorNote(id, errorMessage(e), retryText: path));
    }
  }

  /// Thêm bản nháp từ nguồn khác (ví dụ kết quả quét hóa đơn)
  void addDraft(DraftTransaction draft) => _add(DraftCard(_nextId++, draft));

  /// Đánh dấu một thẻ nháp đã được lưu
  void resolveDraft(int messageId, String summary, {String? categorySlug}) {
    final card = state.messages
        .whereType<DraftCard>()
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (local != null &&
        card != null &&
        categorySlug != null &&
        card.draft.source != DraftSource.receipt &&
        (card.draft.description ?? '').trim().isNotEmpty) {
      local!.remember(
        card.draft.merchantName,
        card.draft.description,
        categorySlug,
      ); // người dùng đã chốt danh mục: nhớ riêng ở máy
    }
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m is DraftCard && m.id == messageId)
            DraftCard(m.id, m.draft, resolved: true, resolvedSummary: summary)
          else
            m,
      ],
    );
  }

  void selectAccount(String? accountId) => state = state.copyWith(
    selectedAccountId: accountId,
    clearAccount: accountId == null,
  );
}
