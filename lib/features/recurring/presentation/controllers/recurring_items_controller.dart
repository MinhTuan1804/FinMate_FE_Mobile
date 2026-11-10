import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';

/// Tự tạo lại (và tải lại) khi đổi người dùng; chưa đăng nhập thì rỗng và không gọi API
final recurringItemsControllerProvider =
    StateNotifierProvider<RecurringItemsController, AsyncValue<List<RecurringItemEntity>>>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  return RecurringItemsController(repository: ref.watch(recurringItemsRepositoryProvider), enabled: signedIn);
});

class RecurringItemsController extends StateNotifier<AsyncValue<List<RecurringItemEntity>>> {
  final RecurringItemsRepository repository;

  RecurringItemsController({required this.repository, bool enabled = true})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      // Không truyền status: lấy mọi khoản trừ đã hủy/đã từ chối, để màn hình gộp suggested/active/paused.
      final list = await repository.getItems();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Lỗi được ném lại cho màn hình; thành công thì tải lại danh sách
  Future<RecurringItemEntity> create({
    required RecurringDirection direction,
    required String name,
    String? counterpartyName,
    required BigInt amountCents,
    required RecurringCadence cadence,
    required DateTime nextDueDate,
    String? categoryId,
    String? financialAccountId,
  }) async {
    final created = await repository.createItem(
      direction: direction,
      name: name,
      counterpartyName: counterpartyName,
      amountCents: amountCents,
      cadence: cadence,
      nextDueDate: nextDueDate,
      categoryId: categoryId,
      financialAccountId: financialAccountId,
    );
    await load();
    return created;
  }

  Future<void> update({
    required String id,
    String? name,
    BigInt? amountCents,
    RecurringCadence? cadence,
    DateTime? nextDueDate,
    String? categoryId,
    String? financialAccountId,
  }) async {
    await repository.updateItem(
      id: id,
      name: name,
      amountCents: amountCents,
      cadence: cadence,
      nextDueDate: nextDueDate,
      categoryId: categoryId,
      financialAccountId: financialAccountId,
    );
    await load();
  }

  Future<void> confirm(String id) async {
    await repository.confirm(id);
    await load();
  }

  Future<void> reject(String id) async {
    await repository.reject(id);
    await load();
  }

  Future<void> pause(String id) async {
    await repository.pause(id);
    await load();
  }

  Future<void> resume(String id) async {
    await repository.resume(id);
    await load();
  }

  Future<void> cancel(String id) async {
    await repository.cancel(id);
    await load();
  }
}
