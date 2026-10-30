import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';

final qrTransferRepositoryProvider = Provider<QrTransferRepository>(
  (ref) => QrTransferRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Gọi API quét QR chuyển khoản của backend (`/api/v1/qr/*`). Số tài khoản người nhận chỉ đi trong body, không đưa lên URL.
class QrTransferRepository {
  QrTransferRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<QrBank>> getBanks() async {
    final response = await apiClient.get(
      '/api/v1/qr/banks',
      fromJsonT: (json) => (json as List).map((e) => QrBank.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<QrTransfer> createTransfer({
    required String receiverBankBin,
    required String receiverAccountNumber,
    String? receiverName,
    required String senderBankBin,
    required int amount,
    String? message,
    String? categoryId,
  }) async {
    final response = await apiClient.post(
      '/api/v1/qr/transfers',
      data: {
        'receiverBankBin': receiverBankBin,
        'receiverAccountNumber': receiverAccountNumber,
        'receiverName': receiverName,
        'senderBankBin': senderBankBin,
        'amountCents': amount,
        'message': message,
        'categoryId': categoryId,
      },
      fromJsonT: (json) => QrTransfer.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<List<QrTransfer>> getTransfers() async {
    final response = await apiClient.get(
      '/api/v1/qr/transfers',
      fromJsonT: (json) => (json as List).map((e) => QrTransfer.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<void> cancelTransfer(String id) async {
    await apiClient.post('/api/v1/qr/transfers/$id/cancel', fromJsonT: (json) => json);
  }

  /// Danh mục đã nhớ cho người nhận này, hoặc null nếu chưa có (không phải lỗi).
  Future<CounterpartyOverride?> lookupOverride({required String bankBin, required String accountNumber}) async {
    final response = await apiClient.post(
      '/api/v1/qr/counterparties/lookup',
      data: {'bankBin': bankBin, 'accountNumber': accountNumber},
      fromJsonT: (json) => json == null ? null : CounterpartyOverride.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<List<CounterpartyOverride>> getOverrides() async {
    final response = await apiClient.get(
      '/api/v1/qr/counterparties',
      fromJsonT: (json) => (json as List).map((e) => CounterpartyOverride.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<void> updateOverrideCategory(String id, String categoryId) async {
    await apiClient.patch('/api/v1/qr/counterparties/$id', data: {'categoryId': categoryId}, fromJsonT: (json) => json);
  }

  Future<void> deleteOverride(String id) => apiClient.delete('/api/v1/qr/counterparties/$id');
}
