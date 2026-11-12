import 'package:finmate/core/format/money.dart';

/// Một ngân hàng quét/mở app được (GET /qr/banks). [canMatchNotifications]: chỉ khi chọn
/// ngân hàng này làm ngân hàng GỬI thì giao dịch sau này mới tự khớp với lần quét.
class QrBankEntity {
  final String bin;
  final String name;
  final String appCode;
  final bool canMatchNotifications;

  const QrBankEntity({required this.bin, required this.name, required this.appCode, required this.canMatchNotifications});

  factory QrBankEntity.fromJson(Map<String, dynamic> json) => QrBankEntity(
        bin: json['bin'] as String,
        name: json['name'] as String,
        appCode: json['appCode'] as String,
        canMatchNotifications: json['canMatchNotifications'] as bool,
      );
}

/// Một ý định chuyển tiền qua QR (quét xong, trước hoặc sau khi mở app ngân hàng).
/// [status]: Pending | Matched | Cancelled (nguyên văn tên enum từ BE, không chuyển chữ thường).
class QrTransferEntity {
  final String id;
  final String receiverBankBin;
  final String receiverBankName;
  final String receiverAccountNumber;
  final String? receiverName;
  final String senderBankBin;
  final String senderBankName;
  final BigInt amountCents;
  final String? message;
  final String? categoryId;
  final String? categoryName;
  final String status;
  /// Đang chờ nhưng đã quá thời gian hết hạn cấu hình kể từ lúc quét: gần như chắc chắn không bao giờ khớp.
  final bool isExpired;
  final DateTime scannedAt;
  final DateTime? matchedAt;
  final String? matchedTransactionId;

  const QrTransferEntity({
    required this.id,
    required this.receiverBankBin,
    required this.receiverBankName,
    required this.receiverAccountNumber,
    this.receiverName,
    required this.senderBankBin,
    required this.senderBankName,
    required this.amountCents,
    this.message,
    this.categoryId,
    this.categoryName,
    required this.status,
    required this.isExpired,
    required this.scannedAt,
    this.matchedAt,
    this.matchedTransactionId,
  });

  bool get isPending => status == 'Pending';
  bool get isMatched => status == 'Matched';
  bool get isCancelled => status == 'Cancelled';
  String get formattedAmount => formatVnd(amountCents);

  factory QrTransferEntity.fromJson(Map<String, dynamic> json) => QrTransferEntity(
        id: json['id'] as String,
        receiverBankBin: json['receiverBankBin'] as String,
        receiverBankName: json['receiverBankName'] as String,
        receiverAccountNumber: json['receiverAccountNumber'] as String,
        receiverName: json['receiverName'] as String?,
        senderBankBin: json['senderBankBin'] as String,
        senderBankName: json['senderBankName'] as String,
        amountCents: parseCents(json['amountCents']),
        message: json['message'] as String?,
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        status: json['status'] as String,
        isExpired: json['isExpired'] as bool,
        scannedAt: DateTime.parse(json['scannedAt'] as String).toLocal(),
        matchedAt: json['matchedAt'] == null ? null : DateTime.parse(json['matchedAt'] as String).toLocal(),
        matchedTransactionId: json['matchedTransactionId'] as String?,
      );
}

/// Danh mục đã nhớ cho một người nhận (bankBin + accountNumber) — tự gắn cho lần quét sau, không hỏi lại.
class CounterpartyOverrideEntity {
  final String id;
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String? displayName;
  final String categoryId;
  final String categoryName;
  final DateTime updatedAt;

  const CounterpartyOverrideEntity({
    required this.id,
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    this.displayName,
    required this.categoryId,
    required this.categoryName,
    required this.updatedAt,
  });

  factory CounterpartyOverrideEntity.fromJson(Map<String, dynamic> json) => CounterpartyOverrideEntity(
        id: json['id'] as String,
        bankBin: json['bankBin'] as String,
        bankName: json['bankName'] as String,
        accountNumber: json['accountNumber'] as String,
        displayName: json['displayName'] as String?,
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}
