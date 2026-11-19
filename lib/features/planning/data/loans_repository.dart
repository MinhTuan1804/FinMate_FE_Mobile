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
  });

  BigInt get totalDueCents => remainingCents + (accruedInterestCents ?? BigInt.zero);

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
}
