import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/qr_transfers/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';

/// Danh sách ngân hàng quét/mở app được (ít đổi, tải một lần).
final qrBanksProvider = FutureProvider.autoDispose<List<QrBankEntity>>(
  (ref) => ref.watch(qrTransferRepositoryProvider).getBanks(),
);

/// Danh sách ý định chuyển tiền qua QR, lọc theo trạng thái (null = tất cả).
class QrTransfersController extends StateNotifier<AsyncValue<List<QrTransferEntity>>> {
  final QrTransferRepository repository;
  String? status;

  QrTransfersController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.listTransfers(status: status));
  }

  Future<void> setStatusFilter(String? value) async {
    if (status == value) return;
    status = value;
    await load();
  }

  /// Hủy một lần quét còn chờ. Lỗi (ví dụ đã khớp giao dịch thật, BE trả 409) được ném lại cho màn hình.
  Future<void> cancel(String id) async {
    final updated = await repository.cancelTransfer(id);
    if (!mounted) return;
    state = AsyncValue.data([for (final t in state.value ?? const <QrTransferEntity>[]) t.id == id ? updated : t]);
  }
}

final qrTransfersControllerProvider = StateNotifierProvider.autoDispose<QrTransfersController, AsyncValue<List<QrTransferEntity>>>(
  (ref) => QrTransfersController(ref.watch(qrTransferRepositoryProvider)),
);

/// Danh sách danh mục đã nhớ cho từng người nhận (bankBin + accountNumber).
class CounterpartyOverridesController extends StateNotifier<AsyncValue<List<CounterpartyOverrideEntity>>> {
  final QrTransferRepository repository;

  CounterpartyOverridesController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.listCounterparties());
  }

  Future<void> update(String id, String categoryId) async {
    final updated = await repository.updateCounterparty(id, categoryId);
    if (!mounted) return;
    state = AsyncValue.data([for (final o in state.value ?? const <CounterpartyOverrideEntity>[]) o.id == id ? updated : o]);
  }

  Future<void> delete(String id) async {
    await repository.deleteCounterparty(id);
    if (!mounted) return;
    state = AsyncValue.data([for (final o in state.value ?? const <CounterpartyOverrideEntity>[]) if (o.id != id) o]);
  }
}

final counterpartyOverridesControllerProvider =
    StateNotifierProvider.autoDispose<CounterpartyOverridesController, AsyncValue<List<CounterpartyOverrideEntity>>>(
  (ref) => CounterpartyOverridesController(ref.watch(qrTransferRepositoryProvider)),
);
