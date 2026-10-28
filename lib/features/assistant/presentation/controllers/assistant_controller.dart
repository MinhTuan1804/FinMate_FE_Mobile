import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart';
import 'package:finmate/features/assistant/data/local_first_chat.dart';
import 'package:finmate/features/assistant/data/pending_message_store.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
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

  const DraftCard(super.id, this.draft, {this.resolved = false, this.resolvedSummary});
}

/// Câu có nhiều khoản (nhiều danh mục): MỘT thẻ để xác nhận một lần ("Lưu tất cả"), mỗi khoản vẫn là một giao dịch theo danh mục của nó
class DraftBatchCard extends ChatMessage {
  final List<DraftTransaction> drafts;

  /// Mã chống trùng của từng khoản, tạo một lần và dùng lại khi thử lại để server/máy không ghi hai lần
  final List<String> requestIds;

  /// Đã ghi ở máy (cả nhóm cùng lúc)
  final String? resolvedSummary;
  final String? error;

  const DraftBatchCard(super.id, this.drafts, this.requestIds, {this.resolvedSummary, this.error});

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

  DraftBatchCard copyWith({List<DraftTransaction>? drafts, String? resolvedSummary, String? error, bool clearError = false}) => DraftBatchCard(
        id,
        drafts ?? this.drafts,
        requestIds,
        resolvedSummary: resolvedSummary ?? this.resolvedSummary,
        error: clearError ? null : (error ?? this.error),
      );
}

enum GoalCardStatus { pending, saving, created, cancelled }

/// Câu đặt mục tiêu tiết kiệm: thẻ xác nhận. Không bao giờ tự tạo; người dùng sửa rồi bấm "Tạo mục tiêu" (app gọi `POST /saving-goals`)
class GoalDraftCard extends ChatMessage {
  final GoalDraft goal;
  final GoalCardStatus status;
  final String? error;

  const GoalDraftCard(super.id, this.goal, {this.status = GoalCardStatus.pending, this.error});

  GoalDraftCard copyWith({GoalDraft? goal, GoalCardStatus? status, String? error, bool clearError = false}) => GoalDraftCard(
        id,
        goal ?? this.goal,
        status: status ?? this.status,
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
  final String? selectedAccountId;

  const AssistantState({this.messages = const [], this.isSending = false, this.selectedAccountId});

  AssistantState copyWith({List<ChatMessage>? messages, bool? isSending, String? selectedAccountId, bool clearAccount = false}) {
    return AssistantState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      selectedAccountId: clearAccount ? null : (selectedAccountId ?? this.selectedAccountId),
    );
  }
}

