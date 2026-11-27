import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

enum LoanType { borrow, lend } // Đi vay hoặc Cho vay

/// Một khoản vay/cho vay (GET /loans). [paidCents] và [remainingCents] do server tính từ các lần trả.
class LoanItem {
  final String id;
  final LoanType type;
  final String title;
  final String counterparty; // Người vay hoặc Ngân hàng
  final BigInt principalCents;
  final BigInt paidCents;
  final BigInt remainingCents;
  final double interestRateYear; // %/năm, chỉ để hiển thị
  final DateTime? dueDate;
  final DateTime? startDate;

  /// Lãi tạm tính (lãi đơn trên dư nợ gốc, chỉ để tham khảo); [totalDueCents] = còn lại + lãi tạm tính
  final BigInt? accruedInterestCents;

  /// `open` | `settled` | `written_off` (BE Phase 90). Khoản `written_off` có thể còn `remainingCents > 0`
  /// — không được coi là "đã xong" chỉ bằng cách so `remainingCents` với 0, phải đọc trường này.
  final String status;

  const LoanItem({
    required this.id,
    required this.type,
    required this.title,
    required this.counterparty,
    required this.principalCents,
    required this.paidCents,
    required this.remainingCents,
    required this.interestRateYear,
    this.dueDate,
    this.startDate,
    this.accruedInterestCents,
    this.status = 'open',
  });

  BigInt get totalDueCents => remainingCents + (accruedInterestCents ?? BigInt.zero);

  /// Đã trả xong (`settled`) hoặc chủ động xoá nợ (`written_off`); không chỉ dựa vào `remainingCents == 0`
  /// vì một khoản xoá nợ có thể còn hiện số dư chưa trả.
  bool get isClosed => status == 'settled' || status == 'written_off';

  factory LoanItem.fromJson(Map<String, dynamic> json) => LoanItem(
        id: json['id'] as String,
        type: json['direction'] == 'lend' ? LoanType.lend : LoanType.borrow,
        title: json['title'] as String? ?? '',
        counterparty: json['counterparty'] as String? ?? '',
        principalCents: parseCents(json['principalCents']),
        paidCents: parseCents(json['paidCents']),
        remainingCents: parseCents(json['remainingCents']),
        interestRateYear: (json['interestRatePercentYear'] as num?)?.toDouble() ?? 0,
        dueDate: json['dueDate'] == null ? null : DateTime.tryParse(json['dueDate'] as String),
        startDate: json['startDate'] == null ? null : DateTime.tryParse(json['startDate'] as String),
        accruedInterestCents: parseCents(json['accruedInterestCents']),
        status: json['status'] as String? ?? 'open',
      );
}

/// Tổng hợp sổ vay (GET /loans/summary): chỉ khoản `open`, theo gốc còn lại. Do BE tính; app không cộng lại.
class LoanSummary {
  final BigInt owedToMeCents;
  final BigInt iOweCents;
  final int overdueCount;
  final BigInt overdueOwedToMeCents;
  final BigInt overdueIOweCents;

  const LoanSummary({
    required this.owedToMeCents,
    required this.iOweCents,
    required this.overdueCount,
    required this.overdueOwedToMeCents,
    required this.overdueIOweCents,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) => LoanSummary(
        owedToMeCents: parseCents(json['owedToMeCents']),
        iOweCents: parseCents(json['iOweCents']),
        overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
        overdueOwedToMeCents: parseCents(json['overdueOwedToMeCents']),
        overdueIOweCents: parseCents(json['overdueIOweCents']),
      );
}

/// `principal` = giải ngân (tăng gốc); `repayment` = trả (vay) / thu hồi (cho vay).
enum LoanEntryKind { principal, repayment }

/// Một dòng của khoản vay (GET /loans/{id}).
class LoanEntry {
  final String id;
  final LoanEntryKind kind;
  final BigInt amountCents;
  final DateTime? at;

  /// Giao dịch ví đã gắn với dòng này (null = chỉ ghi sổ).
  final String? transactionId;

  /// Giao dịch lãi tách riêng khi trả vượt gốc trong ngưỡng lãi (S1).
  final String? interestTransactionId;

  const LoanEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.at,
    this.transactionId,
    this.interestTransactionId,
  });

  factory LoanEntry.fromJson(Map<String, dynamic> json) => LoanEntry(
        id: json['id'] as String? ?? '',
        kind: json['kind'] == 'principal' ? LoanEntryKind.principal : LoanEntryKind.repayment,
        amountCents: parseCents(json['amountCents']),
        at: DateTime.tryParse(json['at'] as String? ?? ''),
        transactionId: json['transactionId'] as String?,
        interestTransactionId: json['interestTransactionId'] as String?,
      );
}

/// Khoản vay kèm các dòng của nó (GET /loans/{id}).
class LoanDetail {
  final LoanItem loan;
  final List<LoanEntry> entries;

  const LoanDetail({required this.loan, required this.entries});

  factory LoanDetail.fromJson(Map<String, dynamic> json) => LoanDetail(
        loan: LoanItem.fromJson(json['loan'] as Map<String, dynamic>),
        entries: [for (final e in (json['entries'] as List? ?? const [])) LoanEntry.fromJson(e as Map<String, dynamic>)],
      );
}

