import 'package:finmate/core/format/money.dart';

/// Các trường chỉ có từ server của một giao dịch: mục tiêu đã gắn, quan hệ hoàn/đảo, nghi trùng, gợi ý chuyển ví, liên kết quỹ nhóm.
/// Không lưu cục bộ (cần mạng để có ý nghĩa) nên tách khỏi [TransactionEntity]; thiếu trường thì coi như không có gì.
class TransactionLinks {
  final String? goalId;
  final String? goalName;

  /// `Refund` | `Reversal` khi đây là khoản hoàn/đảo của một khoản chi; null nếu không.
  final String? relation;
  final String? relatedTransactionId;

  /// Khoản chi đã bị đảo (BE không tính vào chi tiêu).
  final bool isReversed;

  /// Chỉ có với khoản chi đã xác nhận: tổng đã hoàn và phần còn hoàn được.
  final BigInt? refundedCents;
  final BigInt? remainingRefundableCents;

  /// Chỉ với NHÁP mà AI đoán là hoàn/đảo: các khoản chi gốc có thể là của nó.
  final List<RefundSuggestion> suggestedRelated;

  /// `suspected` | `dismissed` | null.
  final String? duplicateStatus;
  final DuplicateSummary? duplicateOf;
  final List<DuplicateSummary> suggestedDuplicates;
  final List<String> mergedSources;

  final TransferSuggestion? transferSuggestion;
  final GroupFundLink? groupFundLink;

  /// Khoản vay giao dịch này đã gắn vào (Phase 90); null nếu chưa gắn.
  final LoanLink? loanLink;

  /// Khoản vay có thể khớp (BE tính khi đọc, không bao giờ tự gắn).
  final List<LoanSuggestion> loanSuggestions;

  const TransactionLinks({
    this.goalId,
    this.goalName,
    this.relation,
    this.relatedTransactionId,
    this.isReversed = false,
    this.refundedCents,
    this.remainingRefundableCents,
    this.suggestedRelated = const [],
    this.duplicateStatus,
    this.duplicateOf,
    this.suggestedDuplicates = const [],
    this.mergedSources = const [],
    this.transferSuggestion,
    this.groupFundLink,
    this.loanLink,
    this.loanSuggestions = const [],
  });

  static const none = TransactionLinks();

  bool get isRefundOrReversal => relation == 'Refund' || relation == 'Reversal';

  /// Giao dịch mà BE nghi trùng với nó và app nên hỏi người dùng: nghi trùng đang mở, hoặc (với nháp) có ứng viên gợi ý.
  /// `dismissed` = người dùng đã bấm "không trùng" nên không hỏi lại.
  DuplicateSummary? get duplicateCandidate {
    if (duplicateStatus == 'dismissed') return null;
    return duplicateOf ?? (suggestedDuplicates.isEmpty ? null : suggestedDuplicates.first);
  }

