import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_links.dart';

/// Kết quả xem trước (POST .../merge/preview, .../convert-to-transfer/preview): BE chạy thật rồi hoàn tác, không ghi gì.
class TransactionPreview {
  /// Giao dịch còn lại sau thao tác.
  final TransactionEntity survivor;

  /// Khoản "Phí giao dịch" sẽ được tạo (nếu có).
  final TransactionEntity? fee;
  final List<BalanceChange> balanceChanges;
  final List<String> warnings;

  const TransactionPreview({required this.survivor, required this.fee, required this.balanceChanges, required this.warnings});

  factory TransactionPreview.fromJson(Map<String, dynamic> json) => TransactionPreview(
        survivor: TransactionEntity.fromJson(json['survivor'] as Map<String, dynamic>),
        fee: json['fee'] == null ? null : TransactionEntity.fromJson(json['fee'] as Map<String, dynamic>),
        balanceChanges: [for (final b in (json['balanceChanges'] as List? ?? const [])) BalanceChange.fromJson(b as Map<String, dynamic>)],
        warnings: [for (final w in (json['warnings'] as List? ?? const [])) w as String],
      );
}

/// Kết quả chuyển đổi thành chuyển ví (POST .../convert-to-transfer).
class TransferConversion {
  final TransactionEntity transfer;
  final TransactionEntity? fee;
  final List<String> warnings;

  const TransferConversion({required this.transfer, required this.fee, required this.warnings});

  factory TransferConversion.fromJson(Map<String, dynamic> json) => TransferConversion(
        transfer: TransactionEntity.fromJson(json['transfer'] as Map<String, dynamic>),
        fee: json['fee'] == null ? null : TransactionEntity.fromJson(json['fee'] as Map<String, dynamic>),
        warnings: [for (final w in (json['warnings'] as List? ?? const [])) w as String],
      );
}

/// Văn bản biên lai để mở khung chia sẻ của máy (không có link công khai).
class ShareReceipt {
  final String title;
  final String text;

  const ShareReceipt({required this.title, required this.text});

