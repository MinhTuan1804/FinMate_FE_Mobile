import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/native/widget_refresh_bridge.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Lỗi xảy ra khi TẢI LẠI danh sách sau 1 hành động (đổi tên/bật-tắt theo dõi/xóa) đã thành công ở
/// BE — bọc lỗi gốc để màn hình phân biệt với lỗi của chính hành động đó (hành động đã thành công,
/// chỉ là tải lại danh sách sau đó bị lỗi).
class AccountsReloadFailedException implements Exception {
  final Object cause;
  const AccountsReloadFailedException(this.cause);
  @override
  String toString() => cause.toString();
}

/// Tự tạo lại (và tải lại) khi đổi người dùng; chưa đăng nhập thì rỗng và không gọi API
final accountsControllerProvider =
    StateNotifierProvider<AccountsController, AsyncValue<List<FinancialAccount>>>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  return AccountsController(repository: ref.watch(accountsRepositoryProvider), enabled: signedIn);
});

/// Các ứng dụng có thể theo dõi (dùng ở onboarding)
final accountProvidersProvider = FutureProvider<List<AccountProviderInfo>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <AccountProviderInfo>[];
  return ref.watch(accountsRepositoryProvider).getProviders();
});

class AccountsController extends StateNotifier<AsyncValue<List<FinancialAccount>>> {
  final AccountsRepository repository;

  AccountsController({required this.repository, bool enabled = true})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) load();
  }

  /// Danh sách hiện có (rỗng khi đang tải hoặc lỗi)
  List<FinancialAccount> get current => state.value ?? const [];

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await repository.getAccounts();
      if (mounted) state = AsyncValue.data(list);
      // await (không fire-and-forget nữa): để load() chỉ thật sự "xong" sau khi widget đã nhận
      // dữ liệu mới — caller (refreshDerivedData) cũng await, tránh race lúc thoát app ngay sau khi
      // lưu giao dịch (xem ghi chú ở data_refresh.dart).
      await syncAllWidgets();
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Tải lại sau 1 hành động (đổi tên/bật-tắt theo dõi/xóa) đã thành công ở BE. Khác [load]: nếu
  /// tải lại lỗi thì KHÔNG ghi đè [state] — hành động người dùng yêu cầu đã thành công rồi, lỗi tải
  /// lại không được phép xóa mất danh sách đang hiển thị. Ném lại lỗi bọc trong
  /// [AccountsReloadFailedException] để màn hình tự báo riêng (vd snackbar), không đẩy cả màn vào
  /// trạng thái lỗi toàn màn.
  Future<void> _reloadAfterAction() async {
    try {
      final list = await repository.getAccounts();
      if (mounted) state = AsyncValue.data(list);
      await syncAllWidgets();
    } catch (e, st) {
      // debugPrint TẠM THỜI — để xác nhận nguyên nhân thật (parsing/timeout/race...) nếu lỗi này
      // còn tái diễn, xem trong `flutter logs`/logcat ngay sau khi đổi tên/bật-tắt/xóa 1 tài khoản.
      debugPrint('[AccountsController] reload after action FAILED: $e\n$st');
      throw AccountsReloadFailedException(e);
    }
  }

  /// Lỗi được ném lại cho màn hình; thành công thì tải lại danh sách
  Future<FinancialAccount> create({
    required String name,
    required AccountType type,
    String? providerConfigId,
    BigInt? initialBalanceCents,
  }) async {
    final created = await repository.createAccount(
      name: name,
      type: type,
      providerConfigId: providerConfigId,
      initialBalanceCents: initialBalanceCents,
    );
    await load();
    return created;
  }

  /// Đổi tên; lỗi được ném lại cho màn hình. Thành công thì tải lại danh sách — nếu tải lại lỗi,
  /// xem [_reloadAfterAction] (không xóa mất danh sách vì việc đổi tên đã thành công).
  Future<void> rename(String id, String name) async {
    await repository.updateAccount(id: id, name: name);
    await _reloadAfterAction();
  }

  /// Bật/tắt theo dõi tự động; lỗi được ném lại cho màn hình, thành công thì tải lại danh sách
  /// (xem [_reloadAfterAction]).
  Future<void> setMonitoring(String id, bool isMonitored) async {
    await repository.toggleMonitoring(id: id, isMonitored: isMonitored);
    await _reloadAfterAction();
  }

  /// Số dư hiện tại; lỗi được ném lại cho màn hình
  Future<AccountBalance> getBalance(String id) => repository.getBalance(id);

  /// Xóa tài khoản/ví; lỗi được ném lại cho màn hình, thành công thì tải lại danh sách
  /// (xem [_reloadAfterAction]).
  Future<void> delete(String id) async {
    await repository.deleteAccount(id);
    await _reloadAfterAction();
  }
}
