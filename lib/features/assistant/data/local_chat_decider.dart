import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Quyết định của chat sau khi server đã HIỂU câu: ghi ngay, hỏi lại (nháp), tính tổng hay chỉ trả lời. Cùng quy tắc với
/// `ChatCommandHandler` của backend nhưng chạy bằng dữ liệu trên máy, nên server không cần giữ giao dịch của người dùng.
sealed class ChatDecision {
  /// Lời nhắn thêm cho người dùng (vế bị bỏ vì thiếu tiền, tổng đã nói khác tổng các khoản...)
  final List<String> notes;
  const ChatDecision({this.notes = const []});
}

class SaveNow extends ChatDecision {
  final DraftTransaction draft;
  const SaveNow(this.draft, {super.notes});
}

class Drafts extends ChatDecision {
  final List<DraftTransaction> drafts;
  final String? replyText;

  /// Chỉ số khoản -> mã giao dịch có thể trùng
  final Map<int, String> duplicateOf;
  const Drafts(this.drafts, {this.replyText, this.duplicateOf = const {}, super.notes});
}

class Reply extends ChatDecision {
  final String text;
  const Reply(this.text, {super.notes});
}

/// Đặt mục tiêu tiết kiệm: luôn hiện thẻ xác nhận, không bao giờ tự tạo
class GoalDecision extends ChatDecision {
  final GoalDraft goal;
  final String? replyText;
  const GoalDecision(this.goal, {this.replyText, super.notes});
}

/// Câu hỏi tổng: vẫn do server tính cho đến khi lịch sử giao dịch nằm đủ trên máy
class NeedSummary extends ChatDecision {
  const NeedSummary();
}

