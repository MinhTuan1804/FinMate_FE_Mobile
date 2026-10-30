/// Ngân hàng quét/mở app được (GET /qr/banks). `canMatchNotifications`: FinMate đọc được thông báo của ngân hàng này, nên chọn nó làm ngân hàng GỬI thì giao dịch sau đó tự khớp với lần quét.
class QrBank {
  const QrBank({required this.bin, required this.name, required this.appCode, required this.canMatchNotifications});

  final String bin;
  final String name;
  final String appCode;
  final bool canMatchNotifications;

  factory QrBank.fromJson(Map<String, dynamic> json) => QrBank(
        bin: json['bin'] as String,
        name: json['name'] as String? ?? json['bin'] as String,
        appCode: json['appCode'] as String? ?? '',
        canMatchNotifications: json['canMatchNotifications'] as bool? ?? false,
      );
}

enum QrTransferStatus {
  pending,
  matched,
  cancelled;

  static QrTransferStatus parse(String? value) => switch (value?.toLowerCase()) {
        'matched' => matched,
        'cancelled' => cancelled,
        _ => pending,
      };
}

/// Một lần quét QR chuyển khoản (POST/GET /qr/transfers). Không phải giao dịch: chỉ là ý định, khớp với thông báo ngân hàng thật sau đó.
class QrTransfer {
  const QrTransfer({
    required this.id,
    required this.receiverBankName,
    required this.receiverAccountNumber,
    required this.receiverName,
    required this.senderBankName,
    required this.amount,
    required this.message,
    required this.categoryName,
    required this.status,
    required this.isExpired,
    required this.scannedAt,
  });

  final String id;
  final String receiverBankName;
  final String receiverAccountNumber;
  final String? receiverName;
  final String senderBankName;

  /// Đồng nguyên (VND không có số lẻ).
  final int amount;
  final String? message;
  final String? categoryName;
  final QrTransferStatus status;

  /// Đang chờ nhưng quá hạn: gần như chắc chắn không bao giờ khớp.
  final bool isExpired;
  final DateTime scannedAt;

  factory QrTransfer.fromJson(Map<String, dynamic> json) => QrTransfer(
        id: json['id'] as String,
        receiverBankName: json['receiverBankName'] as String? ?? '',
        receiverAccountNumber: json['receiverAccountNumber'] as String? ?? '',
        receiverName: json['receiverName'] as String?,
        senderBankName: json['senderBankName'] as String? ?? '',
        amount: (json['amountCents'] as num).toInt(),
        message: json['message'] as String?,
        categoryName: json['categoryName'] as String?,
        status: QrTransferStatus.parse(json['status'] as String?),
        isExpired: json['isExpired'] as bool? ?? false,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );
}

/// Danh mục đã nhớ cho một người nhận (ngân hàng + số tài khoản).
class CounterpartyOverride {
  const CounterpartyOverride({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.displayName,
    required this.categoryId,
    required this.categoryName,
  });

  final String id;
  final String bankName;
  final String accountNumber;
  final String? displayName;
  final String categoryId;
  final String categoryName;

  factory CounterpartyOverride.fromJson(Map<String, dynamic> json) => CounterpartyOverride(
        id: json['id'] as String,
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        displayName: json['displayName'] as String?,
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String? ?? '',
      );
}
