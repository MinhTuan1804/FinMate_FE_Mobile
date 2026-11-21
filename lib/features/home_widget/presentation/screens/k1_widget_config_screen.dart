import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/features/home_widget/data/widget_config_bridge.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

final _accountsProvider = FutureProvider<List<FinancialAccount>>(
  (ref) => ref.watch(accountsRepositoryProvider).getAccounts(),
);

/// Dữ liệu xem trước đã tính từ số liệu thật của người dùng — cùng công thức với các lớp *Sync.kt
/// (perDay = spendable / số ngày còn lại trong tháng; percent = spent / income). Giá trị null = chưa có.
class WidgetPreviewData {
  const WidgetPreviewData({
    this.accountLabel,
    this.balance,
    this.perDay,
    this.spent,
    this.income,
    this.percentUsed,
    this.forecastEnd,
  });

  final String? accountLabel;
  final BigInt? balance;
  final BigInt? perDay;
  final BigInt? spent;
  final BigInt? income;
  final int? percentUsed;
  final BigInt? forecastEnd;

  bool get hasBudget => perDay != null;

  static WidgetPreviewData compute({
    required SpendableEntity spendable,
    List<FinancialAccount>? accounts,
    String? sourceAccountId,
    BigInt? forecastEnd,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final daysRemaining = DateTime(today.year, today.month + 1, 0).day - today.day + 1;
    final spendableCents = spendable.spendableCents;
    final income = spendable.incomeCents;

    BigInt? balance;
    String? label;
    if (accounts != null && accounts.isNotEmpty) {
      final picked = sourceAccountId == null ? accounts : accounts.where((a) => a.id == sourceAccountId).toList();
      if (picked.isNotEmpty) {
        balance = picked.fold<BigInt>(BigInt.zero, (sum, a) => sum + a.balanceCents);
        label = sourceAccountId == null ? 'Tất cả tài khoản' : picked.first.name;
      }
    }
    return WidgetPreviewData(
      accountLabel: label,
      balance: balance,
      perDay: spendableCents == null ? null : spendableCents ~/ BigInt.from(daysRemaining),
      spent: spendable.spentCents,
      income: income,
      percentUsed: (income == null || income == BigInt.zero) ? 0 : (spendable.spentCents * BigInt.from(100) ~/ income).toInt(),
      forecastEnd: forecastEnd,
    );
  }
}

/// Màn "Cấu hình Widget FinMate" (k1_widget_config_screen.png).
///
/// Lớp dùng chung — KHÔNG gắn logic riêng cho Activity: hiện tại được native
/// `WidgetConfigActivity` mở làm nội dung duy nhất của 1 Flutter engine riêng (entrypoint
/// `widgetConfigMain`, xem widget_config_main.dart), nhưng không phụ thuộc gì vào việc đó — sau
/// này khi Luồng 7 (Cài đặt/H1) build xong mục "Widget trên màn hình chính", màn này có thể được
/// mở lại y hệt từ trong app (qua [widgetId]/[initialKind] truyền sẵn) để sửa cấu hình đã ghim.
class K1WidgetConfigScreen extends ConsumerStatefulWidget {
  const K1WidgetConfigScreen({
    super.key,
    required this.bridge,
    this.widgetId,
    this.initialKind,
    this.initialConfig,
    this.editAllPinned = false,
  });

  final WidgetConfigBridge bridge;

  /// Truyền sẵn khi mở lại từ trong app (Cài đặt) theo đúng 1 instance; null = tự hỏi native (lần
  /// ghim đầu, qua OS). Bỏ qua khi [editAllPinned] true.
  final int? widgetId;
  final HomeWidgetKind? initialKind;
  final WidgetConfig? initialConfig;

  /// true = mở từ Cài đặt (profile_screen.dart) không qua WidgetConfigActivity native, nên không có
  /// sẵn 1 appWidgetId cụ thể — lúc lưu áp dụng cấu hình cho TẤT CẢ widget đang ghim của
  /// [initialKind] (xem WidgetConfigBridge.getPinnedWidgetIds), không hỏi native getWidgetId/
  /// getWidgetKind (không có Activity nào đứng sau trả lời).
  final bool editAllPinned;

