import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';

String _exclusionReasonLabel(String value) => switch (value) {
      'one_off' => 'Chi một lần',
      'user_marked' => 'Người dùng tự loại',
      _ => value,
    };

/// Cài đặt dự báo: dự phòng, ngưỡng số dư thấp, giờ yên lặng, bật/tắt cảnh báo, ví tính vào dự báo,
/// và một ô thử nhanh loại/đưa lại một giao dịch khỏi dữ liệu dự báo.
class ForecastSettingsScreen extends ConsumerStatefulWidget {
  const ForecastSettingsScreen({super.key});

  @override
  ConsumerState<ForecastSettingsScreen> createState() => _ForecastSettingsScreenState();
}

class _ForecastSettingsScreenState extends ConsumerState<ForecastSettingsScreen> {
  final _reserveController = TextEditingController();
  final _lowBalanceController = TextEditingController();
  final _quietStartController = TextEditingController();
  final _quietEndController = TextEditingController();
  final _exclusionIdController = TextEditingController();

  bool _useDefaultReserve = true;
  bool _lowBalanceAlertOn = false;
  bool _useDefaultQuietHours = true;
  bool _alertsEnabled = true;
  bool _initialized = false;
  bool _saving = false;

  String _exclusionReason = 'one_off';
  bool _exclusionBusy = false;
  TransactionForecastExclusionEntity? _exclusionResult;

  @override
  void dispose() {
    _reserveController.dispose();
    _lowBalanceController.dispose();
    _quietStartController.dispose();
    _quietEndController.dispose();
    _exclusionIdController.dispose();
    super.dispose();
  }

  /// Chỉ nạp vào form một lần khi tải xong, để không ghi đè thứ người dùng đang sửa khi state đổi.
  void _syncFrom(ForecastSettingsEntity settings) {
    if (_initialized) return;
    _initialized = true;
    _useDefaultReserve = settings.usesDefaultReserve;
    _reserveController.text = settings.reserveCents?.toString() ?? '';
    _lowBalanceAlertOn = settings.lowBalanceAlertEnabled;
    _lowBalanceController.text = settings.lowBalanceThresholdCents?.toString() ?? '';
    _useDefaultQuietHours = settings.usesDefaultQuietHours;
    _quietStartController.text = settings.quietHoursStart ?? '';
    _quietEndController.text = settings.quietHoursEnd ?? '';
    _alertsEnabled = settings.forecastAlertsEnabled;
  }

