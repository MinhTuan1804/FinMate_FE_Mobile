import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';

final qrTransferRepositoryProvider = Provider<QrTransferRepository>(
  (ref) => QrTransferRepository(apiClient: ref.watch(apiClientProvider)),
);

class QrTransferRepository {
  final ApiClient apiClient;

  static const _path = '/api/v1/qr';

  QrTransferRepository({required this.apiClient});

  /// Danh sách ngân hàng quét/mở app được, kèm việc FinMate có đọc được thông báo (tự khớp) của nó không.
  Future<List<QrBankEntity>> getBanks() async {
    final response = await apiClient.get(
      '$_path/banks',
      fromJsonT: (json) => (json as List).map((e) => QrBankEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Tạo ý định chuyển tiền NGAY TRƯỚC khi mở app ngân hàng. [categoryId] null = dùng danh mục đã nhớ
  /// cho người nhận này nếu có, không có nữa thì để AI đoán như thường lúc khớp thông báo thật.
  Future<QrTransferEntity> createTransfer({
    required String receiverBankBin,
    required String receiverAccountNumber,
    String? receiverName,
    required String senderBankBin,
    required BigInt amountCents,
    String? message,
    String? categoryId,
  }) async {
    final response = await apiClient.post(
      '$_path/transfers',
      data: {
        'receiverBankBin': receiverBankBin,
        'receiverAccountNumber': receiverAccountNumber,
        'receiverName': receiverName,
        'senderBankBin': senderBankBin,
        'amountCents': amountCents.toInt(),
        'message': message,
        'categoryId': categoryId,
      },
      fromJsonT: (json) => QrTransferEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// [status] null = tất cả trạng thái. Mặc định 50 bản ghi gần nhất.
  Future<List<QrTransferEntity>> listTransfers({String? status, int limit = 50}) async {
    final response = await apiClient.get(
      '$_path/transfers',
      queryParameters: {if (status != null) 'status': status, 'limit': limit},
      fromJsonT: (json) => (json as List).map((e) => QrTransferEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Hủy một lần quét còn chờ (quét nhầm, hoặc không mở được app ngân hàng). Đã khớp giao dịch thật thì BE trả 409.
  Future<QrTransferEntity> cancelTransfer(String id) async {
    final response = await apiClient.post(
      '$_path/transfers/$id/cancel',
      fromJsonT: (json) => QrTransferEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Danh mục đã nhớ cho người nhận này, hoặc null nếu chưa có (trạng thái bình thường, không phải lỗi).
  Future<CounterpartyOverrideEntity?> lookupCounterparty({required String bankBin, required String accountNumber}) async {
    final response = await apiClient.post(
      '$_path/counterparties/lookup',
      data: {'bankBin': bankBin, 'accountNumber': accountNumber},
      fromJsonT: (json) => json == null ? null : CounterpartyOverrideEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<List<CounterpartyOverrideEntity>> listCounterparties() async {
    final response = await apiClient.get(
      '$_path/counterparties',
      fromJsonT: (json) => (json as List).map((e) => CounterpartyOverrideEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Đổi danh mục đã nhớ cho một người nhận, không cần quét lại QR.
  Future<CounterpartyOverrideEntity> updateCounterparty(String id, String categoryId) async {
    final response = await apiClient.patch(
      '$_path/counterparties/$id',
      data: {'categoryId': categoryId},
      fromJsonT: (json) => CounterpartyOverrideEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xóa hẳn mapping; lần quét sau với người nhận này sẽ hỏi lại "Chọn danh mục"/"Bỏ qua" như chưa từng có.
  Future<void> deleteCounterparty(String id) async {
    await apiClient.delete('$_path/counterparties/$id');
  }
}
