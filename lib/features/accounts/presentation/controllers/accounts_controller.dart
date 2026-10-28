import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

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
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
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
}
