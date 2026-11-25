import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Kết quả sheet lọc: đúng những gì TransactionController hỗ trợ (loại, chờ duyệt, khoảng ngày).
class TransactionFilterResult {
  final TransactionType? type;
  final bool draftsOnly;

  /// null = không lọc ngày (tháng hiện tại)
  final DateTimeRange? range;

  const TransactionFilterResult({
    this.type,
    this.draftsOnly = false,
    this.range,
  });
}

class TransactionsFilterSheet extends StatefulWidget {
  final TransactionFilterResult initial;

  const TransactionsFilterSheet({super.key, required this.initial});

  static Future<TransactionFilterResult?> show(
    BuildContext context,
    TransactionFilterResult initial,
  ) => showModalBottomSheet<TransactionFilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionsFilterSheet(initial: initial),
  );

  @override
  State<TransactionsFilterSheet> createState() =>
      _TransactionsFilterSheetState();
}

class _TransactionsFilterSheetState extends State<TransactionsFilterSheet> {
  static const _types = <(String, TransactionType?)>[
    ('Tất cả', null),
    ('Chi tiêu', TransactionType.expense),
    ('Thu nhập', TransactionType.income),
    ('Chuyển tiền', TransactionType.transfer),
  ];

  late TransactionType? _type = widget.initial.type;
  late bool _drafts = widget.initial.draftsOnly;
  late DateTimeRange? _range = widget.initial.range;

  static DateTimeRange _month(DateTime m) => DateTimeRange(
    start: DateTime(m.year, m.month),
    end: DateTime(m.year, m.month + 1, 0),
  );

  static bool _same(DateTimeRange? a, DateTimeRange b) =>
      a != null &&
      a.start.year == b.start.year &&
      a.start.month == b.start.month &&
      a.start.day == b.start.day &&
      a.end.year == b.end.year &&
      a.end.month == b.end.month &&
      a.end.day == b.end.day;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ?? _month(now),
      helpText: 'Chọn khoảng thời gian',
      saveText: 'Áp dụng',
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _reset() => setState(() {
    _type = null;
    _drafts = false;
    _range = null;
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final presets = <(String, DateTimeRange)>[
      ('Tháng này', _month(now)),
      ('Tháng trước', _month(DateTime(now.year, now.month - 1))),
      (
        'Năm nay',
        DateTimeRange(start: DateTime(now.year), end: DateTime(now.year, 12, 31)),
      ),
      (
        'Năm trước',
        DateTimeRange(
          start: DateTime(now.year - 1),
          end: DateTime(now.year - 1, 12, 31),
        ),
      ),
    ];
    final effective = _range ?? _month(now);
    final isCustom = !presets.any((p) => _same(effective, p.$2));
    final f = DateFormat('dd/MM/yyyy');
    // Chế độ Chờ duyệt bỏ qua loại và ngày (controller không áp dụng), nên làm mờ hai nhóm đó
    final dim = _drafts;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: GlassCard(
            level: 3,
            padding: const EdgeInsets.all(17),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Bộ lọc giao dịch',
                          style: GlassTypography.headlineSm(),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('filter-close'),
                      tooltip: 'Đóng',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: GlassColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                Text(
                  'Tùy chỉnh tiêu chí tra cứu giao dịch',
                  style: GlassTypography.bodySm(),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('Trạng thái', LucideIcons.badgeCheck, [
                          _chip(
                            'Đã xác nhận',
                            !_drafts,
                            () => setState(() => _drafts = false),
                            key: const ValueKey('filter-status-confirmed'),
                          ),
                          _chip(
                            'Chờ duyệt',
                            _drafts,
                            () => setState(() => _drafts = true),
                            key: const ValueKey('filter-status-draft'),
                          ),
                        ]),
                        Opacity(
                          opacity: dim ? 0.4 : 1,
                          child: IgnorePointer(
                            ignoring: dim,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _section(
                                  'Khoảng thời gian',
                                  LucideIcons.calendar,
                                  [
                                    for (final p in presets)
                                      _chip(
                                        p.$1,
                                        !isCustom && _same(effective, p.$2),
                                        () => setState(() => _range = p.$2),
                                      ),
                                    _chip(
                                      'Tùy chọn',
                                      isCustom,
                                      _pickCustom,
                                      key: const ValueKey('filter-range-custom'),
                                    ),
                                  ],
                                  footer:
                                      '${f.format(effective.start)} – ${f.format(effective.end)}',
                                ),
                                _section(
                                  'Loại giao dịch',
                                  LucideIcons.arrowLeftRight,
                                  [
                                    for (final (label, type) in _types)
                                      _chip(
                                        label,
                                        _type == type,
                                        () => setState(() => _type = type),
                                        key: ValueKey(
                                          'filter-type-${type?.name ?? 'all'}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassSecondaryButton(
                        label: 'Đặt lại',
                        onPressed: _reset,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GlassPrimaryButton(
                        label: 'Áp dụng',
                        icon: LucideIcons.check,
                        onPressed: () => Navigator.of(context).pop(
                          TransactionFilterResult(
                            type: _type,
                            draftsOnly: _drafts,
                            range: _range,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    List<Widget> chips, {
    String? footer,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: GlassColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTypography.bodyMd().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (footer != null) ...[
          const SizedBox(height: 8),
          Text(footer, style: GlassTypography.bodySm()),
        ],
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap, {Key? key}) =>
      Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: GlassRadius.roundedPill,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? GlassColors.activeFill : GlassColors.glassFill,
                borderRadius: GlassRadius.roundedPill,
                border: Border.all(
                  color: selected
                      ? GlassColors.activeBorder
                      : GlassColors.glassBorder,
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GlassTypography.bodyMd(
                    color: selected
                        ? GlassColors.activeFg
                        : GlassColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
