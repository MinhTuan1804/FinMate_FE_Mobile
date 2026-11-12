import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/onboarding/presentation/controllers/onboarding_controller.dart';

class InitialSetupScreen extends ConsumerStatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  ConsumerState<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends ConsumerState<InitialSetupScreen> {
  int _currentStep = 0;

  // Step 2: các ứng dụng theo dõi được chọn (BR-07), lấy từ backend
  final Set<String> _selectedProviderIds = {};

  // Step 3: Thu nhập & số dư ví tiền mặt (BR-08, BR-45)
  final _incomeController = TextEditingController();
  final _cashController = TextEditingController(text: '0');
  final _budgetController = TextEditingController();

  @override
  void dispose() {
    _incomeController.dispose();
    _cashController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _completeSetup() async {
    if (_isSaving) return;
    final income = parseAmountInput(_incomeController.text);
    if (income == null) {
      _showError('Vui lòng nhập thu nhập hàng tháng hợp lệ.');
      return;
    }
    final cash = _cashController.text.trim().isEmpty
        ? BigInt.zero
        : parseAmountInput(_cashController.text, allowZero: true);
    if (cash == null) {
      _showError('Số dư ví tiền mặt không hợp lệ.');
      return;
    }

    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : parseAmountInput(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      _showError('Ngân sách tháng không hợp lệ.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final providers = ref.read(accountProvidersProvider).valueOrNull ??
          const <AccountProviderInfo>[];
      await ref.read(onboardingControllerProvider).complete(
            OnboardingInput(
              monthlyIncomeCents: income.toInt(),
              cashBalanceCents: cash,
              selectedProviders: providers
                  .where((p) => _selectedProviderIds.contains(p.id))
                  .toList(),
            ),
          );
      if (mounted) context.go('/finance-survey?onboarding=1');
    } catch (e) {
      if (mounted) _showError(errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thiết lập ban đầu (${_currentStep + 1}/3)',
          style: AppTypography.h3(context),
        ),
        actions: [
          if (_currentStep < 2)
            TextButton(
              onPressed: () {
                setState(() => _currentStep++);
              },
              child: Text(
                'Bỏ qua',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Liquid Glass Capsule Progress Bar
                LiquidGlassProgressBar(
                  value: (_currentStep + 1) / 3,
                  height: 7,
                ),
                const SizedBox(height: 28),

                Expanded(child: _buildCurrentStep(context)),

                // Bottom Navigation Button
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_currentStep < 2) {
                            setState(() => _currentStep++);
                          } else {
                            _completeSetup();
                          }
                        },
                  child: Text(
                    _currentStep < 2
                        ? 'Tiếp tục'
                        : 'Hoàn tất & Khám phá FinMate',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Permissions(context);
      case 1:
        return _buildStep2AppSelection(context);
      case 2:
      default:
        return _buildStep3FinancialInit(context);
    }
  }

  // Bước 1: Quyền & ROM Defense (BR-03, BR-05, BR-10)
  Widget _buildStep1Permissions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tự động ghi nhận thông minh', style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        Text(
          'FinMate lắng nghe thông báo biến động số dư từ ngân hàng để tự động ghi chép tức thì mà không cần bạn nhập tay.',
          style: AppTypography.body(context).copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 24),
        _permissionItem(
          context,
          icon: LucideIcons.bellRing,
          title: 'Quyền truy cập thông báo',
          desc:
              'Cho phép FinMate nhận diện biến động số dư từ ngân hàng và ví điện tử.',
        ),
        const SizedBox(height: 16),
        _permissionItem(
          context,
          icon: LucideIcons.batteryCharging,
          title: 'Tắt tối ưu hóa pin (ROM Defense)',
          desc:
              'Ngăn hệ điều hành Android tự động tắt ngầm dịch vụ lắng nghe thông báo.',
        ),
        const SizedBox(height: 16),
        Text(
          'Các quyền này sẽ được yêu cầu khi tính năng tự động ghi nhận sẵn sàng.',
          style: AppTypography.caption(context),
        ),
      ],
    );
  }

  Widget _permissionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final actionColor = AppColors.primaryAction(context);
    return LiquidGlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: actionColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(desc, style: AppTypography.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bước 2: Chọn ứng dụng theo dõi (BR-07, BR-11)
  Widget _buildStep2AppSelection(BuildContext context) {
    final actionColor = AppColors.primaryAction(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn nguồn cần theo dõi', style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        Text(
          'FinMate chỉ xử lý thông báo từ các ứng dụng bạn chủ động cho phép dưới đây.',
          style: AppTypography.body(context).copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ref.watch(accountProvidersProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage(e), textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(accountProvidersProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (providers) => ListView(
                  children: providers.map((provider) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LiquidGlassCard(
                        enableBlur: false,
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(
                              provider.displayName,
                              style: AppTypography.bodyMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              provider.type.label,
                              style: AppTypography.caption(context),
                            ),
                            value: _selectedProviderIds.contains(provider.id),
                            activeTrackColor: actionColor,
                            onChanged: (val) {
                              setState(() {
                                val
                                    ? _selectedProviderIds.add(provider.id)
                                    : _selectedProviderIds.remove(provider.id);
                              });
                            },
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
        ),
      ],
    );
  }

  // Bước 3: Khởi tạo thông tin tài chính (BR-08, BR-45)
  Widget _buildStep3FinancialInit(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kế hoạch tài chính tháng', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(
            'Thiết lập thu nhập dự kiến và số dư ví để kích hoạt hệ thống cảnh báo và cố vấn AI.',
            style: AppTypography.body(context).copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          ZenvestHeroDeck(
            peekBadgeText: 'INIT',
            child: LiquidGlassCard(
              variant: LiquidGlassVariant.iridescentHero,
              enableBlur: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thu nhập hàng tháng dự kiến (VND)',
                    style: AppTypography.bodyMedium(context),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.moneyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.banknote, size: 20),
                      suffixText: '₫',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Số dư ví tiền mặt hiện có (VND)',
                    style: AppTypography.bodyMedium(context),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cashController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.moneyMedium.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.wallet, size: 20),
                      suffixText: '₫',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
