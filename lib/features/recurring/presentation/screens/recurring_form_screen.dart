import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Màn G8: tạo/sửa khoản định kỳ (thay RecurringFormDialog). Chiều tiền chỉ chọn lúc tạo (API không cho đổi).
/// Figma có "Hàng quý", "Nhắc trước 3 ngày" và "Tự động tạo giao dịch" nhưng BE chưa có trường tương ứng nên không hiển thị;
/// "Tạm dừng khoản này" ánh xạ sang pause/resume và chỉ hiện khi sửa khoản đang hoạt động/tạm dừng.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.item});

  final RecurringItemEntity? item;

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _counterparty = TextEditingController(text: widget.item?.counterpartyKey ?? '');
  late final _amount = TextEditingController(text: widget.item == null ? '' : formatAmountDigits(widget.item!.amountCents));
  late RecurringDirection _direction = widget.item?.direction ?? RecurringDirection.outflow;
  late RecurringCadence _cadence = widget.item?.cadence ?? RecurringCadence.monthly;
  late DateTime? _nextDueDate = widget.item?.nextDueDate;
  late String? _categoryId = widget.item?.categoryId;
  late String? _accountId = widget.item?.financialAccountId;
  late bool _paused = widget.item?.status == RecurringStatus.paused;
  // Trả góp: chỉ nhập khi tạo mới (sửa kỳ cuối cần PATCH riêng, chưa làm ở màn này).
  final _total = TextEditingController();
  final _prepaid = TextEditingController();
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.item != null;
  bool get _canPause => widget.item?.status == RecurringStatus.active || widget.item?.status == RecurringStatus.paused;

  @override
  void dispose() {
    _name.dispose();
    _counterparty.dispose();
    _amount.dispose();
    _total.dispose();
    _prepaid.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = parseAmountInput(_amount.text);
    final due = _nextDueDate;
    if (name.isEmpty) return setState(() => _error = 'Vui lòng nhập tên');
    if (amount == null) return setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
    if (due == null) return setState(() => _error = 'Vui lòng chọn ngày đến hạn tiếp theo');

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(recurringItemsControllerProvider.notifier);
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final item = widget.item;
      if (item == null) {
        await controller.create(
          direction: _direction,
          name: name,
          counterpartyName: _counterparty.text.trim(),
          amountCents: amount,
          cadence: _cadence,
          nextDueDate: due,
          categoryId: _categoryId,
          financialAccountId: _accountId,
          totalOccurrences: int.tryParse(_total.text.trim()),
          prepaidOccurrences: int.tryParse(_prepaid.text.trim()),
        );
      } else {
        await controller.update(
          id: item.id,
          name: name,
          amountCents: amount,
          cadence: _cadence,
          nextDueDate: due,
          categoryId: _categoryId,
          financialAccountId: _accountId,
        );
        final wasPaused = item.status == RecurringStatus.paused;
        if (_canPause && _paused != wasPaused) {
          await (_paused ? controller.pause(item.id) : controller.resume(item.id));
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(_isEdit ? 'Đã lưu khoản định kỳ.' : 'Đã tạo khoản định kỳ.')));
      if (mounted) {
        navigator.maybePop();
        setState(() => _saving = false);
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Chọn một mục từ danh sách; trả (id,) với id null = "không chọn"; trả null = đóng mà không chọn gì.
  Future<(String?,)?> _pick(BuildContext context, String title, List<(String, String)> options, String? current) {
    return showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(title, style: GlassTypography.headlineSm(color: Theme.of(ctx).colorScheme.onSurface)),
              ),
              ListTile(
                title: const Text('Không chọn'),
                selected: current == null,
                onTap: () => Navigator.pop(ctx, (null,)),
              ),
              for (final o in options)
                ListTile(
                  title: Text(o.$2),
                  selected: o.$1 == current,
                  trailing: o.$1 == current ? const Icon(LucideIcons.check, size: 18) : null,
                  onTap: () => Navigator.pop(ctx, (o.$1,)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint, String? suffix, Widget? prefix}) => InputDecoration(
        hintText: hint,
        suffixText: suffix,
        prefixIcon: prefix,
        filled: true,
        fillColor: GlassColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide(color: GlassColors.fieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide(color: GlassColors.fieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide(color: GlassColors.ink, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: GlassTypography.labelCaps(color: GlassColors.textSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final inflow = _direction == RecurringDirection.inflow;
    // Giá trị đã lưu có thể không còn trong danh sách (đã xóa/lọc): tránh DropdownButton assert.
    final categoryValue = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final accountValue = accounts.any((a) => a.id == _accountId) ? _accountId : null;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: _isEdit ? 'Sửa chi phí định kỳ' : 'Thêm chi phí định kỳ',
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
              child: Text('Hủy', style: GlassTypography.bodyMd(color: GlassColors.slateAnchor)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    GlassCard(
                      level: 2,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassBadge(text: inflow ? 'KHOẢN THU CỐ ĐỊNH' : 'KHOẢN CHI CỐ ĐỊNH'),
                          if (!_isEdit) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (final d in RecurringDirection.values) ...[
                                  if (d != RecurringDirection.values.first) const SizedBox(width: 8),
                                  Expanded(
                                    child: _Chip(
                                      key: ValueKey('direction-${d.name}'),
                                      label: d.label,
                                      selected: _direction == d,
                                      expand: true,
                                      onTap: () => setState(() => _direction = d),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          _label('SỐ TIỀN THANH TOÁN'),
                          TextField(
                            key: const ValueKey('recurring-amount'),
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorInputFormatter()],
                            style: GlassTypography.displayHero().copyWith(fontSize: 26),
                            decoration: _decoration(hint: '0', suffix: 'VND').copyWith(
                              hintStyle: GlassTypography.displayHero(color: GlassColors.textMuted).copyWith(fontSize: 26),
                              suffixStyle: GlassTypography.bodyMd(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _label(inflow ? 'TÊN KHOẢN THU' : 'TÊN KHOẢN CHI'),
                          TextField(
                            key: const ValueKey('recurring-name'),
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            style: GlassTypography.bodyLg(color: GlassColors.textPrimary),
                            decoration: _decoration(
                              hint: 'Ví dụ: Tiền nhà, Lương tháng',
                              prefix: Icon(LucideIcons.pencilLine, size: 18, color: GlassColors.textSecondary),
                            ),
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: 16),
                            _label('NGƯỜI NHẬN/TRẢ (TÙY CHỌN)'),
                            TextField(
                              key: const ValueKey('recurring-counterparty'),
                              controller: _counterparty,
                              style: GlassTypography.bodyLg(color: GlassColors.textPrimary),
                              decoration: _decoration(hint: 'Ví dụ: Netflix'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categories.isNotEmpty) ...[
                            _label('DANH MỤC (TÙY CHỌN)'),
                            _PickerTile(
                              key: const ValueKey('recurring-category'),
                              icon: LucideIcons.tag,
                              title: categories.where((c) => c.id == categoryValue).map((c) => c.name).firstOrNull ?? 'Không chọn danh mục',
                              onTap: () async {
                                final r = await _pick(context, 'Chọn danh mục', [for (final c in categories) (c.id, c.name)], categoryValue);
                                if (r != null) setState(() => _categoryId = r.$1);
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          _label('CHU KỲ LẶP LẠI'),
                          // Một hàng, chia đều bề rộng để 3 chu kỳ không xuống dòng ở máy hẹp.
                          Row(
                            children: [
                              for (final c in RecurringCadence.values) ...[
                                if (c != RecurringCadence.values.first) const SizedBox(width: 8),
                                Expanded(
                                  child: _Chip(
                                    key: ValueKey('cadence-${c.name}'),
                                    label: c.label,
                                    selected: _cadence == c,
                                    expand: true,
                                    compact: true,
                                    onTap: () => setState(() => _cadence = c),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          _label('NGÀY ĐẾN HẠN TIẾP THEO'),
                          Semantics(
                            button: true,
                            label: 'Chọn ngày đến hạn tiếp theo',
                            child: InkWell(
                              key: const ValueKey('recurring-date'),
                              borderRadius: GlassRadius.roundedInput,
                              onTap: _pickDate,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 56),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: GlassColors.fieldFill,
                                  borderRadius: GlassRadius.roundedInput,
                                  border: Border.all(color: GlassColors.fieldBorder),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.calendar, size: 18, color: GlassColors.slateAnchor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _nextDueDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(_nextDueDate!),
                                            style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          Text('Lặp ${_cadence.label.toLowerCase()}', style: GlassTypography.bodySm()),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: 20),
                            _label('TRẢ GÓP (TÙY CHỌN)'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey('recurring-total'),
                                    controller: _total,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Tổng số kỳ', hintText: 'vd 12'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey('recurring-prepaid'),
                                    controller: _prepaid,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Đã trả trước', hintText: 'vd 0'),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Để trống nếu khoản này lặp mãi. Có số kỳ thì dự báo ngừng trừ tiền sau kỳ cuối.', style: GlassTypography.bodySm()),
                            ),
                          ],
                          if (accounts.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _label('NGUỒN THANH TOÁN MẶC ĐỊNH (TÙY CHỌN)'),
                            _PickerTile(
                              key: const ValueKey('recurring-account'),
                              icon: LucideIcons.wallet,
                              title: accounts.where((a) => a.id == accountValue).map((a) => a.name).firstOrNull ?? 'Không chọn nguồn tiền',
                              onTap: () async {
                                final r = await _pick(context, 'Chọn nguồn thanh toán', [for (final a in accounts) (a.id, a.name)], accountValue);
                                if (r != null) setState(() => _accountId = r.$1);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isEdit && _canPause) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                        child: Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile.adaptive(
                            key: const ValueKey('recurring-paused'),
                            contentPadding: EdgeInsets.zero,
                            title: Text('Tạm dừng khoản này', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text('Khoản tạm dừng không được tính vào dự báo.', style: GlassTypography.bodySm()),
                            value: _paused,
                            activeThumbColor: GlassColors.onInk,
                            activeTrackColor: GlassColors.ink,
                            onChanged: _saving ? null : (v) => setState(() => _paused = v),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Ngoài ListView để lỗi luôn thấy được ngay trên nút Lưu, không bị cuộn khuất.
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: GlassTypography.bodyMd(color: GlassColors.danger)),
                  ),
                ),
              GlassBottomDock(
                actions: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassPrimaryButton(
                        key: const ValueKey('recurring-save'),
                        label: 'Lưu khoản định kỳ',
                        icon: LucideIcons.circleCheck,
                        loading: _saving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 10),
                      GlassSecondaryButton(label: 'Hủy bỏ', onPressed: _saving ? null : () => Navigator.of(context).maybePop()),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip chọn một giá trị (chu kỳ/chiều tiền): vùng chạm >= 48dp, mục đang chọn dùng token activeFill/activeFg.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap, this.expand = false, this.compact = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// true: giãn đều trong Row/Expanded; false: ôm sát chữ trong Wrap. Container có `alignment` luôn giãn hết bề rộng nên chỉ đặt khi cần.
  final bool expand;

  /// Nhỏ gọn hơn (cao 44, chữ 13, đệm hẹp) để xếp nhiều chip trên một hàng.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: GlassRadius.roundedPill,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 44 : 48),
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 18, vertical: expand ? 0 : 14),
          alignment: expand ? Alignment.center : null,
          decoration: BoxDecoration(
            color: selected ? GlassColors.activeFill : GlassColors.fieldFill,
            borderRadius: GlassRadius.roundedPill,
            border: Border.all(color: selected ? GlassColors.activeBorder : GlassColors.fieldBorder),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GlassTypography.bodyMd(color: selected ? GlassColors.activeFg : GlassColors.textSecondary).copyWith(fontWeight: FontWeight.w600, fontSize: compact ? 13 : null),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô chọn dạng thẻ (icon + giá trị + mũi tên) mở danh sách chọn, theo kiểu hàng "Danh mục chi tiêu" trong Figma G8.
class _PickerTile extends StatelessWidget {
  const _PickerTile({super.key, required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: GlassRadius.roundedInput,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: GlassColors.fieldFill,
            borderRadius: GlassRadius.roundedInput,
            border: Border.all(color: GlassColors.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: GlassColors.activeFill, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: GlassColors.activeFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