final loansRepositoryProvider = Provider<LoansRepository>(
  (ref) => LoansRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Khoản vay của người dùng hiện tại; chưa đăng nhập thì rỗng và không gọi API.
final loansProvider = FutureProvider.autoDispose<List<LoanItem>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <LoanItem>[];
  return ref.watch(loansRepositoryProvider).getLoans();
});

/// Tổng hợp sổ vay cho thẻ đầu màn. Chỉ là thông tin phụ: lỗi cho ra `null`, màn hình dùng số cộng từ danh sách thay vì báo lỗi.
final loansSummaryProvider = FutureProvider.autoDispose<LoanSummary?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  try {
    return await ref.watch(loansRepositoryProvider).getSummary();
  } on Object {
    return null;
  }
});

/// Chi tiết một khoản (kèm các dòng). Lỗi được ném ra để màn chi tiết hiện thông báo và nút Thử lại.
final loanDetailProvider = FutureProvider.autoDispose.family<LoanDetail, String>((ref, id) {
  return ref.watch(loansRepositoryProvider).getDetail(id);
});

class LoansRepository {
  final ApiClient apiClient;

  LoansRepository({required this.apiClient});

  Future<List<LoanItem>> getLoans() async {
    final res = await apiClient.get(
      '/api/v1/loans',
      fromJsonT: (json) => (json as List).map((e) => LoanItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return res.data ?? const [];
  }

  Future<LoanItem> createLoan({
    required LoanType type,
    required String title,
    required String counterparty,
    required BigInt principalCents,
    double interestRateYear = 0,
    DateTime? dueDate,
    DateTime? startDate,
  }) async {
    final res = await apiClient.post(
      '/api/v1/loans',
      data: _body(type, title, counterparty, principalCents, interestRateYear, dueDate, startDate),
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// Sửa khoản vay (PUT /loans/{id}). Gửi đủ các trường; [startDate] null = giữ nguyên ngày bắt đầu.
  Future<LoanItem> updateLoan({
    required String id,
    required LoanType type,
    required String title,
    required String counterparty,
    required BigInt principalCents,
    double interestRateYear = 0,
    DateTime? dueDate,
    DateTime? startDate,
  }) async {
    final res = await apiClient.put(
      '/api/v1/loans/$id',
      data: _body(type, title, counterparty, principalCents, interestRateYear, dueDate, startDate),
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _body(LoanType type, String title, String counterparty, BigInt principal, double rate, DateTime? due, DateTime? start) => {
        'direction': type.name,
        'title': title,
        'counterparty': counterparty,
        'principalCents': principal.toInt(),
        'interestRatePercentYear': rate,
        if (due != null) 'dueDate': _date(due),
        if (start != null) 'startDate': _date(start),
      };

  /// Ghi một lần trả (vay) / thu hồi (cho vay). Có [financialAccountId] thì server ghi giao dịch ví tương ứng.
  Future<LoanItem> repay({required String loanId, required BigInt amountCents, String? financialAccountId}) async {
    final res = await apiClient.post(
      '/api/v1/loans/$loanId/repayments',
      data: {'amountCents': amountCents.toInt(), if (financialAccountId != null) 'financialAccountId': financialAccountId},
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> deleteLoan(String id) => apiClient.delete('/api/v1/loans/$id');

  Future<LoanSummary> getSummary() async {
    final res = await apiClient.get(
      '/api/v1/loans/summary',
      fromJsonT: (json) => LoanSummary.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<LoanDetail> getDetail(String id) async {
    final res = await apiClient.get(
      '/api/v1/loans/$id',
      fromJsonT: (json) => LoanDetail.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// Cho mượn thêm / vay thêm (POST /loans/{id}/principal), cùng dạng với [repay]. Có [financialAccountId] thì BE ghi giao dịch ví
  /// tương ứng (cho vay = tiền ra, đi vay = tiền vào); không có = chỉ ghi sổ.
  Future<LoanItem> addPrincipal({required String loanId, required BigInt amountCents, String? financialAccountId}) async {
    final res = await apiClient.post(
      '/api/v1/loans/$loanId/principal',
      data: {'amountCents': amountCents.toInt(), if (financialAccountId != null) 'financialAccountId': financialAccountId},
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// Xóa một dòng (DELETE /loans/{id}/entries/{entryId}): chỉ gỡ khỏi sổ, giao dịch ví đã gắn vẫn ở lại.
  /// Trả khoản sau khi xóa; trả `null` (BE 204) khi khoản thành rỗng và bị xóa theo.
  Future<LoanItem?> deleteEntry({required String loanId, required String entryId}) async {
    final res = await apiClient.deleteWithResult(
      '/api/v1/loans/$loanId/entries/$entryId',
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data;
  }

  /// Xóa nợ (POST /loans/{id}/write-off): khoản đóng là `written_off`, không tạo giao dịch và không đổi số dư ví.
  Future<LoanItem> writeOff(String loanId) async {
    final res = await apiClient.post(
      '/api/v1/loans/$loanId/write-off',
      fromJsonT: (json) => LoanItem.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }
}