const _letters = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Khóa của bộ nhớ danh mục: chữ thường, bỏ dấu, gọn khoảng trắng
String memoryKey(String? text) {
  var out = (text ?? '').toLowerCase();
  _letters.forEach((plain, accented) {
    for (final ch in accented.split('')) {
      out = out.replaceAll(ch, plain);
    }
  });
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class LocalChatDecider {
  final AppDatabase db;
  final Duration duplicateWindow;

  const LocalChatDecider({required this.db, this.duplicateWindow = const Duration(minutes: 10)});

  /// [accountId]: ví đang chọn (hoặc ví duy nhất); null thì khoản chi chỉ là nháp thiếu ví
  Future<ChatDecision> decide(ChatAnalysis analysis, {required String? accountId, required DateTime now, DraftSource source = DraftSource.chat}) async {
    if (analysis.goal != null) return GoalDecision(analysis.goal!, replyText: analysis.replyText);
    if (analysis.goal != null) return GoalDecision(analysis.goal!, replyText: analysis.replyText);
    if (analysis.entries.isEmpty) {
      if (analysis.hasQuery) return const NeedSummary();
      return Reply(analysis.replyText ?? 'Mình chưa hiểu câu này. Bạn thử lại nhé.');
    }

    final notes = _notes(analysis);
    final entries = [for (final e in analysis.entries) await _withMemory(e)];

    if (entries.length > 1) {
      final drafts = <DraftTransaction>[];
      final duplicates = <int, String>{};
      for (var i = 0; i < entries.length; i++) {
        final duplicate = await _findDuplicate(entries[i], now);
        if (duplicate != null) duplicates[i] = duplicate;
        drafts.add(_draftOf(entries[i], accountId, duplicate, source));
      }
      return Drafts(drafts,
          replyText: analysis.replyText ?? 'Mình thấy ${drafts.length} khoản trong câu này. Bạn kiểm tra và xác nhận từng khoản nhé.',
          duplicateOf: duplicates,
          notes: notes);
    }

    final entry = entries.single;
    final duplicate = await _findDuplicate(entry, now);
    final draft = _draftOf(entry, accountId, duplicate, source);
    // Còn điều chưa khớp trong câu (vế thiếu tiền, tổng đã nói khác tổng các khoản): luôn hỏi lại, kể cả khi server báo autoSaveOk
    final unresolved = analysis.totalMismatch || analysis.skipped.isNotEmpty;
    if (!unresolved && duplicate == null && entry.autoSaveOk && entry.kind == 'expense' && accountId != null && entry.amountCents > BigInt.zero && entry.categorySlug != null) {
      return SaveNow(draft, notes: notes);
    }
    return Drafts([draft], replyText: analysis.replyText, duplicateOf: duplicate == null ? const {} : {0: duplicate}, notes: notes);
  }

  List<String> _notes(ChatAnalysis analysis) {
    final notes = <String>[];
    for (final clause in analysis.skipped) {
      notes.add('Mình chưa thấy số tiền cho "$clause" nên chưa ghi. Bạn nhắn thêm số tiền nhé.');
    }
    if (analysis.totalMismatch && analysis.totalAmount != null) {
      final sum = analysis.entries.fold<BigInt>(BigInt.zero, (a, e) => a + e.amountCents);
      notes.add('Bạn nói tổng ${formatVnd(BigInt.from(analysis.totalAmount!))} nhưng các khoản cộng lại là ${formatVnd(sum)}. Kiểm tra lại giúp mình nhé.');
    }
    return notes;
  }

  /// Bộ nhớ riêng thắng gợi ý yếu: điền món chưa biết, đè gợi ý từ bảng nhớ chung, và chỉ đè luật chung khi đã xác nhận từ 2 lần
  Future<AnalyzedEntry> _withMemory(AnalyzedEntry e) async {
    if (e.kind != 'expense' || (e.description ?? '').trim().isEmpty) return e;
    final memory = await db.categoryMemory(memoryKey(e.merchantName), memoryKey(e.description)) ??
        (e.merchantName == null ? null : await db.categoryMemory('', memoryKey(e.description)));
    if (memory == null || memory.categorySlug == e.categorySlug) return e;
    final weak = e.categorySlug == null || e.categorySource != 'rule';
    if (!weak && memory.confirmCount < 2) return e;
    return AnalyzedEntry(
      kind: e.kind,
      amountCents: e.amountCents,
      description: e.description,
      merchantName: e.merchantName,
      categorySlug: memory.categorySlug,
      categorySource: 'memory',
      incomeType: e.incomeType,
      autoSaveOk: false, // nguồn "memory" chỉ gợi ý cho đến khi người dùng xác nhận lại
      toOthers: e.toOthers,
      occurredAt: e.occurredAt,
    );
  }

  Future<String?> _findDuplicate(AnalyzedEntry e, DateTime now) async {
    if (e.kind != 'expense' || e.amountCents <= BigInt.zero) return null;
    final at = e.occurredAt ?? now;
    for (final row in await db.getAllTransactions()) {
      if (row.transactionType == 'Debit' && row.amountCents == e.amountCents && row.transactedAt.difference(at).abs() <= duplicateWindow) {
        return row.id;
      }
    }
    return null;
  }

  DraftTransaction _draftOf(AnalyzedEntry e, String? accountId, String? duplicate, DraftSource source) {
    final transfer = e.kind == 'transfer';
    final missing = <String>[
      if (transfer) 'accounts' else ...[if (e.kind == 'expense' && e.categorySlug == null) 'category', if (accountId == null) 'account'],
    ];
    return DraftTransaction(
      kind: transfer ? DraftKind.transfer : DraftKind.expense,
      amountCents: e.amountCents,
      type: switch (e.kind) {
        'transfer' => TransactionType.transfer,
        'income' => TransactionType.income,
        _ => TransactionType.expense,
      },
      merchantName: e.merchantName,
      description: e.description,
      categorySlug: e.categorySlug,
      suggestedAccountId: transfer ? null : accountId,
      missingFields: missing,
      source: source,
      transactedAt: e.occurredAt,
      possibleDuplicateId: duplicate,
    );
  }
}