  factory ShareReceipt.fromJson(Map<String, dynamic> json) => ShareReceipt(
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}

final transactionLinksRepositoryProvider = Provider<TransactionLinksRepository>(
  (ref) => TransactionLinksRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Chi tiết một giao dịch từ server, đủ các trường mà danh sách không có (gợi ý trùng, gợi ý chuyển ví, mục tiêu...).
/// Lỗi (mất mạng...) được ném ra: màn chi tiết vẫn dùng bản đã có từ danh sách trong lúc chờ hoặc khi lỗi.
final transactionDetailProvider = FutureProvider.autoDispose.family<TransactionEntity, String>((ref, id) {
  return ref.watch(transactionLinksRepositoryProvider).getDetail(id);
});

/// Các thao tác nhỏ trên một giao dịch đã có: gắn mục tiêu, chia sẻ biên lai, nghi trùng, chuyển ví, hoàn/đảo, quỹ nhóm.
/// Giao dịch của người khác BE trả 404; lỗi nghiệp vụ là 422 kèm mã riêng (hiện nguyên thông điệp của BE).
class TransactionLinksRepository {
  final ApiClient apiClient;

  TransactionLinksRepository({required this.apiClient});

  static const _path = '/api/v1/transactions';

  TransactionEntity _entity(dynamic json) => TransactionEntity.fromJson(json as Map<String, dynamic>);

  Future<TransactionEntity> getDetail(String id) async {
    final res = await apiClient.get('$_path/$id', fromJsonT: _entity);
    return res.data!;
  }

  // ---- mục tiêu và chia sẻ biên lai ----

  /// Gắn giao dịch vào một mục tiêu tiết kiệm (chỉ là nhãn: không đổi số dư hay tiến độ mục tiêu).
  Future<TransactionEntity> attachGoal(String id, String goalId) async {
    final res = await apiClient.put('$_path/$id/goal', data: {'goalId': goalId}, fromJsonT: _entity);
    return res.data!;
  }

  Future<TransactionEntity> detachGoal(String id) async {
    final res = await apiClient.deleteWithResult('$_path/$id/goal', fromJsonT: _entity);
    return res.data!;
  }

  Future<ShareReceipt> shareReceipt(String id) async {
    final res = await apiClient.post('$_path/$id/share-receipt', fromJsonT: (j) => ShareReceipt.fromJson(j as Map<String, dynamic>));
    return res.data!;
  }

  // ---- giao dịch trùng ----

  /// "Không trùng": giữ liên kết ở trạng thái đã bỏ qua để cặp này không bị gợi ý lại.
  Future<TransactionEntity> notDuplicate(String id) async {
    final res = await apiClient.post('$_path/$id/not-duplicate', fromJsonT: _entity);
    return res.data!;
  }

  Map<String, dynamic> _mergeBody(String withTransactionId, String? categoryId, String? clientRequestId) => {
        'withTransactionId': withTransactionId,
        if (categoryId != null) 'categoryId': categoryId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      };

  Future<TransactionPreview> previewMerge(String id, String withTransactionId, {String? categoryId}) async {
    final res = await apiClient.post(
      '$_path/$id/merge/preview',
      data: _mergeBody(withTransactionId, categoryId, null),
      fromJsonT: (j) => TransactionPreview.fromJson(j as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// Gộp hai giao dịch thành một. BE tự chọn bản giữ lại (đã xác nhận trước, rồi bản tạo trước / bản ngân hàng báo) và trả bản đó.
  Future<TransactionEntity> merge(String id, String withTransactionId, {String? categoryId}) async {
    final res = await apiClient.post('$_path/$id/merge', data: _mergeBody(withTransactionId, categoryId, null), fromJsonT: _entity);
    return res.data!;
  }

  // ---- chuyển tiền giữa ví của mình ----

  Map<String, dynamic> _convertBody(String counterAccountId, String? pairedTransactionId, String? clientRequestId) => {
        'counterAccountId': counterAccountId,
        if (pairedTransactionId != null) 'pairedTransactionId': pairedTransactionId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      };

  Future<TransactionPreview> previewConvertToTransfer(String id, String counterAccountId, {String? pairedTransactionId}) async {
    final res = await apiClient.post(
      '$_path/$id/convert-to-transfer/preview',
      data: _convertBody(counterAccountId, pairedTransactionId, null),
      fromJsonT: (j) => TransactionPreview.fromJson(j as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// Đổi khoản chi/thu thành chuyển tiền giữa hai ví. Có [pairedTransactionId] thì ghép hai chiều và phần chênh thành khoản phí.
  /// [clientRequestId] giúp gọi lại cùng thao tác an toàn.
  Future<TransferConversion> convertToTransfer(
    String id,
    String counterAccountId, {
    String? pairedTransactionId,
    String? clientRequestId,
  }) async {
    final res = await apiClient.post(
      '$_path/$id/convert-to-transfer',
      data: _convertBody(counterAccountId, pairedTransactionId, clientRequestId),
      fromJsonT: (j) => TransferConversion.fromJson(j as Map<String, dynamic>),
    );
    return res.data!;
  }

  /// "Không phải chuyển ví": tắt gợi ý cho giao dịch này và chiều đang được gợi ý ghép cùng.
  Future<TransactionEntity> notTransfer(String id) async {
    final res = await apiClient.post('$_path/$id/not-transfer', fromJsonT: _entity);
    return res.data!;
  }

  // ---- khoản định kỳ ----

  /// Tạo khoản định kỳ từ một giao dịch đã xác nhận (POST /recurring-items/from-transaction/{id}): tên (nơi nhận hoặc mô tả),
  /// số tiền, danh mục và ví lấy từ giao dịch. [cadence] null = BE mặc định hằng tháng. Lỗi: 422 khi giao dịch là nháp, chuyển ví
  /// hoặc không có tên lẫn mô tả; 409 khi đã có khoản định kỳ cho người nhận này.
  Future<RecurringItemEntity> createRecurring(String transactionId, {RecurringCadence? cadence}) async {
    final res = await apiClient.post(
      '/api/v1/recurring-items/from-transaction/$transactionId',
      data: cadence == null ? null : {'cadence': cadence.name},
      fromJsonT: (j) => RecurringItemEntity.fromJson(j as Map<String, dynamic>),
    );
    return res.data!;
  }

  // ---- sổ vay (Phase 90) ----

  /// Gắn giao dịch đã xác nhận [transactionId] vào khoản vay làm một lần trả/thu nợ (POST /loans/{id}/repayments với transactionId).
  Future<void> linkToLoan(String loanId, String transactionId) =>
      apiClient.post('/api/v1/loans/$loanId/repayments', data: {'transactionId': transactionId}, fromJsonT: (json) => json);

  /// Xác nhận nháp [id] và gắn luôn vào khoản vay (POST /transactions/{id}/confirm với loanId).
  Future<TransactionEntity> confirmWithLoan(String id, String loanId) async {
    final res = await apiClient.post('$_path/$id/confirm', data: {'loanId': loanId}, fromJsonT: _entity);
    return res.data!;
  }

  // ---- hoàn / đảo ----

  /// Ghi khoản hoàn (hoặc đảo) từ khoản chi gốc [originalId] (POST /transactions/{id}/refunds). BE kiểm số tiền không vượt phần còn hoàn được.
  Future<TransactionEntity> recordRefund(
    String originalId, {
    required BigInt amountCents,
    required DateTime transactedAt,
    required String financialAccountId,
    String relation = 'Refund',
    String? clientRequestId,
  }) async {
    final res = await apiClient.post(
      '$_path/$originalId/refunds',
      data: {
        'amountCents': amountCents.toInt(),
        'transactedAt': transactedAt.toIso8601String(),
        'financialAccountId': financialAccountId,
        'relation': relation,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      },
      fromJsonT: _entity,
    );
    return res.data!;
  }

  /// Liên kết khoản tiền vào [id] làm hoàn/đảo của khoản chi [relatedTransactionId]. [relation] là `Refund` hoặc `Reversal`.
  Future<TransactionEntity> linkRelated(String id, {required String relatedTransactionId, String relation = 'Refund'}) async {
    final res = await apiClient.put(
      '$_path/$id/related',
      data: {'relatedTransactionId': relatedTransactionId, 'relation': relation},
      fromJsonT: _entity,
    );
    return res.data!;
  }

  /// Gỡ liên kết: khoản đó trở lại thành thu nhập thường.
  Future<TransactionEntity> unlinkRelated(String id) async {
    final res = await apiClient.deleteWithResult('$_path/$id/related', fromJsonT: _entity);
    return res.data!;
  }

  // ---- quỹ nhóm ----

  /// Đưa giao dịch về lại khoản chi với danh mục gốc sau khi người quản lý nhóm đã xóa dòng quỹ tạo từ nó.
  Future<TransactionEntity> restoreFromFund(String id) async {
    final res = await apiClient.post('$_path/$id/restore-from-fund', fromJsonT: _entity);
    return res.data!;
  }
}
