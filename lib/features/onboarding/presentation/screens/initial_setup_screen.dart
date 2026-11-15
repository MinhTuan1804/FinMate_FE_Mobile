import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';

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
      SnackBar(content: Text(message), backgroundColor: GlassColors.danger),
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
      final providers =
          ref.read(accountProvidersProvider).valueOrNull ??
          const <AccountProviderInfo>[];
      await ref
          .read(onboardingControllerProvider)
          .complete(
            OnboardingInput(
              monthlyIncomeCents: income.toInt(),
              cashBalanceCents: cash,
              selectedProviders: providers
                  .where((p) => _selectedProviderIds.contains(p.id))
                  .toList(),
            ),
          );
      // Cuối chuỗi onboarding bắt buộc: hỏi quyền đọc thông báo 1 lần (§16.4) trước khi sang
      // khảo sát đầu vào (B3) — không đi thẳng '/survey' nữa.
      if (mounted) context.go('/onboarding/notification-permission');
    } catch (e) {
      if (mounted) _showError(errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const stepLabels = ['Hồ sơ cá nhân', 'Phân loại quỹ', 'Hoàn tất thiết lập'];

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Thiết lập ban đầu (${_currentStep + 1}/3) · ${stepLabels[_currentStep]}',
            style: GlassTypography.headlineSm(),
          ),
          actions: [
            if (_currentStep < 2)
              TextButton(
                onPressed: () => setState(() => _currentStep++),
                child: Text('Bỏ qua', style: GlassTypography.bodyMd(color: GlassColors.textMuted)),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    backgroundColor: GlassColors.secondarySurface,
                    color: GlassColors.ink,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(child: SingleChildScrollView(child: _buildCurrentStep(context))),

                const SizedBox(height: 16),
                GlassPrimaryButton(
                  label: _currentStep < 2 ? 'Tiếp tục' : 'Hoàn tất & Khám phá FinMate',
                  loading: _isSaving,
                  onPressed: () {
                    if (_currentStep < 2) {
                      setState(() => _currentStep++);
                    } else {
                      _completeSetup();
                    }
                  },
                ),
                const SizedBox(height: 16),
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
        Text('Tự động ghi nhận thông minh', style: GlassTypography.headlineMd()),
        const SizedBox(height: 8),
        Text(
          'FinMate lắng nghe thông báo biến động số dư từ ngân hàng để tự động ghi chép tức thì mà không cần bạn nhập tay.',
          style: GlassTypography.bodyMd(),
        ),
        const SizedBox(height: 24),
        _permissionItem(
          icon: LucideIcons.bellRing,
          title: 'Quyền truy cập thông báo',
          desc: 'Cho phép FinMate nhận diện biến động số dư từ ngân hàng và ví điện tử.',
        ),
        const SizedBox(height: 16),
        _permissionItem(
          icon: LucideIcons.batteryCharging,
          title: 'Tắt tối ưu hóa pin (ROM Defense)',
          desc: 'Ngăn hệ điều hành Android tự động tắt ngầm dịch vụ lắng nghe thông báo.',
        ),
        const SizedBox(height: 16),
        Text('Các quyền này sẽ được yêu cầu khi tính năng tự động ghi nhận sẵn sàng.', style: GlassTypography.bodySm()),
      ],
    );
  }

  Widget _permissionItem({required IconData icon, required String title, required String desc}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GlassColors.slateAnchor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: GlassTypography.bodySm()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bước 2: Chọn ứng dụng theo dõi (BR-07, BR-11)
  Widget _buildStep2AppSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn nguồn cần theo dõi', style: GlassTypography.headlineMd()),
        const SizedBox(height: 8),
        Text(
          'FinMate chỉ xử lý thông báo từ các ứng dụng bạn chủ động cho phép dưới đây.',
          style: GlassTypography.bodyMd(),
        ),
        const SizedBox(height: 20),
        ref.watch(accountProvidersProvider).when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    TextButton(
                      onPressed: () => ref.invalidate(accountProvidersProvider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (providers) => Column(
                children: providers.map((provider) {
                  final selected = _selectedProviderIds.contains(provider.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(provider.displayName, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(provider.type.label, style: GlassTypography.bodySm()),
                          value: selected,
                          activeThumbColor: Colors.white,
                          activeTrackColor: GlassColors.ink,
                          onChanged: (val) {
                            setState(() {
                              val ? _selectedProviderIds.add(provider.id) : _selectedProviderIds.remove(provider.id);
                            });
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
      ],
    );
  }

  // Bước 3: Khởi tạo thông tin tài chính (BR-08, BR-45)
  Widget _buildStep3FinancialInit(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kế hoạch tài chính tháng', style: GlassTypography.headlineMd()),
        const SizedBox(height: 8),
        Text(
          'Thiết lập thu nhập dự kiến và số dư ví để kích hoạt hệ thống cảnh báo và cố vấn AI.',
          style: GlassTypography.bodyMd(),
        ),
        const SizedBox(height: 24),
        GlassTextField(
          label: 'Thu nhập hàng tháng dự kiến (VND)',
          controller: _incomeController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          prefixIcon: LucideIcons.banknote,
          suffixIcon: const Padding(padding: EdgeInsets.only(right: 16), child: Center(widthFactor: 1, child: Text('₫'))),
        ),
        const SizedBox(height: 20),
        GlassTextField(
          label: 'Số dư ví tiền mặt hiện có (VND)',
          controller: _cashController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          prefixIcon: LucideIcons.wallet,
          suffixIcon: const Padding(padding: EdgeInsets.only(right: 16), child: Center(widthFactor: 1, child: Text('₫'))),
        ),
      ],
    );
  }
}