/// Lịch sử chỉ giữ trong phiên và bị xóa khi đổi người dùng/đăng xuất
final assistantControllerProvider = StateNotifierProvider<AssistantController, AssistantState>((ref) {
  ref.watch(currentUserIdProvider);
  final controller = AssistantController(
    repository: ref.watch(assistantRepositoryProvider),
    local: ref.watch(localFirstChatProvider) ? LocalFirstChat.fromRef(ref) : null,
    saver: DraftSaver.fromRef(ref),
    pending: ref.watch(pendingMessageStoreProvider),
    createGoal: (name, target, deadline) =>
        ref.read(planningControllerProvider.notifier).createSavingsGoal(title: name, targetAmountCents: target, targetDate: deadline),
    onDataChanged: () {
      refreshDerivedData(ref);
      ref.invalidate(transactionControllerProvider);
    },
  );
  Future.microtask(controller.retryPending); // câu giữ lại từ lần mất mạng trước (kể cả trước khi tắt app)
  return controller;
});

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

  /// Tạo mục tiêu tiết kiệm sau khi người dùng xác nhận thẻ (gọi `POST /saving-goals`); null = thẻ mục tiêu không tạo được
  final Future<void> Function(String name, BigInt targetCents, DateTime? deadline)? createGoal;
  Timer? _retryTimer;
  bool _retrying = false;

  /// Mã các câu được giữ lại ngay trong phiên này (bong bóng của người dùng đã hiện sẵn); câu giữ từ lần chạy trước thì chưa có
  final Set<String> _heldThisSession = {};
  final Set<String> _shownOnce = {}; // câu cũ đã hiện lại một lần (vẫn mất mạng thì lần thử sau không hiện nữa)

  final Map<int, _FailedSend> _failed = {};
  final Map<int, String> _failedScans = {};
  final Map<int, _FailedVoice> _failedVoices = {};
  int _nextId = 0;

  /// [retryEvery]: chu kỳ tự phân tích lại các câu đang chờ (null = không tự chạy, test gọi [retryPending] trực tiếp)
  AssistantController({required this.repository, this.onDataChanged, this.local, this.saver, this.pending, this.createGoal, Duration? retryEvery = const Duration(seconds: 30)})
      : super(const AssistantState()) {
    if (pending != null && retryEvery != null) _retryTimer = Timer.periodic(retryEvery, (_) => retryPending());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _add(ChatMessage message) {
    if (!mounted) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Gửi một tin nhắn cho chatbot. Mỗi tin nhắn có một `clientRequestId` riêng, dùng lại khi gửi lại.
  Future<void> send(String text, {DraftSource source = DraftSource.chat}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    _add(UserText(_nextId++, trimmed));
    if (await _deliver(trimmed, const Uuid().v4(), source)) unawaited(retryPending());
  }

  /// Gửi lại tin nhắn bị lỗi bằng đúng `clientRequestId` cũ để backend không tạo trùng
  Future<void> retry(int errorMessageId) async {
    final voice = _failedVoices.remove(errorMessageId);
    if (voice != null) {
      if (state.isSending) return;
      state = state.copyWith(messages: state.messages.where((m) => m.id != errorMessageId).toList());
      await _deliverVoice(voice.path, voice.requestId);
      return;
    }
    final scanPath = _failedScans.remove(errorMessageId);
    if (scanPath != null) {
      if (state.isSending) return;
      state = state.copyWith(messages: state.messages.where((m) => m.id != errorMessageId).toList());
      await _scan(scanPath);
      return;
    }
    final failed = _failed.remove(errorMessageId);
    if (failed == null || state.isSending) return;

    state = state.copyWith(messages: state.messages.where((m) => m.id != errorMessageId).toList());
    await _deliver(failed.text, failed.requestId, failed.source);
  }

  /// Trả false khi mất mạng (câu được giữ lại để phân tích sau, hoặc đã nằm sẵn trong hàng chờ), true khi đã có kết quả hay lỗi để hiện.
  Future<bool> _deliver(String text, String requestId, DraftSource source, {bool fromQueue = false}) async {
    state = state.copyWith(isSending: true);
    try {
      final local = this.local;
      if (local != null) {
        final analysis = await repository.analyze(text);
        if (!mounted) return true;
        await _decideLocally(local, analysis, text, requestId, source);
      } else {
        final reply = await repository.chat(text, accountId: state.selectedAccountId, clientRequestId: requestId);
        if (!mounted) return true;
        _present(reply, source);
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

  static const _heldNotice = 'Đang không có mạng. Mình giữ câu này trên máy và sẽ phân tích khi có mạng lại.';

  /// Phân tích lại các câu đã giữ lại vì mất mạng, theo thứ tự, bằng đúng mã chống trùng cũ. Dừng ngay khi vẫn mất mạng (câu sau không
  /// được vượt mặt câu trước). Chạy tự động theo chu kỳ, khi mở app, và sau mỗi lần gửi thành công.
  Future<void> retryPending() async {
    final store = pending;
    if (store == null || _retrying || state.isSending) return;
    _retrying = true;
    try {
      for (final item in await store.all()) {
        if (!mounted) return;
        if (item.kind == PendingKind.text && !_heldThisSession.contains(item.id) && !_shownOnce.contains(item.id)) {
          _shownOnce.add(item.id);
          _add(UserText(_nextId++, item.content)); // câu giữ từ lần chạy trước: hiện lại câu gốc trước kết quả
        }
        final reached = item.kind == PendingKind.text
            ? await _deliver(item.content, item.id, item.source, fromQueue: true)
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

  Future<bool> _deliverVoice(String path, String requestId, {bool fromQueue = false}) async {
    state = state.copyWith(isSending: true);
    try {
      final local = this.local;
      if (local != null) {
        final voice = await repository.analyzeVoice(path);
        if (!mounted) return true;
        _add(UserText(_nextId++, voice.transcript));
        await _decideLocally(local, voice.analysis, voice.transcript, requestId, DraftSource.voice);
      } else {
        final voice = await repository.voiceChat(path, accountId: state.selectedAccountId, clientRequestId: requestId);
        if (!mounted) return true;
        _add(UserText(_nextId++, voice.transcript));
        _present(voice.chat, DraftSource.voice);
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
  Future<void> _decideLocally(LocalFirstChat local, ChatAnalysis analysis, String text, String requestId, DraftSource source) async {
    final decision = await local.decider.decide(analysis, accountId: state.selectedAccountId, now: DateTime.now(), source: source);
    if (!mounted) return;
    switch (decision) {
      case SaveNow(:final draft, :final notes):
        final categoryId = local.saver.categoryIdOf(draft.categorySlug!);
        final accountId = draft.suggestedAccountId;
        if (categoryId == null || accountId == null) {
          _add(DraftCard(_nextId++, draft)); // chưa có danh mục của server hoặc ví: để người dùng xem và lưu
        } else {
          final tx = await local.saver.save(draft, categoryId: categoryId, accountId: accountId, clientRequestId: requestId);
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
        if (replyText != null) _add(AssistantText(_nextId++, replyText));
        _add(GoalDraftCard(_nextId++, goal));
        _addNotes(notes);
      case NeedSummary():
        final reply = await repository.chat(text, accountId: state.selectedAccountId, clientRequestId: requestId);
        if (!mounted) return;
        _present(reply, source);
    }
  }

  /// Một khoản: thẻ nháp như thường. Nhiều khoản: MỘT thẻ gộp để xác nhận một lần. Chuyển tiền giữa hai ví cần chọn ví nên luôn là thẻ nháp riêng.
  void addBatch(List<DraftTransaction> drafts) {
    final transfers = [for (final d in drafts) if (d.kind == DraftKind.transfer) d];
    final others = [for (final d in drafts) if (d.kind != DraftKind.transfer) d];
    if (others.length == 1) {
      _add(DraftCard(_nextId++, others.single));
    } else if (others.length > 1) {
      _add(DraftBatchCard(_nextId++, others, [for (final _ in others) const Uuid().v4()]));
    }
    for (final t in transfers) {
      _add(DraftCard(_nextId++, t));
    }
  }

  DraftBatchCard? _batch(int messageId) => state.messages.whereType<DraftBatchCard>().where((m) => m.id == messageId).firstOrNull;

  void _replace(ChatMessage updated) {
    if (!mounted) return;
    state = state.copyWith(messages: [for (final m in state.messages) m.id == updated.id ? updated : m]);
  }

  /// Chọn danh mục cho một khoản còn thiếu ngay trên thẻ gộp
  void setBatchCategory(int messageId, int index, String slug) {
    final batch = _batch(messageId);
    if (batch == null || index < 0 || index >= batch.drafts.length) return;
    final drafts = [...batch.drafts];
    drafts[index] = drafts[index].copyWith(categorySlug: slug, missingFields: [for (final f in drafts[index].missingFields) if (f != 'category') f]);
    _replace(batch.copyWith(drafts: drafts, clearError: true));
  }

  /// Sửa một dòng ngay trên thẻ gộp (số tiền, ghi chú, danh mục). Số tiền không hợp lệ (<= 0) bị bỏ qua, mã chống trùng giữ nguyên.
  void updateBatchDraft(int messageId, int index, {BigInt? amountCents, String? description, String? categorySlug}) {
    final batch = _batch(messageId);
    if (batch == null || index < 0 || index >= batch.drafts.length) return;
    final old = batch.drafts[index];
    final validAmount = amountCents != null && amountCents > BigInt.zero ? amountCents : null;
    final drafts = [...batch.drafts];
    drafts[index] = old.copyWith(
      amountCents: validAmount,
      description: description,
      categorySlug: categorySlug,
      missingFields: categorySlug == null ? null : [for (final f in old.missingFields) if (f != 'category') f],
    );
    _replace(batch.copyWith(drafts: drafts, clearError: true));
  }

  /// "Lưu tất cả": ghi cả nhóm ở máy trong MỘT lần (được tất cả hoặc không gì; mất mạng hay không đều xong ngay), rồi đồng bộ lên server ngầm.
  /// Bấm lại sau lỗi dùng đúng các mã chống trùng cũ.
  Future<void> confirmBatch(int messageId) async {
    final batch = _batch(messageId);
    final saver = this.saver;
    if (batch == null || saver == null || batch.resolved || state.isSending) return;
    if (!batch.allComplete) {
      _replace(batch.copyWith(error: 'Còn khoản cần bổ sung thông tin, hãy chọn danh mục hoặc bấm "Sửa từng khoản".'));
      return;
    }
    final items = <DraftSave>[];
    for (var i = 0; i < batch.drafts.length; i++) {
      final draft = batch.drafts[i];
      final categoryId = saver.categoryIdOf(draft.categorySlug ?? 'income');
      if (categoryId == null) {
        _replace(batch.copyWith(error: 'Chưa tải được danh mục, bạn thử lại sau ít giây nhé.'));
        return;
      }
      items.add(DraftSave(draft, categoryId, draft.suggestedAccountId!, batch.requestIds[i]));
    }
    state = state.copyWith(isSending: true);
    try {
      await saver.saveAll(items);
      if (!mounted) return;
      final total = batch.drafts.fold<BigInt>(BigInt.zero, (a, d) => a + d.amountCents!);
      _replace(batch.copyWith(resolvedSummary: 'Đã ghi ${batch.drafts.length} giao dịch: ${formatVnd(total)}', clearError: true));
      onDataChanged?.call();
      for (final draft in batch.drafts) {
        final slug = draft.categorySlug;
        if (local != null && slug != null && draft.source != DraftSource.receipt && (draft.description ?? '').trim().isNotEmpty) {
          local!.remember(draft.merchantName, draft.description, slug); // đã xác nhận: nhớ riêng ở máy
        }
      }
      // Đồng bộ lên server ngầm: người dùng không phải chờ, và mất mạng thì hàng đợi giữ nguyên cho lần sau
      saver.syncNow().then((_) => mounted ? onDataChanged?.call() : null, onError: (_) {});
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
    final cards = <ChatMessage>[for (final d in batch.drafts) DraftCard(_nextId++, d)];
    state = state.copyWith(messages: [
      for (final m in state.messages)
        if (m.id == messageId) ...cards else m,
    ]);
  }

  void _addNotes(List<String> notes) {
    for (final note in notes) {
      _add(AssistantText(_nextId++, note));
    }
  }

  void _present(ChatReply reply, DraftSource source) {
    switch (reply.action) {
      case ChatAction.saved:
        _add(SavedCard(_nextId++, reply.transaction!));
        onDataChanged?.call();
      case ChatAction.summary:
        _add(SummaryCard(_nextId++, reply.summary!));
      case ChatAction.confirm:
        final drafts = reply.drafts.isEmpty ? [reply.draft!] : reply.drafts;
        // Nhiều khoản trong một câu: lời báo của BE rồi mỗi khoản một thẻ, người dùng rà soát và lưu từng khoản.
        if (reply.replyText != null) _add(AssistantText(_nextId++, reply.replyText!)); // lời nhắn của server (nhiều khoản, vế thiếu tiền, tổng không khớp)
        addBatch([for (final d in drafts) d.copyWith(source: source)]);
      case ChatAction.reply:
        _add(AssistantText(_nextId++, reply.replyText ?? ''));
      case ChatAction.goal:
        if (reply.replyText != null) _add(AssistantText(_nextId++, reply.replyText!));
        _add(GoalDraftCard(_nextId++, reply.goal!));
    }
  }

  GoalDraftCard? _goalCard(int messageId) => state.messages.whereType<GoalDraftCard>().where((m) => m.id == messageId).firstOrNull;

  /// Sửa thẻ mục tiêu ngay trên thẻ: tên (trống thì giữ tên cũ), số tiền (phải lớn hơn 0), hạn ([clearDeadline] = không hạn)
  void updateGoal(int messageId, {String? name, BigInt? targetCents, DateTime? deadline, bool clearDeadline = false}) {
    final card = _goalCard(messageId);
    if (card == null || card.status != GoalCardStatus.pending) return;
    final cleanName = name?.trim();
    _replace(card.copyWith(
      goal: card.goal.copyWith(
        name: cleanName != null && cleanName.isNotEmpty ? cleanName : null,
        targetCents: targetCents != null && targetCents > BigInt.zero ? targetCents : null,
        deadline: deadline,
        clearDeadline: clearDeadline,
      ),
      clearError: true,
    ));
  }

  /// "Tạo mục tiêu": gọi `POST /saving-goals` đúng một lần. Lỗi thì thẻ về trạng thái chờ kèm lý do để bấm lại; không bao giờ tự tạo khi chưa bấm.
  Future<void> confirmGoal(int messageId) async {
    final card = _goalCard(messageId);
    final create = createGoal;
    if (card == null || create == null || card.status != GoalCardStatus.pending) return;
    final deadline = card.goal.deadline;
    if (deadline != null && !deadline.isAfter(DateTime.now())) {
      _replace(card.copyWith(error: 'Hạn phải ở tương lai, bạn chọn lại ngày nhé.'));
      return;
    }
    _replace(card.copyWith(status: GoalCardStatus.saving, clearError: true));
    try {
      await create(card.goal.name, card.goal.targetCents, deadline);
      if (!mounted) return;
      _replace(card.copyWith(status: GoalCardStatus.created, clearError: true));
    } catch (e) {
      if (mounted) _replace(card.copyWith(status: GoalCardStatus.pending, error: errorMessage(e)));
    }
  }

  void cancelGoal(int messageId) {
    final card = _goalCard(messageId);
    if (card == null || card.status != GoalCardStatus.pending) return;
    _replace(card.copyWith(status: GoalCardStatus.cancelled, clearError: true));
  }

  /// Gửi ảnh hóa đơn vào chat để quét; kết quả là thẻ nháp cần xác nhận
  Future<void> scanReceipt(String path) async {
    if (state.isSending) return;
    _add(ImageNote(_nextId++, path));
    await _scan(path);
  }

  Future<void> _scan(String path) async {
    state = state.copyWith(isSending: true);
    try {
      final scan = await repository.scanReceipt(path);
      if (!mounted) return;
      if (!scan.success || scan.draft.amountCents == null) {
        _add(AssistantText(_nextId++, 'Không đọc được hóa đơn. Bạn thử chụp rõ hơn hoặc nhập tay.'));
      } else if (scan.orders.length > 1) {
        // Màn hình danh sách đơn: MỘT thẻ gộp để xác nhận một lần (mỗi đơn vẫn là một giao dịch giữ tên cửa hàng của nó), không chỉ đơn đầu
        final cut = scan.incompleteOrders > 0 ? ' Còn ${scan.incompleteOrders} đơn bị cắt ở mép ảnh, bạn kéo xuống chụp thêm phần đó nhé.' : '';
        _add(AssistantText(_nextId++, 'Mình thấy ${scan.orders.length} đơn trong ảnh. Bạn kiểm tra rồi bấm Lưu tất cả nhé.$cut'));
        addBatch([for (final order in scan.orders) order.copyWith(suggestedAccountId: state.selectedAccountId)]);
      } else {
        _add(DraftCard(_nextId++, scan.draft));
      }
    } catch (e) {
      final id = _nextId++;
      _failedScans[id] = path;
      _add(ErrorNote(id, errorMessage(e), retryText: path));
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  /// Thêm bản nháp từ nguồn khác (ví dụ kết quả quét hóa đơn)
  void addDraft(DraftTransaction draft) => _add(DraftCard(_nextId++, draft));

  /// Đánh dấu một thẻ nháp đã được lưu
  void resolveDraft(int messageId, String summary, {String? categorySlug}) {
    final card = state.messages.whereType<DraftCard>().where((m) => m.id == messageId).firstOrNull;
    if (local != null && card != null && categorySlug != null && card.draft.source != DraftSource.receipt && (card.draft.description ?? '').trim().isNotEmpty) {
      local!.remember(card.draft.merchantName, card.draft.description, categorySlug); // người dùng đã chốt danh mục: nhớ riêng ở máy
    }
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m is DraftCard && m.id == messageId) DraftCard(m.id, m.draft, resolved: true, resolvedSummary: summary) else m,
      ],
    );
  }

  void selectAccount(String? accountId) => state = state.copyWith(selectedAccountId: accountId, clearAccount: accountId == null);
}
