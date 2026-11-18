import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/home_widget/data/widget_config_bridge.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';

final _accountsProvider = FutureProvider<List<FinancialAccount>>(
  (ref) => ref.watch(accountsRepositoryProvider).getAccounts(),
);

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
      return Theme(
        data: AppTheme.lightTheme,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Màn này được thiết kế với màu "Light"-suffixed (dùng cho entrypoint độc lập
    // widgetConfigMain). Ép theme light cục bộ để khi bị push vào app chính (đang dark) vẫn hiện
    // đúng như bản gốc, không bị chữ tối-trên-nền-tối.
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _onClose),
          title: const Text('Cấu hình Widget FinMate'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimaryLight,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: _onDone,
                child: const Text('Hoàn tất'),
              ),
            ),
          ],
        ),
        body: ListView(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Chọn kích thước tiện ích', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLightSubtle,
                borderRadius: AppSpacing.roundedPill,
              ),
              child: const Text('iOS & Android', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SizeCard(
                icon: Icons.crop_square,
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
                icon: Icons.view_agenda_outlined,
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
                icon: Icons.dashboard_outlined,
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedLarge,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: badge != null ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceLightSubtle,
              borderRadius: AppSpacing.roundedLarge,
              border: Border.all(
                color: selected ? AppColors.textPrimaryLight : AppColors.borderLight,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceLight,
                  child: Icon(icon, size: 18, color: AppColors.textPrimaryLight),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textPrimaryLight,
                borderRadius: AppSpacing.roundedPill,
              ),
              child: Text(badge!, style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.kind, required this.config});

  final HomeWidgetKind kind;
  final WidgetConfig config;

  String get _sizeLabel => switch (kind) {
        HomeWidgetKind.safeSpend => '2×2',
        HomeWidgetKind.overview => '4×2',
        HomeWidgetKind.detail => '4×4',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Xem trước tương tác thực tế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Cỡ $_sizeLabel', style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        switch (kind) {
          HomeWidgetKind.safeSpend => const _SafeSpendPreview(),
          HomeWidgetKind.overview => _OverviewPreview(config: config),
          HomeWidgetKind.detail => const _DetailPreview(),
        },
      ],
    );
  }
}

/// Preview W1 "Chi an toàn" (2×2) — bản Flutter đơn giản hoá của SafeSpendWidget.kt (chỉ đổ bóng
/// hình dáng, không cần khớp pixel-for-pixel), khớp card đầu tiên trong w1_states.png.
class _SafeSpendPreview extends StatelessWidget {
  const _SafeSpendPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.textMutedLight),
              SizedBox(width: 6),
              Text('FinMate • Chi an toàn', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('120.000 đ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text(
            'Hôm nay có thể chi tiêu an toàn',
            style: TextStyle(fontSize: 11, color: AppColors.textMutedLight),
          ),
        ],
      ),
    );
  }
}

/// Preview W2 "Tổng quan" (4×2) — giữ nguyên nội dung gốc đã có từ trước (chip tài khoản, số dư,
/// gợi ý AI, 2 nút thao tác).
class _OverviewPreview extends StatelessWidget {
  const _OverviewPreview({required this.config});

  final WidgetConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Tất cả tài khoản', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16),
              const Spacer(),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.safe, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Vừa đồng bộ', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('HẠN MỨC KHẢ DỤNG HÔM NAY', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('42.850.000 đ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          if (config.aiSuggestionsEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: AppSpacing.roundedMedium),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('FinMate AI: Bạn đã tiêu 62% ngân sách tuần', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ghi nhanh'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.textPrimaryLight),
                onPressed: null,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Quét mã QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Preview W3 "Chi tiết" (4×4) — card cao hơn 4×2: số dư + dự báo cuối tháng + vài dòng giao dịch
/// gần đây (dữ liệu tĩnh cho mục đích xem trước), khớp hình dáng w_4x4_detail.png.
class _DetailPreview extends StatelessWidget {
  const _DetailPreview();

  static const _rows = [
    (icon: Icons.restaurant, label: 'Ăn uống', amount: '-85.000 đ'),
    (icon: Icons.local_gas_station, label: 'Xăng xe', amount: '-120.000 đ'),
    (icon: Icons.shopping_bag_outlined, label: 'Mua sắm', amount: '-350.000 đ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HẠN MỨC KHẢ DỤNG HÔM NAY', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('42.850.000 đ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Dự báo cuối tháng: ~38.200.000 đ', style: TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
          const SizedBox(height: AppSpacing.md),
          const Text('Giao dịch gần đây', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(row.icon, size: 16, color: AppColors.textSecondaryLight),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(row.label, style: const TextStyle(fontSize: 13))),
                  Text(row.amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ghi nhanh'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.textPrimaryLight),
                onPressed: null,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Quét mã QR'),
              ),
            ],
          ),
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
        const Text('Tùy chọn hiển thị & Riêng tư', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.textPrimaryLight),
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
        const Text('Nguồn tiền hiển thị trên widget', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimaryLight : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedPill,
          border: Border.all(color: selected ? AppColors.textPrimaryLight : AppColors.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimaryLight),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Chu kỳ tự động làm mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            TextButton(
              onPressed: () => onChanged(batterySaver ? WidgetRefreshMode.immediateAndPeriodic : WidgetRefreshMode.batterySaver),
              child: Text(batterySaver ? 'DÙNG MẶC ĐỊNH' : 'TIẾT KIỆM PIN'),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceLightSubtle,
            borderRadius: AppSpacing.roundedLarge,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync, size: 18, color: AppColors.textSecondaryLight),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  batterySaver
                      ? 'Chỉ làm mới định kỳ mỗi 2 giờ (không làm mới ngay khi có giao dịch mới).'
                      : 'Ngay khi có giao dịch mới & định kỳ mỗi 30 phút.',
                  style: const TextStyle(fontSize: 13),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle,
        borderRadius: AppSpacing.roundedLarge,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.warning),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Mẹo thêm nhanh tiện ích: ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: 'Bạn có thể nhấn giữ khoảng trống hoặc biểu tượng FinMate trên màn hình điện thoại, '
                        'sau đó chọn "Tiện ích / Widgets" để ghim ngay mà không cần mở lại cài đặt này.',
                  ),
                ],
              ),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }
}