  @override
  ConsumerState<K1WidgetConfigScreen> createState() => _K1WidgetConfigScreenState();
}

class _K1WidgetConfigScreenState extends ConsumerState<K1WidgetConfigScreen> {
  int? _widgetId;
  HomeWidgetKind _previewKind = HomeWidgetKind.overview;
  bool _loadingWidgetId = true;

  late WidgetConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? const WidgetConfig();
    _previewKind = widget.initialKind ?? HomeWidgetKind.overview;
    _resolveWidget();
  }

  Future<void> _resolveWidget() async {
    if (widget.editAllPinned) {
      // Đang sửa widget ĐÃ ghim (không phải ghim mới) — đọc cấu hình đã lưu của 1 id bất kỳ đang
      // ghim để công tắc khởi tạo đúng trạng thái thật, không phải luôn mặc định (WidgetConfig()).
      final kind = widget.initialKind ?? _previewKind;
      final pinnedIds = await widget.bridge.getPinnedWidgetIds(kind);
      final config = pinnedIds.isNotEmpty ? await widget.bridge.loadConfig(pinnedIds.first) : _config;
      if (!mounted) return;
      setState(() {
        _widgetId = widget.widgetId;
        _config = config;
        _loadingWidgetId = false;
      });
      return;
    }
    if (widget.widgetId != null) {
      setState(() {
        _widgetId = widget.widgetId;
        _loadingWidgetId = false;
      });
      return;
    }
    final id = await widget.bridge.getWidgetId();
    final kind = await widget.bridge.getWidgetKind();
    if (!mounted) return;
    setState(() {
      _widgetId = id;
      _previewKind = kind;
      _loadingWidgetId = false;
    });
  }

  Future<void> _onDone() async {
    final kind = widget.initialKind ?? _previewKind;
    if (widget.editAllPinned) {
      final ids = await widget.bridge.getPinnedWidgetIds(kind);
      await widget.bridge.saveConfig(ids, kind, _config);
    } else if (_widgetId != null) {
      await widget.bridge.saveConfig([_widgetId!], kind, _config);
    }
    await widget.bridge.finishConfig(accepted: true);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _onClose() async {
    await widget.bridge.finishConfig(accepted: false);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWidgetId) {
      return GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: GlassColors.ink)),
        ),
      );
    }

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Đóng',
            icon: Icon(LucideIcons.x, color: GlassColors.textPrimary),
            onPressed: _onClose,
          ),
          title: Text(
            'Cấu hình Widget FinMate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: GlassColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: AsyncActionBuilder(
                onPressed: _onDone,
                builder: (_, onTap, running) => FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: GlassColors.ink,
                    foregroundColor: GlassColors.onInk,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onTap,
                  child: running ? const ButtonLoadingIndicator() : const Text('Hoàn tất'),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _SizeSection(selected: _previewKind, onSelected: (k) => setState(() => _previewKind = k)),
              const SizedBox(height: AppSpacing.xl),
              _PreviewSection(kind: _previewKind, config: _config),
              const SizedBox(height: AppSpacing.xl),
              _PrivacySection(
                config: _config,
                onChanged: (c) => setState(() => _config = c),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SourceAccountSection(
                selectedAccountId: _config.sourceAccountId,
                onSelected: (id) => setState(() => _config = _config.copyWith(sourceAccountId: () => id)),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RefreshModeSection(
                mode: _config.refreshMode,
                onChanged: (m) => setState(() => _config = _config.copyWith(refreshMode: m)),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _TipCard(),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _title() => TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: GlassColors.textPrimary);

/// Thẻ kính dùng chung cho mọi khối của màn (nền/viền theo GlassColors, tự đổi sáng/tối).
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(AppSpacing.md)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: GlassColors.glassFill,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: GlassColors.glassBorder),
      ),
      child: child,
    );
  }
}

class _SizeSection extends StatelessWidget {
  const _SizeSection({required this.selected, required this.onSelected});

