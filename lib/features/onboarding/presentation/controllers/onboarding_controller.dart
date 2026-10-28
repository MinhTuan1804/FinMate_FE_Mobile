import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

class OnboardingInput {
  final int monthlyIncomeCents;
  final BigInt cashBalanceCents;
  final List<AccountProviderInfo> selectedProviders;

  /// Ngân sách chi tiêu cả tháng (tùy chọn); null = không đặt
  final BigInt? monthlyBudgetCents;

  const OnboardingInput({
    required this.monthlyIncomeCents,
    required this.cashBalanceCents,
    required this.selectedProviders,
    this.monthlyBudgetCents,
  });
}

final onboardingControllerProvider = Provider<OnboardingController>((ref) {
  return OnboardingController(
    updateIncome: ref.read(authControllerProvider.notifier).updateMonthlyIncome,
    accounts: ref.read(accountsControllerProvider.notifier),
    createTotalBudget: (limit) => ref
        .read(planningControllerProvider.notifier)
        .createOrUpdateBudget(categoryId: null, limitAmountCents: limit),
  );
});

/// Hoàn tất thiết lập ban đầu: lưu thu nhập, tạo ví tiền mặt và các tài khoản được chọn.
/// Có thể chạy lại an toàn (bỏ qua thứ đã tồn tại); lỗi được ném lại cho màn hình.
class OnboardingController {
  final Future<void> Function(int incomeCents) updateIncome;
  final AccountsController accounts;

  /// Tạo (hoặc cập nhật) ngân sách tổng của tháng
  final Future<void> Function(BigInt limitCents) createTotalBudget;

  OnboardingController({required this.updateIncome, required this.accounts, required this.createTotalBudget});

  Future<void> complete(OnboardingInput input) async {
    await updateIncome(input.monthlyIncomeCents);

    await accounts.load();
    var existing = accounts.current;

    if (!existing.any((a) => a.type == AccountType.cash)) {
      await accounts.create(
        name: 'Ví tiền mặt',
        type: AccountType.cash,
        initialBalanceCents: input.cashBalanceCents,
      );
      existing = accounts.current;
    }

    for (final provider in input.selectedProviders) {
      if (existing.any((a) => a.providerName == provider.displayName)) continue;
      await accounts.create(
        name: provider.displayName,
        type: provider.type,
        providerConfigId: provider.id,
      );
      existing = accounts.current;
    }

    final budget = input.monthlyBudgetCents;
    if (budget != null) await createTotalBudget(budget);
  }
}