  BigInt? _parseCents(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : BigInt.parse(digits);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(forecastSettingsControllerProvider.notifier).update(
            reserveCents: _useDefaultReserve ? null : _parseCents(_reserveController.text),
            lowBalanceThresholdCents: _lowBalanceAlertOn ? _parseCents(_lowBalanceController.text) : null,
            quietHoursStart: _useDefaultQuietHours ? null : _quietStartController.text.trim(),
            quietHoursEnd: _useDefaultQuietHours ? null : _quietEndController.text.trim(),
            forecastAlertsEnabled: _alertsEnabled,
          );
      if (mounted) {
        _initialized = false; // nạp lại form từ dữ liệu đã lưu (BE có thể chuẩn hoá lại giá trị)
        messenger.showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt dự báo.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAccount(String accountId, bool included) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(forecastSettingsControllerProvider.notifier).setAccountInclusion(accountId, included);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _submitExclusion(bool excluded) async {
    final id = _exclusionIdController.text.trim();
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exclusionBusy = true);
    try {
      final result = await ref.read(forecastRepositoryProvider).setTransactionExclusion(
            id,
            excluded: excluded,
            reason: excluded ? _exclusionReason : null,
          );
      if (mounted) setState(() => _exclusionResult = result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _exclusionBusy = false);
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildReserveCard(BuildContext context, ForecastSettingsEntity settings) {
    return _sectionCard(
      title: 'Khoản dự phòng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dự phòng đang áp dụng: ${settings.formattedEffectiveReserve}',
            style: AppTypography.caption(context),
          ),
          CheckboxListTile(
            key: const ValueKey('forecast-settings-use-default-reserve'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Dùng mức mặc định hệ thống (${settings.defaultReservePercentOfIncome}% thu nhập)'),
            value: _useDefaultReserve,
            onChanged: (v) => setState(() => _useDefaultReserve = v ?? true),
          ),
          if (!_useDefaultReserve)
            TextField(
              key: const ValueKey('forecast-settings-reserve-amount'),
              controller: _reserveController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Dự phòng tự đặt (₫)'),
            ),
        ],
      ),
    );
  }

  Widget _buildLowBalanceCard(BuildContext context) {
    return _sectionCard(
      title: 'Cảnh báo số dư thấp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('forecast-settings-low-balance-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Bật cảnh báo khi số dư dự kiến xuống thấp'),
            value: _lowBalanceAlertOn,
            onChanged: (v) => setState(() => _lowBalanceAlertOn = v),
          ),
          if (_lowBalanceAlertOn)
            TextField(
              key: const ValueKey('forecast-settings-low-balance-amount'),
              controller: _lowBalanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ngưỡng cảnh báo (₫)'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursCard(BuildContext context, ForecastSettingsEntity settings) {
    return _sectionCard(
      title: 'Giờ yên lặng (không gửi cảnh báo)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: const ValueKey('forecast-settings-use-default-quiet-hours'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Dùng giờ mặc định hệ thống (${settings.defaultQuietHoursStart}–${settings.defaultQuietHoursEnd})'),
            value: _useDefaultQuietHours,
            onChanged: (v) => setState(() => _useDefaultQuietHours = v ?? true),
          ),
          if (!_useDefaultQuietHours)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('forecast-settings-quiet-start'),
                    controller: _quietStartController,
                    decoration: const InputDecoration(labelText: 'Bắt đầu (HH:mm)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('forecast-settings-quiet-end'),
                    controller: _quietEndController,
                    decoration: const InputDecoration(labelText: 'Kết thúc (HH:mm)'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
    return _sectionCard(
      title: 'Cảnh báo dự báo',
      child: SwitchListTile(
        key: const ValueKey('forecast-settings-alerts-enabled'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Bật cảnh báo dự báo (số dư thấp, vượt ngân sách, thu nhập trễ...)'),
        value: _alertsEnabled,
        onChanged: (v) => setState(() => _alertsEnabled = v),
      ),
    );
  }

  Widget _buildAccountsCard(BuildContext context, ForecastSettingsEntity settings) {
    return _sectionCard(
      title: 'Ví tính vào dự báo',
      child: settings.accounts.isEmpty
          ? Text('Chưa có ví nào.', style: AppTypography.caption(context))
          : Column(
              children: [
                for (final account in settings.accounts)
                  SwitchListTile(
                    key: ValueKey('forecast-account-switch-${account.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(account.name),
                    value: account.includeInForecast,
                    onChanged: (v) => _toggleAccount(account.id, v),
                  ),
              ],
            ),
    );
  }

  Widget _buildExclusionTesterCard(BuildContext context) {
    final result = _exclusionResult;
    return _sectionCard(
      title: 'Loại/đưa lại một giao dịch khỏi dự báo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số dư không đổi — giao dịch vẫn có thật, chỉ không dùng làm dữ liệu dự báo.',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('exclusion-transaction-id'),
            controller: _exclusionIdController,
            decoration: const InputDecoration(labelText: 'ID giao dịch'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: const ValueKey('exclusion-reason'),
            initialValue: _exclusionReason,
            decoration: const InputDecoration(labelText: 'Lý do (khi loại)'),
            items: [
              for (final r in const ['one_off', 'user_marked'])
                DropdownMenuItem(value: r, child: Text(_exclusionReasonLabel(r))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _exclusionReason = v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton(
                key: const ValueKey('exclude-transaction-button'),
                onPressed: _exclusionBusy ? null : () => _submitExclusion(true),
                child: const Text('Loại khỏi dự báo'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                key: const ValueKey('include-transaction-button'),
                onPressed: _exclusionBusy ? null : () => _submitExclusion(false),
                child: const Text('Đưa lại vào dự báo'),
              ),
            ],
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                result.excludeFromForecast
                    ? 'Đã loại khỏi dự báo (${_exclusionReasonLabel(result.reason ?? '')}).'
                    : 'Đã đưa lại vào dự báo.',
                style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(forecastSettingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt dự báo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.read(forecastSettingsControllerProvider.notifier).load(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (settings) {
          _syncFrom(settings);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildReserveCard(context, settings),
              const SizedBox(height: AppSpacing.lg),
              _buildLowBalanceCard(context),
              const SizedBox(height: AppSpacing.lg),
              _buildQuietHoursCard(context, settings),
              const SizedBox(height: AppSpacing.lg),
              _buildAlertsCard(context),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                key: const ValueKey('forecast-settings-save'),
                onPressed: _saving ? null : _save,
                child: const Text('Lưu cài đặt'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAccountsCard(context, settings),
              const SizedBox(height: AppSpacing.lg),
              _buildExclusionTesterCard(context),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}
