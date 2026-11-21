import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group_extras.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';

const _weekdayLabels = {1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư', 4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ nhật'};

/// Ngày chốt sổ gợi ý để chọn nhanh (0 = cuối tháng); BE nhận 1–28 hoặc null.
const _closingDayChoices = [0, 1, 5, 10, 15, 20, 25, 28];

/// Cài đặt quỹ, ngân sách, thông báo và phê duyệt của nhóm (Figma I7). Chỉ chủ nhóm sửa được, `PUT` thay toàn bộ
/// nên mỗi lần đổi một mục là gửi lại đủ các mục. Cờ thông báo giao dịch mới và tóm tắt tuần hiện mới được LƯU,
/// server chưa gửi thông báo theo hai cờ này (backend ghi chú sẽ làm sau).
class GroupSettingsSection extends ConsumerWidget {
  final String groupId;
  final bool canEdit;
  const GroupSettingsSection({super.key, required this.groupId, required this.canEdit});

  Future<void> _save(BuildContext context, WidgetRef ref, GroupSettingsEntity next) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupsRepositoryProvider).putSettings(groupId, next);
      ref.invalidate(groupSettingsProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt nhóm')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  Future<void> _pickClosingDay(BuildContext context, WidgetRef ref, GroupSettingsEntity s) async {
    final picked = await GlassDialog.choice<int>(
      context,
      title: 'Ngày chốt sổ hàng tháng',
      options: _closingDayChoices,
      labelOf: (d) => d == 0 ? 'Cuối tháng' : 'Ngày $d',
      isSelected: (d) => d == (s.closingDay ?? 0),
    );
    if (picked == null || !context.mounted) return;
    await _save(context, ref, picked == 0 ? s.copyWith(clearClosingDay: true) : s.copyWith(closingDay: picked));
  }

  Future<void> _pickMethod(BuildContext context, WidgetRef ref, GroupSettingsEntity s) async {
    const labels = {'AiOptimized': 'Tự động tối ưu số lượt chuyển khoản', 'Manual': 'Thủ công (tự thống nhất cách trả)'};
    final picked = await GlassDialog.choice<String>(
      context,
      title: 'Phương thức cấn trừ nợ',
      options: labels.keys.toList(),
      labelOf: (k) => labels[k]!,
      isSelected: (k) => k == s.debtSettlementMethod,
    );
    if (picked == null || picked == s.debtSettlementMethod || !context.mounted) return;
    await _save(context, ref, s.copyWith(debtSettlementMethod: picked));
  }

  Future<void> _setApproval(BuildContext context, WidgetRef ref, GroupSettingsEntity s, bool on) async {
    if (!on) {
      await _save(context, ref, s.copyWith(clearApproval: true));
      return;
    }
    final controller = TextEditingController(text: s.requireApprovalAboveCents?.toString() ?? '');
    final amount = await GlassDialog.custom<BigInt>(
      context,
      title: 'Ngưỡng cần duyệt',
      contentBuilder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hóa đơn, chi hoặc rút quỹ từ mức này trở lên do người không phải chủ nhóm tạo sẽ chờ chủ nhóm duyệt.',
            style: GlassTypography.bodySm(color: GlassColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('approval-amount'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Số tiền (đồng)', suffixText: '₫'),
          ),
        ],
      ),
      actionsBuilder: (ctx, setState) => Row(
        children: [
          Expanded(child: GlassGhostButton(onPressed: () => Navigator.pop(ctx), label: 'Hủy')),
          const SizedBox(width: 12),
          Expanded(
            child: GlassPrimaryButton(
              key: const ValueKey('approval-save'),
              label: 'Lưu',
              onPressed: () {
                final value = BigInt.tryParse(controller.text.trim());
                if (value != null && value > BigInt.zero) Navigator.pop(ctx, value);
              },
            ),
          ),
        ],
      ),
    );
    if (amount == null || !context.mounted) return;
    await _save(context, ref, s.copyWith(requireApprovalAboveCents: amount));
  }

  Future<void> _pickWeeklyDay(BuildContext context, WidgetRef ref, GroupSettingsEntity s) async {
    final picked = await GlassDialog.choice<int>(
      context,
      title: 'Gửi tóm tắt vào',
      options: _weekdayLabels.keys.toList(),
      labelOf: (d) => _weekdayLabels[d]!,
      isSelected: (d) => d == s.weeklySummaryDay,
    );
    if (picked == null || picked == s.weeklySummaryDay || !context.mounted) return;
    await _save(context, ref, s.copyWith(weeklySummaryDay: picked));
  }

  Future<void> _pickWeeklyTime(BuildContext context, WidgetRef ref, GroupSettingsEntity s) async {
    final parts = s.weeklySummaryTime.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts.first) ?? 9, minute: int.tryParse(parts.last) ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !context.mounted) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    await _save(context, ref, s.copyWith(weeklySummaryTime: '$hh:$mm'));
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupSettingsProvider(groupId));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
      error: (e, __) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: GlassCard(
          child: Row(
            children: [
              Expanded(child: Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger))),
              TextButton(onPressed: () => ref.invalidate(groupSettingsProvider(groupId)), child: const Text('Thử lại')),
            ],
          ),
        ),
      ),
      data: (s) {
        final approval = s.requireApprovalAboveCents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('CÀI ĐẶT QUỸ & NGÂN SÁCH'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('closing-day'),
                      leading: const Icon(LucideIcons.calendarDays, size: 20),
                      // Một hàng: chữ tự thu nhỏ vừa chỗ còn lại thay vì xuống dòng khi bên phải có "Cuối tháng".
                      title: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Ngày chốt sổ & kết chuyển quỹ', maxLines: 1)),
                      subtitle: const Text('Chu kỳ tự động vào ngày này hàng tháng'),
                      trailing: Text(s.closingDay == null ? 'Cuối tháng' : 'Ngày ${s.closingDay}'),
                      onTap: canEdit ? () => _pickClosingDay(context, ref, s) : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const ValueKey('debt-method'),
                      leading: const Icon(LucideIcons.wandSparkles, size: 20),
                      title: const Text('Phương thức cấn trừ nợ'),
                      subtitle: Text(s.debtSettlementMethod == 'Manual' ? 'Thủ công' : 'Tự động tối ưu'),
                      trailing: canEdit ? const Icon(LucideIcons.chevronRight, size: 18) : null,
                      onTap: canEdit ? () => _pickMethod(context, ref, s) : null,
                    ),
                  ],
                ),
              ),
            ),
            _section('THÔNG BÁO & PHÊ DUYỆT'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeTrackColor: GlassColors.ink,
                      activeThumbColor: GlassColors.onInk,
                      key: const ValueKey('notify-new-transaction'),
                      title: const Text('Thông báo khi có giao dịch mới'),
                      value: s.notifyOnNewTransaction,
                      onChanged: canEdit ? (v) => _save(context, ref, s.copyWith(notifyOnNewTransaction: v)) : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeTrackColor: GlassColors.ink,
                      activeThumbColor: GlassColors.onInk,
                      key: const ValueKey('require-approval'),
                      title: const Text('Yêu cầu chủ nhóm duyệt khoản lớn'),
                      subtitle: approval == null ? null : Text('Từ ${formatVnd(approval)} trở lên'),
                      value: approval != null,
                      onChanged: canEdit ? (v) => _setApproval(context, ref, s, v) : null,
                    ),
                    if (approval != null && canEdit)
                      ListTile(
                        key: const ValueKey('edit-approval'),
                        dense: true,
                        title: const Text('Đổi ngưỡng cần duyệt'),
                        trailing: const Icon(LucideIcons.pencil, size: 16),
                        onTap: () => _setApproval(context, ref, s, true),
                      ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeTrackColor: GlassColors.ink,
                      activeThumbColor: GlassColors.onInk,
                      key: const ValueKey('weekly-summary'),
                      title: const Text('Báo cáo tóm tắt tài chính nhóm mỗi tuần'),
                      value: s.weeklySummary,
                      onChanged: canEdit ? (v) => _save(context, ref, s.copyWith(weeklySummary: v)) : null,
                    ),
                    if (s.weeklySummary) ...[
                      ListTile(
                        key: const ValueKey('weekly-day'),
                        dense: true,
                        title: const Text('Ngày gửi'),
                        trailing: Text(_weekdayLabels[s.weeklySummaryDay] ?? 'Thứ Hai'),
                        onTap: canEdit ? () => _pickWeeklyDay(context, ref, s) : null,
                      ),
                      ListTile(
                        key: const ValueKey('weekly-time'),
                        dense: true,
                        title: const Text('Giờ gửi (giờ Việt Nam)'),
                        trailing: Text(s.weeklySummaryTime),
                        onTap: canEdit ? () => _pickWeeklyTime(context, ref, s) : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Chỉ chủ nhóm mới đổi được các cài đặt này.', style: GlassTypography.bodySm(color: GlassColors.textMuted)),
              ),
          ],
        );
      },
    );
  }
}
