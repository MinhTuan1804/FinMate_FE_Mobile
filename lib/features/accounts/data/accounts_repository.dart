import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(apiClient: ref.watch(apiClientProvider)),
);

class AccountsRepository {
  final ApiClient apiClient;

  AccountsRepository({required this.apiClient});

  Future<List<FinancialAccount>> getAccounts() async {
    final response = await apiClient.get(
      '/api/v1/financial-accounts',
      fromJsonT: (json) => (json as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<List<AccountProviderInfo>> getProviders() async {
    final response = await apiClient.get(
      '/api/v1/financial-accounts/providers',
      fromJsonT: (json) => (json as List).map((e) => AccountProviderInfo.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<FinancialAccount> createAccount({
    required String name,
    required AccountType type,
    String? providerConfigId,
    BigInt? initialBalanceCents,
  }) async {
    final response = await apiClient.post(
      '/api/v1/financial-accounts',
      data: {
        'accountName': name,
        'accountType': type.apiValue,
        if (providerConfigId != null) 'providerConfigId': providerConfigId,
        'initialBalanceCents': (initialBalanceCents ?? BigInt.zero).toInt(),
      },
      fromJsonT: (json) => FinancialAccount.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Đổi tên tài khoản/ví (PATCH /financial-accounts/{id})
  Future<FinancialAccount> updateAccount({required String id, required String name}) async {
    final response = await apiClient.patch(
      '/api/v1/financial-accounts/$id',
      data: {'accountName': name},
      fromJsonT: (json) => FinancialAccount.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Bật/tắt theo dõi tự động (PATCH /financial-accounts/{id}/monitoring)
  Future<FinancialAccount> toggleMonitoring({required String id, required bool isMonitored}) async {
    final response = await apiClient.patch(
      '/api/v1/financial-accounts/$id/monitoring',
      data: {'isMonitored': isMonitored},
      fromJsonT: (json) => FinancialAccount.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Số dư hiện tại (GET /financial-accounts/{id}/balance)
  Future<AccountBalance> getBalance(String id) async {
    final response = await apiClient.get(
      '/api/v1/financial-accounts/$id/balance',
      fromJsonT: (json) => AccountBalance.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Xóa tài khoản/ví (DELETE /financial-accounts/{id})
  Future<void> deleteAccount(String id) => apiClient.delete('/api/v1/financial-accounts/$id');
}
