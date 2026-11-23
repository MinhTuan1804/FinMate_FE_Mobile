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

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kiểm tra mua sắm'),
        content: const Text(
          'Nhập món đồ và số tiền dự kiến. FinMate tính tác động của khoản chi này đến dòng tiền tới kỳ lương kế tiếp, ngân sách danh mục và kế hoạch tháng. Kết quả chỉ để tham khảo, không tạo giao dịch.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đã hiểu'))],
      ),
    );
  }

  /// Chạy lại kiểm tra với đúng ngày an toàn sớm nhất mà BE gợi ý.
  void _replanAt(DateTime date, PurchaseCheckEntity r) {
    ref.read(purchaseCheckControllerProvider.notifier).check(
          amountCents: r.amountCents,
          purchaseDate: date,
          item: r.item,
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
              Flexible(child: Text('Kiểm tra mua sắm', style: GlassTypography.headlineMd(), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              GlassBadge(text: 'AI CHECK', color: GlassColors.accentSkyBlue),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Trợ giúp',
              icon: Icon(LucideIcons.circleQuestionMark, color: GlassColors.textPrimary),
              onPressed: _showHelp,
            ),
          ],
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
                    foregroundColor: GlassColors.onInk,
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
              Flexible(child: Text('SỐ TIỀN DỰ KIẾN', style: GlassTypography.labelCaps(), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text('Đơn vị: VNĐ', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            style: GlassTypography.displayHero().copyWith(fontSize: 26),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'đ',
              suffixIcon: Icon(LucideIcons.banknote, size: 20, color: GlassColors.textMuted),
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
            items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.name} — ${formatVnd(a.balanceCents)}', overflow: TextOverflow.ellipsis))],
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
                DropdownMenuItem(value: c.id, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(categoryIcon(c.slug), size: 16), const SizedBox(width: 8), Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis))])),
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

        final date = result.earliestSafeDate;
        final b = result.budget;
        final over = b.projectedAfterCents != null && b.limitCents != null ? b.projectedAfterCents! - b.limitCents! : null;
        final remainingBefore = b.projectedAfterCents != null && b.limitCents != null ? b.limitCents! - (b.projectedAfterCents! - result.amountCents) : null;
        final strong = GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700);

        Widget impactRow(IconData icon, Color tone, List<InlineSpan> spans) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text.rich(TextSpan(style: GlassTypography.bodyMd(), children: spans))),
              ],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              level: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GlassBadge(text: label, color: color),
                      if (result.status != 'assessable') GlassBadge(text: result.status == 'partial' ? 'Dữ liệu một phần' : 'Chưa đủ dữ liệu', color: GlassColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(result.summary, style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                  if (!b.isUnknown) ...[
                    const SizedBox(height: 14),
                    impactRow(
                      b.isOver ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                      b.isOver ? GlassColors.danger : GlassColors.success,
                      [
                        TextSpan(text: b.isOver ? 'Mua ngay sẽ vượt ngân sách danh mục "${b.name}"' : 'Vẫn trong ngân sách danh mục "${b.name}"'),
                        if (b.isOver && over != null && over > BigInt.zero) ...[
                          const TextSpan(text: ' thêm '),
                          TextSpan(text: formatVnd(over), style: strong.copyWith(color: GlassColors.danger)),
                        ] else if (!b.isOver && remainingBefore != null) ...[
                          const TextSpan(text: ', hạn mức còn lại trước khi mua '),
                          TextSpan(text: formatVnd(remainingBefore), style: strong),
                        ],
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ],
                  if (result.plan.isOver) ...[
                    const SizedBox(height: 12),
                    impactRow(LucideIcons.triangleAlert, GlassColors.warning, const [
                      TextSpan(text: 'Khoản mua này sẽ làm kế hoạch tháng (số tiền có thể chi) bị âm.'),
                    ]),
                  ],
                  if (date != null || result.maxAffordableCents != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GlassColors.accentSkyBlue.withValues(alpha: 0.14),
                        borderRadius: GlassRadius.roundedInput,
                        border: Border.all(color: GlassColors.accentSkyBlue.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.sparkles, size: 14, color: GlassColors.slateAnchor),
                              const SizedBox(width: 6),
                              Flexible(child: Text('Đề xuất thông minh từ AI', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (date != null)
                            Text.rich(TextSpan(style: GlassTypography.bodySm(color: GlassColors.textPrimary), children: [
                              const TextSpan(text: 'Bạn nên dời lịch mua sang ngày '),
                              TextSpan(text: DateFormat('dd/MM/yyyy').format(date), style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                              const TextSpan(text: ' để dòng tiền không bị thiếu.'),
                            ])),
                          if (result.maxAffordableCents != null)
                            Padding(
                              padding: EdgeInsets.only(top: date != null ? 4 : 0),
                              child: Text('Mức tối đa có thể mua đúng ngày này: ${formatVnd(result.maxAffordableCents!)}', style: GlassTypography.bodySm()),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Chỉ hiện khi BE trả ngày an toàn sớm nhất; bấm sẽ chạy lại kiểm tra với ngày đó.
            if (date != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _replanAt(date, result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassColors.ink,
                    foregroundColor: GlassColors.onInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                  ),
                  icon: const Icon(LucideIcons.calendarClock, size: 18),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Lập kế hoạch mua sau ngày ${DateFormat('dd/MM').format(date)}', maxLines: 1)),
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
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Vẫn mua và trừ vào ngân sách', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), maxLines: 1)),
              ),
            ),
          ],
        );
      },
    );
  }
}