  factory TransactionLinks.fromJson(Map<String, dynamic> json) => TransactionLinks(
        goalId: json['goalId'] as String?,
        goalName: json['goalName'] as String?,
        relation: json['relation'] as String?,
        relatedTransactionId: json['relatedTransactionId'] as String?,
        isReversed: json['isReversed'] == true,
        refundedCents: json['refundedCents'] == null ? null : parseCents(json['refundedCents']),
        remainingRefundableCents: json['remainingRefundableCents'] == null ? null : parseCents(json['remainingRefundableCents']),
        suggestedRelated: [
          for (final s in (json['suggestedRelatedTransactions'] as List? ?? const [])) RefundSuggestion.fromJson(s as Map<String, dynamic>),
        ],
        duplicateStatus: (json['duplicateStatus'] as String?)?.toLowerCase(),
        duplicateOf: json['duplicateOf'] == null ? null : DuplicateSummary.fromJson(json['duplicateOf'] as Map<String, dynamic>),
        suggestedDuplicates: [
          for (final s in (json['suggestedDuplicates'] as List? ?? const [])) DuplicateSummary.fromJson(s as Map<String, dynamic>),
        ],
        mergedSources: [for (final s in (json['mergedSources'] as List? ?? const [])) s as String],
        transferSuggestion: json['transferSuggestion'] == null
            ? null
            : TransferSuggestion.fromJson(json['transferSuggestion'] as Map<String, dynamic>),
        groupFundLink: json['groupFundLink'] == null ? null : GroupFundLink.fromJson(json['groupFundLink'] as Map<String, dynamic>),
        loanLink: json['loanLink'] is Map<String, dynamic> ? LoanLink.fromJson(json['loanLink'] as Map<String, dynamic>) : null,
        loanSuggestions: [
          for (final s in (json['loanSuggestions'] as List? ?? const [])) LoanSuggestion.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// Giao dịch đã là một dòng của khoản vay. [kind]: `principal` (giải ngân) | `repayment` (trả/thu nợ) | `interest` (tiền lãi tách riêng).
class LoanLink {
  final String loanId;
  final String title;
  final String? counterparty;
  final String kind;

  const LoanLink({required this.loanId, required this.title, this.counterparty, required this.kind});

  factory LoanLink.fromJson(Map<String, dynamic> json) => LoanLink(
        loanId: json['loanId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        counterparty: json['counterparty'] as String?,
        kind: (json['kind'] as String? ?? '').toLowerCase(),
      );
}

/// Khoản vay có thể khớp với giao dịch. [interestCents] > 0: phần vượt gốc sẽ được tách thành giao dịch lãi khi gắn.
class LoanSuggestion {
  final String loanId;
  final String title;
  final String? counterparty;
  final BigInt remainingCents;
  final DateTime? dueDate;
  final bool nameMatched;
  final BigInt interestCents;

  const LoanSuggestion({
    required this.loanId,
    required this.title,
    this.counterparty,
    required this.remainingCents,
    this.dueDate,
    this.nameMatched = false,
    required this.interestCents,
  });

  factory LoanSuggestion.fromJson(Map<String, dynamic> json) => LoanSuggestion(
        loanId: json['loanId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        counterparty: json['counterparty'] as String?,
        remainingCents: parseCents(json['remainingCents']),
        dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
        nameMatched: json['nameMatched'] == true,
        interestCents: parseCents(json['interestCents']),
      );
}

/// Một khoản chi có thể là gốc của khoản hoàn/đảo (Phase 81).
class RefundSuggestion {
  final String transactionId;
  final BigInt amountCents;
  final BigInt remainingRefundableCents;
  final String? merchantName;
  final String? categoryName;
  final DateTime? transactedAt;

  const RefundSuggestion({
    required this.transactionId,
    required this.amountCents,
    required this.remainingRefundableCents,
    this.merchantName,
    this.categoryName,
    this.transactedAt,
  });

  factory RefundSuggestion.fromJson(Map<String, dynamic> json) => RefundSuggestion(
        transactionId: json['transactionId'] as String? ?? '',
        amountCents: parseCents(json['amountCents']),
        remainingRefundableCents: parseCents(json['remainingRefundableCents']),
        merchantName: json['merchantName'] as String?,
        categoryName: json['categoryName'] as String?,
        transactedAt: DateTime.tryParse(json['transactedAt'] as String? ?? '')?.toLocal(),
      );
}

/// Một giao dịch có thể trùng (Phase 82), đủ để so sánh mà không gọi thêm.
class DuplicateSummary {
  final String id;
  final BigInt amountCents;
  final DateTime? transactedAt;

  /// Kênh đã ghi giao dịch (`Notification`, `Manual`...): để nói "ngân hàng báo" hay "bạn đã nhập".
  final String source;
  final String? merchantName;
  final String? categoryName;
  final String? accountName;

  const DuplicateSummary({
    required this.id,
    required this.amountCents,
    required this.transactedAt,
    required this.source,
    this.merchantName,
    this.categoryName,
    this.accountName,
  });

  factory DuplicateSummary.fromJson(Map<String, dynamic> json) => DuplicateSummary(
        id: json['id'] as String? ?? '',
        amountCents: parseCents(json['amountCents']),
        transactedAt: DateTime.tryParse(json['transactedAt'] as String? ?? '')?.toLocal(),
        source: json['source'] as String? ?? '',
        merchantName: json['merchantName'] as String?,
        categoryName: json['categoryName'] as String?,
        accountName: json['financialAccountName'] as String?,
      );
}

/// Gợi ý "đây có thể là chuyển tiền giữa các ví của bạn" (Phase 83).
class TransferSuggestion {
  /// `AtmWithdrawal` | `AtmDeposit` | `WalletTopup` | `WalletWithdrawal` | `OwnAccount`.
  final String kind;

  /// Chiều bên kia nếu BE đã tìm thấy; null thì người dùng chọn một ví trong [candidateAccounts].
  final TransferPaired? paired;
  final List<TransferAccount> candidateAccounts;
  final BigInt? feeCents;

  const TransferSuggestion({required this.kind, required this.paired, required this.candidateAccounts, required this.feeCents});

  factory TransferSuggestion.fromJson(Map<String, dynamic> json) => TransferSuggestion(
        kind: json['kind'] as String? ?? '',
        paired: json['pairedTransaction'] == null ? null : TransferPaired.fromJson(json['pairedTransaction'] as Map<String, dynamic>),
        candidateAccounts: [
          for (final a in (json['candidateAccounts'] as List? ?? const [])) TransferAccount.fromJson(a as Map<String, dynamic>),
        ],
        feeCents: json['feeCents'] == null ? null : parseCents(json['feeCents']),
      );
}

class TransferPaired {
  final String id;
  final BigInt amountCents;
  final DateTime? transactedAt;
  final String accountId;
  final String? accountName;

  const TransferPaired({required this.id, required this.amountCents, required this.transactedAt, required this.accountId, this.accountName});

  factory TransferPaired.fromJson(Map<String, dynamic> json) => TransferPaired(
        id: json['id'] as String? ?? '',
        amountCents: parseCents(json['amountCents']),
        transactedAt: DateTime.tryParse(json['transactedAt'] as String? ?? '')?.toLocal(),
        accountId: json['financialAccountId'] as String? ?? '',
        accountName: json['financialAccountName'] as String?,
      );
}

class TransferAccount {
  final String id;
  final String name;
  final String accountType;

  const TransferAccount({required this.id, required this.name, required this.accountType});

  factory TransferAccount.fromJson(Map<String, dynamic> json) => TransferAccount(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        accountType: json['accountType'] as String? ?? '',
      );
}

/// Giao dịch này ghi lại một dòng quỹ nhóm ở sổ cá nhân (Phase 85).
class GroupFundLink {
  final String groupId;
  final String fundId;
  final String fundName;

  /// `Contribution` | `Expense` | `Withdrawal`.
  final String kind;

  /// `out` | `in`.
  final String direction;

  /// Người quản lý đã xóa dòng quỹ; giao dịch vẫn ở sổ cá nhân.
  final bool entryDeleted;

  const GroupFundLink({
    required this.groupId,
    required this.fundId,
    required this.fundName,
    required this.kind,
    required this.direction,
    required this.entryDeleted,
  });

  factory GroupFundLink.fromJson(Map<String, dynamic> json) => GroupFundLink(
        groupId: json['groupId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        fundName: json['fundName'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        direction: json['direction'] as String? ?? '',
        entryDeleted: json['entryDeleted'] == true,
      );
}

/// Số dư một ví trước và sau một thao tác xem trước (gộp / chuyển đổi).
class BalanceChange {
  final String accountId;
  final String accountName;
  final BigInt beforeCents;
  final BigInt afterCents;

  const BalanceChange({required this.accountId, required this.accountName, required this.beforeCents, required this.afterCents});

  factory BalanceChange.fromJson(Map<String, dynamic> json) => BalanceChange(
        accountId: json['accountId'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        beforeCents: parseCents(json['balanceBeforeCents']),
        afterCents: parseCents(json['balanceAfterCents']),
      );
}
