import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/database/sync_service.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/transactions/data/transaction_repository.dart';
import 'package:finmate/features/transactions/presentation/controllers/data_refresh.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_page.dart';

/// Tạo lại (và tải lại) khi đổi người dùng; chưa đăng nhập thì rỗng và không gọi API
final transactionControllerProvider =
    StateNotifierProvider<TransactionController, AsyncValue<List<TransactionEntity>>>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  return TransactionController(
    repository: ref.watch(transactionRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
    enabled: signedIn,
    onDataChanged: () => refreshDerivedData(ref),
  );
});

class TransactionController extends StateNotifier<AsyncValue<List<TransactionEntity>>> {
  final TransactionRepository repository;
  final SyncService syncService;

  /// Gọi sau khi dữ liệu ghi thành công (tạo/chuyển/xác nhận giao dịch, hoặc đồng bộ được hàng đợi offline)
  final VoidCallback? onDataChanged;

  TransactionType? _filter;
  bool _draftsOnly = false;
  String? _cursor;
  bool _loadingMore = false;
  int _gen = 0;

  TransactionController({required this.repository, required this.syncService, bool enabled = true, this.onDataChanged})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) loadTransactions();
  }

  /// Bộ lọc loại giao dịch đang áp dụng (null = tất cả)
  TransactionType? get filter => _filter;

  /// Đang xem danh sách nháp (chưa xác nhận); khi đó bộ lọc loại bị bỏ qua
  bool get draftsOnly => _draftsOnly;

  /// Còn trang tiếp theo trên server
  bool get hasMore => _cursor != null;

  /// Tải trang đầu; trước đó thử đồng bộ hàng đợi offline (lỗi đồng bộ không chặn việc tải)
  Future<void> loadTransactions() async {
    state = const AsyncValue.loading();
    // Chế độ/bộ lọc chốt ngay đây: tải chậm của chế độ cũ không được ghi đè kết quả của chế độ mới.
    final gen = ++_gen;
    final draftsOnly = _draftsOnly;
    final filter = _filter;
    try {
      var synced = 0;
      try {
        synced = await syncService.processQueue();
      } catch (_) {}
      final page = await _fetch(draftsOnly, filter);
      if (!mounted) return;
      if (synced > 0) onDataChanged?.call();
      if (gen != _gen) return;
      _cursor = page.nextCursor;
      state = AsyncValue.data(page.items);
    } catch (e, st) {
      if (mounted && gen == _gen) state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    final current = state.value;
    if (cursor == null || current == null || _loadingMore) return;

    final gen = _gen;
    _loadingMore = true;
    try {
      final page = await _fetch(_draftsOnly, _filter, cursor: cursor);
      if (!mounted || gen != _gen) return;
      _cursor = page.nextCursor;
      state = AsyncValue.data([...current, ...page.items]);
    } catch (_) {
      // Giữ nguyên danh sách hiện có; người dùng có thể cuộn để thử lại
    } finally {
      _loadingMore = false;
    }
  }

  Future<TransactionPage> _fetch(bool draftsOnly, TransactionType? filter, {String? cursor}) => repository.getTransactions(
        type: draftsOnly ? null : filter,
        cursor: cursor,
        status: draftsOnly ? TransactionStatus.draft : TransactionStatus.confirmed,
      );

  /// Chế độ nháp là trạng thái dùng chung của provider: màn nháp phải gọi `setDraftsOnly(false)` khi rời đi.
  Future<void> setDraftsOnly(bool value) {
    _draftsOnly = value;
    _cursor = null;
    return loadTransactions();
  }

  Future<void> setFilter(TransactionType? type) {
    _filter = type;
    _cursor = null;
    return loadTransactions();
  }

  void _prepend(TransactionEntity tx) {
    if (mounted && !_draftsOnly && (_filter == null || tx.type == _filter)) {
      // Lưu lại (server trả 200 bản đã có) không được hiện hai dòng cùng một giao dịch.
      state = AsyncValue.data([tx, ...(state.value ?? const []).where((t) => t.id != tx.id)]);
    }
    if (mounted) onDataChanged?.call();
  }

  Future<void> createTransaction({
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    String? merchantName,
    String description = '',
    required DateTime date,
    String source = 'Manual',
    String? receiptScanId,
    String? receiptGroup,
    String? clientRequestId,
  }) async {
    final tx = await repository.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amountCents: amountCents,
      type: type,
      merchantName: merchantName,
      description: description,
      date: date,
      source: source,
      receiptScanId: receiptScanId,
      receiptGroup: receiptGroup,
      clientRequestId: clientRequestId,
    );
    _prepend(tx);
  }

  /// Xác nhận nháp: gỡ khỏi danh sách nháp rồi báo dữ liệu đổi (số dư/báo cáo thay đổi).
  Future<void> confirmDraft(String id, {String? categoryId}) async {
    await repository.confirmDraft(id, categoryId: categoryId);
    if (!mounted) return;
    state = AsyncValue.data((state.value ?? const <TransactionEntity>[]).where((t) => t.id != id).toList());
    onDataChanged?.call();
  }

  Future<void> saveDraft({
    required String id,
    required String accountId,
    String? categoryId,
    required BigInt amountCents,
    required TransactionType type,
    required DateTime date,
    String? merchantName,
    String description = '',
  }) async {
    final saved = await repository.updateDraft(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      amountCents: amountCents,
      type: type,
      date: date,
      merchantName: merchantName,
      description: description,
    );
    if (!mounted) return;
    state = AsyncValue.data([for (final t in state.value ?? const <TransactionEntity>[]) t.id == id ? saved : t]);
  }

  Future<void> transferInternal({
    required BigInt amountCents,
    required String fromAccountId,
    required String toAccountId,
    String description = '',
    required DateTime date,
  }) async {
    final tx = await repository.transferInternal(
      amountCents: amountCents,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      description: description,
      date: date,
    );
    _prepend(tx);
  }
}