  final HomeWidgetKind selected;
  final ValueChanged<HomeWidgetKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Chọn kích thước tiện ích', style: _title())),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: AppSpacing.roundedPill),
              child: Text('iOS & Android', style: TextStyle(fontSize: 11, color: GlassColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SizeCard(
                icon: LucideIcons.square,
                title: '2 × 2',
                subtitle: 'Chi an toàn',
                hint: 'Nhỏ gọn, đơn giản',
                selected: selected == HomeWidgetKind.safeSpend,
                onTap: () => onSelected(HomeWidgetKind.safeSpend),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SizeCard(
                icon: LucideIcons.rectangleHorizontal,
                title: '4 × 2',
                subtitle: 'Tổng quan',
                hint: 'Số dư & thao tác',
                badge: 'Khuyến dùng',
                selected: selected == HomeWidgetKind.overview,
                onTap: () => onSelected(HomeWidgetKind.overview),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SizeCard(
                icon: LucideIcons.layoutDashboard,
                title: '4 × 4',
                subtitle: 'Chi tiết',
                hint: 'Dự báo & sổ phụ',
                selected: selected == HomeWidgetKind.detail,
                onTap: () => onSelected(HomeWidgetKind.detail),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String hint;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cỡ $title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedLarge,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: GlassColors.glassFill,
                borderRadius: AppSpacing.roundedLarge,
                border: Border.all(color: selected ? GlassColors.ink : GlassColors.glassBorder, width: selected ? 2 : 1),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: GlassColors.secondarySurface,
                    child: Icon(icon, size: 18, color: GlassColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassColors.textPrimary),
                  ),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: GlassColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: GlassColors.ink, borderRadius: AppSpacing.roundedPill),
                child: Text(badge!, style: TextStyle(fontSize: 10, color: GlassColors.onInk)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends ConsumerWidget {
  const _PreviewSection({required this.kind, required this.config});

  final HomeWidgetKind kind;
  final WidgetConfig config;

  String get _sizeLabel => switch (kind) {
        HomeWidgetKind.safeSpend => '2×2',
        HomeWidgetKind.overview => '4×2',
        HomeWidgetKind.detail => '4×4',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendable = ref.watch(spendableProvider);
    final accounts = kind == HomeWidgetKind.safeSpend ? null : ref.watch(_accountsProvider);
    // Dự báo chỉ làm đẹp thêm cho 4×4: lỗi/đang tải thì hiện "—", không chặn cả xem trước.
    final forecast = kind == HomeWidgetKind.detail ? ref.watch(cashflowForecastProvider) : null;

    Widget body;
    final failed = spendable.hasError ? spendable : (accounts?.hasError ?? false) ? accounts : null;
    if (failed != null && !(failed.hasValue)) {
      body = _PreviewMessage(
        icon: LucideIcons.triangleAlert,
        text: 'Không tải được dữ liệu xem trước.',
        actionLabel: 'Thử lại',
        onAction: () {
          ref.invalidate(spendableProvider);
          ref.invalidate(_accountsProvider);
          ref.invalidate(cashflowForecastProvider);
        },
      );
    } else if (!spendable.hasValue || (accounts != null && !accounts.hasValue)) {
      body = const _PreviewMessage(loading: true, text: 'Đang tải dữ liệu xem trước…');
    } else {
      final data = WidgetPreviewData.compute(
        spendable: spendable.requireValue,
        accounts: accounts?.valueOrNull,
        sourceAccountId: config.sourceAccountId,
        forecastEnd: forecast?.valueOrNull?.endBalanceCents,
      );
      body = switch (kind) {
        HomeWidgetKind.safeSpend => _SafeSpendPreview(data: data, config: config),
        HomeWidgetKind.overview => _OverviewPreview(data: data, config: config),
        HomeWidgetKind.detail => _DetailPreview(data: data, config: config),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Xem trước tương tác thực tế', style: _title())),
            Text('Cỡ $_sizeLabel', style: TextStyle(fontSize: 12, color: GlassColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }
}

String _vnd(BigInt? v) => v == null ? '—' : formatVnd(v);

TextStyle _muted([double size = 11]) => TextStyle(fontSize: size, color: GlassColors.textSecondary);

/// Khung hiển thị 1 trạng thái không có số (đang tải / lỗi) trong vùng xem trước.
class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.text, this.loading = false, this.icon, this.actionLabel, this.onAction});

  final String text;
  final bool loading;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          if (loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.ink))
          else if (icon != null)
            Icon(icon, size: 18, color: GlassColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: GlassColors.textSecondary))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ báo khung này chưa có số thật (người dùng chưa có dữ liệu) — không hiển thị số bịa.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(text, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: GlassColors.textSecondary)),
      );
}

Color _ringColor(int percent) => percent >= 100 ? GlassColors.danger : (percent >= 80 ? GlassColors.warning : GlassColors.success);

class _Ring extends StatelessWidget {
  const _Ring({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = _ringColor(percent);
    return Semantics(
      label: '$percent% ngân sách tháng đã dùng',
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                strokeWidth: 5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Hai nút thao tác của widget — chỉ minh họa, không bấm được.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String label, {required bool filled}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: filled ? GlassColors.ink : GlassColors.secondarySurface,
              borderRadius: AppSpacing.roundedMedium,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: filled ? GlassColors.onInk : GlassColors.textPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: filled ? GlassColors.onInk : GlassColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
    return ExcludeSemantics(
      child: Row(children: [
        pill(LucideIcons.plus, 'Ghi chép', filled: false),
        const SizedBox(width: AppSpacing.sm),
        pill(LucideIcons.qrCode, 'Quét QR', filled: true),
      ]),
    );
  }
}

/// W1 "Chi an toàn" (2×2) — bản Flutter đơn giản hoá của SafeSpendWidget.kt.
class _SafeSpendPreview extends StatelessWidget {
  const _SafeSpendPreview({required this.data, required this.config});

  final WidgetPreviewData data;
  final WidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final over = data.hasBudget && (data.percentUsed ?? 0) >= 100;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 220,
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(over ? LucideIcons.triangleAlert : LucideIcons.shieldCheck, size: 14, color: GlassColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(over ? 'Cần điều chỉnh' : 'FinMate • Chi an toàn', maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.hasBudget ? _vnd(data.perDay) : '—',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: over ? GlassColors.danger : GlassColors.textPrimary),
                          ),
                        ),
                        Text(data.hasBudget ? 'Hôm nay có thể chi tiêu an toàn' : 'Chưa đặt ngân sách', style: _muted()),
                      ],
                    ),
                  ),
                  if (config.aiSuggestionsEnabled && data.hasBudget) ...[
                    const SizedBox(width: 6),
                    _Ring(percent: data.percentUsed ?? 0),
                  ],
                ],
              ),
              if (!data.hasBudget) const _EmptyNote('Chưa có dữ liệu — khung xem trước, không phải số thật.'),
            ],
          ),
        ),
      ),
    );
  }
}

