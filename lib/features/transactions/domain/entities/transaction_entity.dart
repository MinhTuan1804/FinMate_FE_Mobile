import 'package:finmate/core/format/money.dart';

enum TransactionType {
  income('Credit'),
  expense('Debit'),
  transfer('Transfer');

  /// Giá trị backend dùng (transactionType)
  final String apiValue;
  const TransactionType(this.apiValue);

  /// Chấp nhận cả giá trị backend (Credit/Debit/Transfer) và tên cũ (income/expense)
  static TransactionType fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'credit':
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'debit':
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }
}

enum TransactionStatus { draft, confirmed }

class TransactionEntity {
  final String id;
  final BigInt amountCents;
  final TransactionType type;
  final String? categoryId;
  final String? categoryName;
  final String? merchantName;
  final String description;
  final DateTime date;
  final String accountId;
  final String? toAccountId;
  final TransactionStatus status;
  final bool isSynced;
  final String? clientRequestId;
  final BigInt? balanceAfterCents;

  /// Nguồn ghi nhận khi gửi lên server: Manual | Voice | Receipt | Notification
  final String source;

  /// Mã lần quét hóa đơn (chỉ khi source == Receipt); gửi lên BE để nối bản ghi quét với giao dịch
  final String? receiptScanId;

  /// Nhóm của hóa đơn đã tách (slug gốc hoặc "unknown"); một giao dịch cho mỗi nhóm
  final String? receiptGroup;

  const TransactionEntity({
    required this.id,
    required this.amountCents,
    required this.type,
    this.categoryId,
    this.categoryName,
    this.merchantName,
    this.description = '',
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.status = TransactionStatus.confirmed,
    this.isSynced = true,
    this.clientRequestId,
    this.balanceAfterCents,
    this.source = 'Manual',
    this.receiptScanId,
    this.receiptGroup,
  });

  /// Factory cho chuyển khoản nội bộ giữa 2 tài khoản (BR-26, BR-27)
  /// Theo quy tắc kế toán: không được gán category chi tiêu/thu nhập
  factory TransactionEntity.internalTransfer({
    required String id,
    required BigInt amountCents,
    required String fromAccountId,
    required String toAccountId,
    String description = '',
    required DateTime date,
    bool isSynced = true,
    String? clientRequestId,
  }) {
    return TransactionEntity(
      id: id,
      amountCents: amountCents,
      type: TransactionType.transfer,
      description: description,
      date: date,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      isSynced: isSynced,
      clientRequestId: clientRequestId,
    );
  }

  bool get isInternalTransfer => type == TransactionType.transfer;

  /// Định dạng tiền tệ VND chuẩn vi-VN: ví dụ 150.000 ₫
  String get formattedAmount => formatVnd(amountCents);

  /// Body gửi lên backend: POST /transactions hoặc POST /transactions/transfer
  Map<String, dynamic> toRequestJson() {
    if (isInternalTransfer) {
      return {
        'fromAccountId': accountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents.toInt(),
        'transactedAt': date.toUtc().toIso8601String(),
        if (description.isNotEmpty) 'description': description,
        'clientRequestId': clientRequestId,
      };
    }
    return {
      'financialAccountId': accountId,
      if (categoryId != null) 'categoryId': categoryId,
      'amountCents': amountCents.toInt(),
      'transactionType': type.apiValue,
      'transactedAt': date.toUtc().toIso8601String(),
      if (merchantName != null) 'merchantName': merchantName,
      if (description.isNotEmpty) 'description': description,
      'clientRequestId': clientRequestId,
      'source': source,
      if (receiptScanId != null) 'receiptScanId': receiptScanId,
      if (receiptGroup != null) 'receiptGroup': receiptGroup,
    };
  }

  /// Đọc một giao dịch từ response của backend
  factory TransactionEntity.fromJson(Map<String, dynamic> json) {
    return TransactionEntity(
      id: json['id'] as String,
      amountCents: parseCents(json['amountCents']),
      type: TransactionType.fromApi(json['transactionType'] as String?),
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      merchantName: json['merchantName'] as String?,
      description: json['description'] as String? ?? '',
      date: DateTime.parse(json['transactedAt'] as String).toLocal(),
      accountId: json['financialAccountId'] as String? ?? '',
      toAccountId: json['counterAccountId'] as String?,
      status: (json['status'] as String?)?.toLowerCase() == 'draft' ? TransactionStatus.draft : TransactionStatus.confirmed,
      balanceAfterCents: json['balanceAfterCents'] == null ? null : parseCents(json['balanceAfterCents']),
      source: json['source'] as String? ?? 'Manual',
    );
  }

  TransactionEntity copyWith({
    String? id,
    BigInt? amountCents,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    String? merchantName,
    String? description,
    DateTime? date,
    String? accountId,
    String? toAccountId,
    TransactionStatus? status,
    bool? isSynced,
    String? clientRequestId,
    BigInt? balanceAfterCents,
    String? source,
    String? receiptScanId,
    String? receiptGroup,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      balanceAfterCents: balanceAfterCents ?? this.balanceAfterCents,
      source: source ?? this.source,
      receiptScanId: receiptScanId ?? this.receiptScanId,
      receiptGroup: receiptGroup ?? this.receiptGroup,
    );
  }
}
