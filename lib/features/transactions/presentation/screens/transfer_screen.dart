import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// "1250000" -> "1.250.000" (chỉ giữ chữ số)
String _groupThousands(String raw) => raw
    .replaceAll(RegExp(r'\D'), '')
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Gom nhóm hàng nghìn khi gõ số tiền; phần lưu bỏ dấu chấm nên không đổi giá trị
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _groupThousands(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Màn D3: Chuyển tiền giữa các ví / tài khoản (Transfer Screen)
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  FinancialAccount? _fromAccount;
  FinancialAccount? _toAccount;
  DateTime _transferDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Mức cộng nhanh vào ô số tiền (tiện nhập, không phải dữ liệu tài chính)
  static const _quickAmounts = [500000, 1000000, 2000000];

  int get _amount =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  void _setAmount(int value) => setState(
    () => _amountController.text = _groupThousands(value.toString()),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _transferDate = picked);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccount == null || _toAccount == null) {
      setState(() => _errorMessage = 'Vui lòng chọn ví nguồn và ví đích.');
      return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
      setState(
        () => _errorMessage = 'Ví nguồn và ví đích không được trùng nhau.',
      );
      return;
    }

    final rawText = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();
    final amountInt = int.tryParse(rawText);
    if (amountInt == null || amountInt <= 0) {
      setState(() => _errorMessage = 'Số tiền chuyển không hợp lệ.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final amountCents = BigInt.from(amountInt);
      await ref
          .read(transactionControllerProvider.notifier)
          .transferInternal(
            amountCents: amountCents,
            fromAccountId: _fromAccount!.id,
            toAccountId: _toAccount!.id,
            date: _transferDate,
            description: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : 'Chuyển tiền từ ${_fromAccount!.name} sang ${_toAccount!.name}',
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển ${formatVnd(amountCents)} thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể thực hiện chuyển tiền: ${e.toString()}';
      });
    }
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quy tắc chuyển ví nội bộ'),
        content: const Text(
          'Chuyển giữa các ví của bạn không tính vào chi tiêu hay thu nhập. Ví nguồn và ví đích phải khác nhau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsControllerProvider);
    final accounts = accountsState.valueOrNull ?? [];

    if (_fromAccount == null && accounts.isNotEmpty) {
      _fromAccount = accounts.first;
      if (accounts.length > 1) {
        _toAccount = accounts[1];
      }
    }

    return Scaffold(
      body: AmbientGlassBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          LiquidGlassCard(
                            variant: LiquidGlassVariant.subtle,
                            padding: const EdgeInsets.all(14),
                            borderColor: AppColors.danger.withValues(
                              alpha: 0.4,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTypography.caption(context)
                                        .copyWith(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _walletsCard(context, accounts),
                        const SizedBox(height: 16),
                        _amountCard(context),
                        const SizedBox(height: 16),
                        _attributesCard(context),
                        ..._insight(context),
                      ],
                    ),
                  ),
                ),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context, {double radius = 24}) =>
      BoxDecoration(
        color: AppColors.isDark(context)
            ? AppColors.glassFillDark
            : AppColors.glassFillLight,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slateAction.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      );

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          LiquidGlassIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Quay lại',
            iconSize: 18,
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Chuyển tiền nội bộ',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge(context).copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          LiquidGlassIconButton(
            icon: LucideIcons.info,
            tooltip: 'Quy tắc chuyển',
            iconSize: 18,
            onPressed: _showRules,
          ),
        ],
      ),
    );
  }

  /// Hai ví nguồn/đích nối nhau, nút hoán đổi ở giữa
  Widget _walletsCard(BuildContext context, List<FinancialAccount> accounts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          _walletBlock(
            context,
            label: 'Từ nguồn tiền',
            selected: _fromAccount,
            accounts: accounts,
            onChanged: (val) => setState(() => _fromAccount = val),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: LiquidGlassIconButton(
              icon: LucideIcons.arrowDownUp,
              tooltip: 'Hoán đổi nguồn tiền',
              size: 40,
              iconSize: 16,
              onPressed: () => setState(() {
                final temp = _fromAccount;
                _fromAccount = _toAccount;
                _toAccount = temp;
              }),
            ),
          ),
          _walletBlock(
            context,
            label: 'Đến nguồn tiền',
            selected: _toAccount,
            accounts: accounts,
            onChanged: (val) => setState(() => _toAccount = val),
          ),
        ],
      ),
    );
  }

  Widget _walletBlock(
    BuildContext context, {
    required String label,
    required FinancialAccount? selected,
    required List<FinancialAccount> accounts,
    required ValueChanged<FinancialAccount?> onChanged,
  }) {
    final secondary = AppTypography.caption(context);
    Widget summary(FinancialAccount a) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: secondary),
        Text(
          a.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        Text.rich(
          TextSpan(
            text: 'Số dư: ',
            children: [
              TextSpan(
                text: formatVnd(a.balanceCents),
                style: secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          style: secondary,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Icon(
              LucideIcons.wallet,
              size: 20,
              color: AppColors.slateOn(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FinancialAccount>(
                value: selected,
                isExpanded: true,
                itemHeight: null,
                icon: const Icon(LucideIcons.chevronDown, size: 18),
                hint: Text(label, style: secondary),
                selectedItemBuilder: (_) => [
                  for (final a in accounts)
                    Align(alignment: Alignment.centerLeft, child: summary(a)),
                ],
                items: [
                  for (final acc in accounts)
                    DropdownMenuItem<FinancialAccount>(
                      value: acc,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              acc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatVnd(acc.balanceCents),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCard(BuildContext context) {
    final from = _fromAccount;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Số tiền chuyển',
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.tabular(
                    AppTypography.h1(context).copyWith(
                      fontSize: 30,
                      height: 1.25,
                      letterSpacing: -0.75,
                    ),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: '0',
                    suffixText: ' ₫',
                    hintStyle: TextStyle(color: AppColors.textMuted(context)),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty || val == '0') {
                      return 'Vui lòng nhập số tiền.';
                    }
                    return null;
                  },
                ),
              ),
              if (_amountController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa số tiền',
                  onPressed: () => setState(_amountController.clear),
                  icon: const Icon(LucideIcons.circleX, size: 18),
                ),
            ],
          ),
          Divider(height: 1, color: AppColors.glassBorder(context)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in _quickAmounts) ...[
                  _chip(
                    context,
                    '+${formatVnd(BigInt.from(v))}',
                    () => _setAmount(_amount + v),
                  ),
                  const SizedBox(width: 8),
                ],
                // Số dư lấy từ ví nguồn (dữ liệu BE)
                _chip(
                  context,
                  'Tất cả số dư',
                  from == null
                      ? null
                      : () => _setAmount(from.balanceCents.toInt()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle(context).withValues(alpha: 0.5),
          borderRadius: AppSpacing.roundedPill,
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _attributesCard(BuildContext context) {
    final secondary = AppColors.textSecondary(context);
    Widget label(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 16, color: secondary),
        const SizedBox(width: 10),
        Text(
          text,
          style: AppTypography.body(context).copyWith(color: secondary),
        ),
      ],
    );
    final today = DateTime.now();
    final isToday =
        _transferDate.year == today.year &&
        _transferDate.month == today.month &&
        _transferDate.day == today.day;
    final dateText =
        '${isToday ? 'Hôm nay, ' : ''}${DateFormat('dd/MM/yyyy').format(_transferDate)}';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: AppSpacing.roundedSmall,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  label(LucideIcons.calendar, 'Ngày chuyển'),
                  const Spacer(),
                  Text(dateText, style: AppTypography.bodyMedium(context)),
                  const SizedBox(width: 6),
                  Icon(LucideIcons.chevronRight, size: 14, color: secondary),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.glassBorder(context)),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                label(LucideIcons.fileText, 'Ghi chú'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _noteController,
                    textAlign: TextAlign.end,
                    style: AppTypography.body(context),
                    decoration: const InputDecoration(
                      hintText: 'Ví dụ: Nạp ví MoMo',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gợi ý số dư ví nguồn sau khi chuyển, tính từ số liệu thật
  List<Widget> _insight(BuildContext context) {
    final from = _fromAccount;
    final amount = _amount;
    if (from == null || amount <= 0) return const [];
    final after = from.balanceCents - BigInt.from(amount);
    final enough = after >= BigInt.zero;
    final body = enough
        ? 'Sau khi chuyển, số dư ${from.name} còn ${formatVnd(after)}.'
        : 'Số dư ${from.name} không đủ cho khoản chuyển này (thiếu ${formatVnd(-after)}).';
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (enough ? AppColors.slateOn(context) : AppColors.warning).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                enough ? LucideIcons.sparkles : LucideIcons.triangleAlert,
                size: 16,
                // Icon cùng màu nền nhạt: tương phản đủ ở cả sáng lẫn tối (trước là chữ trắng trên nền xanh nhạt ở giao diện tối).
                color: enough ? AppColors.slateOn(context) : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FINMATE THÔNG MINH',
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.55,
                      color: AppColors.slateOn(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: AppTypography.caption(context).copyWith(
                      color: AppColors.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncActionBuilder(
            onPressed: _isLoading ? null : _handleSubmit,
            builder: (_, onTap, running) => ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                backgroundColor: AppColors.primaryAction(context),
                foregroundColor: AppColors.onPrimaryAction(context),
              ),
              child: running ? const ButtonLoadingIndicator() : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _isLoading ? 'Đang xử lý...' : 'Xác nhận chuyển ví',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isLoading ? null : () => context.pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.textSecondary(context),
            ),
            child: const Text(
              'Hủy bỏ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