/// W2 "Tổng quan" (4×2) — nội dung theo OverviewWidget.kt.
class _OverviewPreview extends StatelessWidget {
  const _OverviewPreview({required this.data, required this.config});

  final WidgetPreviewData data;
  final WidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final hasAccount = data.balance != null;
    return _Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 14, color: GlassColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'FinMate • ${data.accountLabel ?? 'Tất cả tài khoản'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: GlassColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SỐ DƯ KHẢ DỤNG', style: TextStyle(fontSize: 11, color: GlassColors.textSecondary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_vnd(data.balance), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GlassColors.textPrimary)),
                    ),
                    if (data.hasBudget) ...[
                      Text('Đã chi tháng này: ${_vnd(data.spent)}', style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Chi an toàn: ${_vnd(data.perDay)}/ngày', style: _muted(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (config.aiSuggestionsEnabled && data.hasBudget) ...[
                const SizedBox(width: AppSpacing.sm),
                _Ring(percent: data.percentUsed ?? 0),
              ],
            ],
          ),
          if (config.aiSuggestionsEnabled && !data.hasBudget) Text('Chưa đặt ngân sách tháng', style: _muted()),
          if (!hasAccount) const _EmptyNote('Chưa có tài khoản — khung xem trước, không phải số thật.'),
          const SizedBox(height: AppSpacing.md),
          const _ActionButtons(),
        ],
      ),
    );
  }
}

/// Widget "Chi tiết" (4×4) — số dư + dự báo cuối tháng + hạn mức, theo DetailWidget.kt. Danh sách giao
/// dịch gần đây của widget thật không dựng ở đây (xem ghi chú dưới thẻ).
class _DetailPreview extends StatelessWidget {
  const _DetailPreview({required this.data, required this.config});

  final WidgetPreviewData data;
  final WidgetConfig config;

