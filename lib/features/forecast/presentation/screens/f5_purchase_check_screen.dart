import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

final _verdictLabel = {
  'shortfall_risk': 'CÓ NGUY CƠ THIẾU TIỀN',
  'consider': 'NÊN CÂN NHẮC',
  'off_plan': 'LỆCH KẾ HOẠCH',
  'fits_plan': 'PHÙ HỢP VỚI KẾ HOẠCH',
  'insufficient_data': 'CHƯA ĐỦ DỮ LIỆU',
};

final _verdictColor = {
  'shortfall_risk': GlassColors.danger,
  'consider': GlassColors.warning,
  'off_plan': GlassColors.warning,
  'fits_plan': GlassColors.success,
  'insufficient_data': GlassColors.textMuted,
};

/// F5 — Kiểm tra mua sắm (Luồng 6). Dùng đúng `POST /forecast/purchase-check` đã có sẵn ở BE
/// (xem `docs/flows/flow-6-purchase-decision-assistant.md`), KHÔNG bịa "điểm bền vững /100" như
/// Stitch vẽ — BE chỉ trả `verdict` dạng chuỗi (shortfall_risk/consider/off_plan/fits_plan/
/// insufficient_data) + số liệu thật, nên UI hiện đúng verdict + số liệu, không quy đổi sang điểm số.
class F5PurchaseCheckScreen extends ConsumerStatefulWidget {
  const F5PurchaseCheckScreen({super.key});

  @override
  ConsumerState<F5PurchaseCheckScreen> createState() => _F5PurchaseCheckScreenState();
}

class _F5PurchaseCheckScreenState extends ConsumerState<F5PurchaseCheckScreen> {
  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  String? _accountId;
  String? _categoryId;

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền dự kiến hợp lệ.')));
      return;
    }
    ref.read(purchaseCheckControllerProvider.notifier).check(
          amountCents: amount,
          item: _itemController.text.trim().isEmpty ? null : _itemController.text.trim(),
          accountId: _accountId,
          categoryId: _categoryId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final resultState = ref.watch(purchaseCheckControllerProvider);
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), onPressed: () => context.pop()),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kiểm tra mua sắm', style: GlassTypography.headlineMd()),
              const SizedBox(width: 8),
              GlassBadge(text: 'AI CHECK', color: GlassColors.accentSkyBlue),
            ],
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _buildIntro(),
              const SizedBox(height: 16),
              _buildForm(accounts, categories),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassColors.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                  child: const Text('Kiểm tra ngay'),
                ),
              ),
              const SizedBox(height: 16),
              if (resultState != null) _buildResult(resultState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return GlassCard(
      level: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, size: 22, color: GlassColors.slateAnchor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FinMate AI Simulator', style: GlassTypography.headlineSm()),
                const SizedBox(height: 4),
                Text(
                  'Nhập món đồ bạn dự định mua, FinMate sẽ tính tác động đến dòng tiền từ hôm nay tới kỳ lương kế tiếp, ngân sách và mục tiêu của bạn.',
                  style: GlassTypography.bodySm(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(List<FinancialAccount> accounts, List<Category> categories) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TÊN MÓN ĐỒ / KẾ HOẠCH MUA', style: GlassTypography.labelCaps()),
          const SizedBox(height: 8),
          TextField(
            controller: _itemController,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Tai nghe Sony WH-1000XM5',
              counterText: '',
              prefixIcon: const Icon(LucideIcons.package, size: 18),
              border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
              filled: true,
              fillColor: GlassColors.secondarySurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SỐ TIỀN DỰ KIẾN', style: GlassTypography.labelCaps()),
              Text('Đơn vị: VNĐ', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            style: GlassTypography.displayHero().copyWith(fontSize: 28),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'đ',
              border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
              filled: true,
              fillColor: GlassColors.secondarySurface,
            ),
          ),
          const SizedBox(height: 16),
          Text('DỰ KIẾN LẤY TỪ NGUỒN', style: GlassTypography.labelCaps()),
          const SizedBox(height: 8),
          _dropdown(
            value: _accountId,
            hint: 'Không xác định (bỏ qua số dư tài khoản)',
            icon: LucideIcons.landmark,
            items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.name} — ${formatVnd(a.balanceCents)}'))],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 16),
          Text('DANH MỤC', style: GlassTypography.labelCaps()),
          const SizedBox(height: 8),
          _dropdown(
            value: _categoryId,
            hint: 'Chưa chọn danh mục',
            icon: LucideIcons.tag,
            items: [
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(categoryIcon(c.slug), size: 16), const SizedBox(width: 8), Text(c.name)])),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedInput),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: GlassColors.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(hint, style: GlassTypography.bodyMd(), overflow: TextOverflow.ellipsis)),
            ],
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResult(AsyncValue<PurchaseCheckEntity> resultState) {
    return resultState.when(
      loading: () => const GlassCard(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => GlassCard(child: Text(errorMessage(e), style: GlassTypography.bodyMd())),
      data: (result) {
        final color = _verdictColor[result.verdict] ?? GlassColors.textMuted;
        final label = _verdictLabel[result.verdict] ?? result.verdict;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              level: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GlassBadge(text: label, color: color),
                      if (result.status != 'assessable') GlassBadge(text: result.status == 'partial' ? 'Dữ liệu một phần' : 'Chưa đủ dữ liệu', color: GlassColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(result.summary, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                  if (!result.budget.isUnknown) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(result.budget.isOver ? LucideIcons.trendingDown : LucideIcons.trendingUp, size: 16, color: result.budget.isOver ? GlassColors.danger : GlassColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.budget.isOver
                                ? 'Vượt ngân sách danh mục "${result.budget.name}" nếu mua.'
                                : 'Vẫn trong ngân sách danh mục "${result.budget.name}".',
                            style: GlassTypography.bodySm(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (result.plan.isOver) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.triangleAlert, size: 16, color: GlassColors.warning),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Khoản mua này sẽ làm kế hoạch tháng (số tiền có thể chi) bị âm.', style: GlassTypography.bodySm())),
                      ],
                    ),
                  ],
                  if (result.maxAffordableCents != null) ...[
                    const SizedBox(height: 8),
                    Text('Mức tối đa có thể mua đúng ngày này: ${formatVnd(result.maxAffordableCents!)}', style: GlassTypography.bodySm()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (result.verdict == 'shortfall_risk' || result.verdict == 'consider')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: result.earliestSafeDate == null
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gợi ý: cân nhắc mua sau ngày ${DateFormat('dd/MM/yyyy').format(result.earliestSafeDate!)}.')),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassColors.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                  icon: const Icon(LucideIcons.calendarClock, size: 18),
                  label: Text(
                    result.earliestSafeDate == null
                        ? 'Chưa đủ dữ liệu để gợi ý ngày mua'
                        : 'Cân nhắc mua sau ngày ${DateFormat('dd/MM').format(result.earliestSafeDate!)}',
                  ),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => CreateTransactionBottomSheet.show(
                  context,
                  initialAmountCents: result.amountCents,
                  initialDescription: result.item,
                  initialCategoryId: _categoryId,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: GlassColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                ),
                icon: Icon(LucideIcons.creditCard, size: 18, color: GlassColors.textPrimary),
                label: Text('Vẫn mua và ghi nhận giao dịch', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );
      },
    );
  }
}
