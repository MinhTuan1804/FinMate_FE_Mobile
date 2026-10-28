import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Ghi một bản nháp thành giao dịch theo kiểu offline-first (ở máy trước, gửi server hoặc xếp hàng đồng bộ). Dùng cho "ghi ngay" của chat
/// local-first và cho nút "Lưu tất cả" của thẻ gộp. [clientRequestId] chống trùng khi gửi lại.
/// Một khoản của thẻ gộp, đã có mã danh mục và ví để ghi
class DraftSave {
  final DraftTransaction draft;
  final String categoryId;
  final String accountId;
  final String requestId;

  const DraftSave(this.draft, this.categoryId, this.accountId, this.requestId);
}

class DraftSaver {
  /// Mã danh mục (UUID của server) cho một slug, null nếu chưa tải được danh mục
  final String? Function(String slug) categoryIdOf;
  final Future<TransactionEntity> Function(DraftTransaction draft, {required String categoryId, required String accountId, required String clientRequestId}) save;

  /// Ghi cả nhóm ở máy trong MỘT lần (được tất cả hoặc không gì), không đụng mạng
  final Future<void> Function(List<DraftSave> items) saveAll;

  /// Đẩy hàng đợi đồng bộ lên server; gọi ngầm sau khi ghi ở máy
  final Future<void> Function() syncNow;

  const DraftSaver({required this.categoryIdOf, required this.save, required this.saveAll, required this.syncNow});

  factory DraftSaver.fromRef(Ref ref) {
    final transactions = ref.read(transactionRepositoryProvider);
    final sync = ref.read(syncServiceProvider);
    return DraftSaver(
      categoryIdOf: (slug) => (ref.read(categoriesProvider).valueOrNull ?? const []).where((c) => c.slug == slug).firstOrNull?.id,
      save: (draft, {required categoryId, required accountId, required clientRequestId}) => transactions.createTransaction(
        accountId: accountId,
        categoryId: categoryId,
        amountCents: draft.amountCents!,
        type: draft.type!,
        merchantName: draft.merchantName,
        description: draft.description ?? '',
        date: draft.transactedAt ?? DateTime.now(),
        source: draft.source.apiValue,
        clientRequestId: clientRequestId,
      ),
      saveAll: (items) => transactions.createTransactionsLocally([
        for (final i in items)
          NewTransaction(
            accountId: i.accountId,
            categoryId: i.categoryId,
            amountCents: i.draft.amountCents!,
            type: i.draft.type!,
            merchantName: i.draft.merchantName,
            description: i.draft.description ?? '',
            date: i.draft.transactedAt ?? DateTime.now(),
            source: i.draft.source.apiValue,
            clientRequestId: i.requestId,
          ),
      ]),
      syncNow: () async {
        await sync.processQueue();
      },
    );
  }
}