  @override
  Widget build(BuildContext context) {
    Widget metric(String label, String value, double size) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: GlassColors.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: GlassColors.textPrimary)),
              ),
            ],
          ),
        );
    return _Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FinMate • ${data.accountLabel ?? 'Tất cả tài khoản'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: GlassColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              metric('SỐ DƯ KHẢ DỤNG', _vnd(data.balance), 22),
              const SizedBox(width: AppSpacing.sm),
              metric('DỰ BÁO CUỐI THÁNG', _vnd(data.forecastEnd), 16),
              if (config.aiSuggestionsEnabled && data.hasBudget) ...[
                const SizedBox(width: AppSpacing.sm),
                _Ring(percent: data.percentUsed ?? 0),
              ],
            ],
          ),
          if (data.hasBudget) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Đã chi: ${_vnd(data.spent)} / Ngân sách: ${_vnd(data.income)}', style: _muted(12)),
          ],
          if (data.balance == null) const _EmptyNote('Chưa có tài khoản — khung xem trước, không phải số thật.'),
          const SizedBox(height: AppSpacing.md),
          const _ActionButtons(),
          const SizedBox(height: AppSpacing.sm),
          Text('Giao dịch vừa ghi nhận sẽ hiện trên widget thật.', style: _muted()),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.config, required this.onChanged});

  final WidgetConfig config;
  final ValueChanged<WidgetConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tùy chọn hiển thị & Riêng tư', style: _title()),
        const SizedBox(height: AppSpacing.md),
        _SwitchTile(
          title: 'Gợi ý thông minh từ FinMate AI',
          subtitle: 'Hiển thị cảnh báo trực quan khi chi tiêu vượt 80% định mức an toàn.',
          value: config.aiSuggestionsEnabled,
          onChanged: (v) => onChanged(config.copyWith(aiSuggestionsEnabled: v)),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: GlassColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: GlassColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: GlassColors.ink,
            activeThumbColor: GlassColors.onInk,
          ),
        ],
      ),
    );
  }
}

class _SourceAccountSection extends ConsumerWidget {
  const _SourceAccountSection({required this.selectedAccountId, required this.onSelected});

  final String? selectedAccountId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(_accountsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nguồn tiền hiển thị trên widget', style: _title()),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _AccountChip(label: 'Tất cả tài khoản', selected: selectedAccountId == null, onTap: () => onSelected(null)),
            ...accountsAsync.when(
              data: (accounts) => accounts
                  .map((a) => _AccountChip(
                        label: a.name,
                        selected: selectedAccountId == a.id,
                        onTap: () => onSelected(a.id),
                      ))
                  .toList(),
              loading: () => const [],
              error: (_, __) => const [],
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? GlassColors.ink : GlassColors.glassFill,
            borderRadius: AppSpacing.roundedPill,
            border: Border.all(color: selected ? GlassColors.ink : GlassColors.glassBorder),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? GlassColors.onInk : GlassColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _RefreshModeSection extends StatelessWidget {
  const _RefreshModeSection({required this.mode, required this.onChanged});

  final WidgetRefreshMode mode;
  final ValueChanged<WidgetRefreshMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final batterySaver = mode == WidgetRefreshMode.batterySaver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Chu kỳ tự động làm mới', style: _title())),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: GlassColors.ink),
              onPressed: () => onChanged(batterySaver ? WidgetRefreshMode.immediateAndPeriodic : WidgetRefreshMode.batterySaver),
              child: Text(batterySaver ? 'DÙNG MẶC ĐỊNH' : 'TIẾT KIỆM PIN'),
            ),
          ],
        ),
        _Panel(
          child: Row(
            children: [
              Icon(LucideIcons.refreshCw, size: 18, color: GlassColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  batterySaver
                      ? 'Chỉ làm mới định kỳ mỗi 2 giờ (không làm mới ngay khi có giao dịch mới).'
                      : 'Ngay khi có giao dịch mới & định kỳ mỗi 30 phút.',
                  style: TextStyle(fontSize: 13, color: GlassColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.lightbulb, size: 20, color: GlassColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Mẹo thêm nhanh tiện ích: ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: 'Bạn có thể nhấn giữ khoảng trống hoặc biểu tượng FinMate trên màn hình điện thoại, '
                        'sau đó chọn "Tiện ích / Widgets" để ghim ngay mà không cần mở lại cài đặt này.',
                  ),
                ],
              ),
              style: TextStyle(fontSize: 13, color: GlassColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
