import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/assistant/data/agent_memory_repository.dart';
import 'package:finmate/features/assistant/domain/agent_memory.dart';

/// Màu nhãn của từng sở thích theo Figma E3 (nền nhãn, chữ nhãn, chấm). Không có token tương đương trong AppColors.
typedef _PillStyle = ({Color bg, Color fg, Color dot});

const _pillStyles = <String, _PillStyle>{
  'preferred_method': (
    bg: Color(0xFFCFE5FF),
    fg: Color(0xFF001D33),
    dot: Color(0xFF33628B),
  ),
  'eating_out_weekends': (
    bg: Color(0xFFFFD9E4),
    fg: Color(0xFF31101E),
    dot: Color(0xFF633B4A),
  ),
  'notification_quiet_hours': (
    bg: Color(0xFFA3D0FF),
    fg: Color(0xFF295982),
    dot: Color(0xFF33628B),
  ),
  'communication_tone': (
    bg: Color(0xFFE6EEFF),
    fg: Color(0xFF0D1C2E),
    dot: Color(0xFF45464C),
  ),
};
const _fallbackPill = (
  bg: Color(0xFFE6EEFF),
  fg: Color(0xFF0D1C2E),
  dot: Color(0xFF45464C),
);
const _dividerColor = Color(0x99D5E3FC);

/// Màn E3: Bộ nhớ AI (khớp Figma). BE chỉ cho đặt 4 sở thích ([agentMemorySlots]); người dùng xem, sửa, xóa từng mục hoặc xóa hết.
/// Ô tìm kiếm lọc trên 4 sở thích; chip Tất cả/Đã đặt/Chưa đặt thay cho tab Thu nhập/Chi tiêu/Quy tắc vì BE chưa phân loại.
/// Nguồn ghi nhớ trong Figma được thay bằng ngày cập nhật thật; độ tin cậy chưa có dữ liệu nên không hiển thị.
class AiMemoryScreen extends ConsumerStatefulWidget {
  const AiMemoryScreen({super.key});

  @override
  ConsumerState<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

enum _Filter { all, set, unset }

class _AiMemoryScreenState extends ConsumerState<AiMemoryScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  /// Khớp ô tìm kiếm (theo tên hoặc nội dung, không phân biệt hoa thường) và chip lọc đang chọn.
  bool _matches(String title, AgentMemoryEntry? entry) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !title.toLowerCase().contains(q) &&
        !(entry?.value.toLowerCase().contains(q) ?? false))
      return false;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.set => entry != null,
      _Filter.unset => entry == null,
    };
  }

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AgentMemorySlot slot,
    String? current,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditDialog(slot: slot, initial: current ?? ''),
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(agentMemoryRepositoryProvider).put(slot.key, value);
      ref.invalidate(agentMemoryProvider);
      if (context.mounted) _toast(context, 'Đã lưu ghi nhớ.');
    } on Object catch (e) {
      if (context.mounted) _toast(context, errorMessage(e));
    }
  }

  /// "Thêm ghi nhớ": BE chỉ nhận 4 khóa nên chọn trong các sở thích chưa đặt rồi nhập giá trị.
  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<AgentMemorySlot> free,
  ) async {
    final slot = await showModalBottomSheet<AgentMemorySlot>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Chọn sở thích muốn thêm',
                style: AppTypography.h3(sheet),
              ),
            ),
            for (final s in free)
              ListTile(
                minTileHeight: 52,
                title: Text(s.label),
                onTap: () => Navigator.pop(sheet, s),
              ),
          ],
        ),
      ),
    );
    if (slot == null || !context.mounted) return;
    await _edit(context, ref, slot, null);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String key) async {
    try {
      await ref.read(agentMemoryRepositoryProvider).delete(key);
      ref.invalidate(agentMemoryProvider);
      if (context.mounted)
        _toast(context, 'Đã xóa ghi nhớ này khỏi bộ nhớ AI.');
    } on Object catch (e) {
      if (context.mounted) _toast(context, errorMessage(e));
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa toàn bộ bộ nhớ AI?'),
        content: const Text(
          'Trợ lý AI FinMate sẽ quên mọi sở thích và ngữ cảnh trò chuyện của bạn. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(agentMemoryRepositoryProvider).deleteAll();
      ref.invalidate(agentMemoryProvider);
      if (context.mounted) _toast(context, 'Đã xóa sạch bộ nhớ AI.');
    } on Object catch (e) {
      if (context.mounted) _toast(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(agentMemoryProvider);
    final hasAny = memory.valueOrNull?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ nhớ FinMate AI'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(
            icon: LucideIcons.arrowLeft,
            size: 40,
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          if (hasAny)
            Tooltip(
              message: 'Xóa toàn bộ',
              child: TextButton.icon(
                onPressed: () => _clearAll(context, ref),
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 14,
                  color: AppColors.danger,
                ),
                label: const Text(
                  'Xóa tất cả',
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(agentMemoryProvider.future),
          child: memory.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  errorMessage(e),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(agentMemoryProvider),
                    child: const Text('Thử lại'),
                  ),
                ),
              ],
            ),
            data: (entries) => _content(context, ref, entries),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    List<AgentMemoryEntry> entries,
  ) {
    final byKey = {for (final e in entries) e.key: e};
    final known = {for (final s in agentMemorySlots) s.key};
    final unknown = entries.where((e) => !known.contains(e.key));
    final free = [
      for (final s in agentMemorySlots)
        if (!byKey.containsKey(s.key)) s,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _banner(context, entries.isEmpty),
        const SizedBox(height: 16),
        _searchBar(context),
        const SizedBox(height: 8),
        _filterChips(
          context,
          all: agentMemorySlots.length + unknown.length,
          set: entries.length,
          unset: free.length,
        ),
        const SizedBox(height: 12),
        for (final slot in agentMemorySlots)
          if (_matches(slot.label, byKey[slot.key]))
            _card(
              context,
              ref,
              memoryKey: slot.key,
              title: slot.label,
              entry: byKey[slot.key],
              onEdit: () => _edit(context, ref, slot, byKey[slot.key]?.value),
            ),
        for (final e in unknown)
          if (_matches(e.key, e))
            _card(context, ref, memoryKey: e.key, title: e.key, entry: e),
        if (![
          for (final s in agentMemorySlots)
            if (_matches(s.label, byKey[s.key])) s,
          for (final e in unknown)
            if (_matches(e.key, e)) e,
        ].isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Không có ghi nhớ phù hợp.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context),
            ),
          ),
        if (free.isNotEmpty) ...[
          const SizedBox(height: 4),
          _addButton(context, () => _add(context, ref, free)),
        ],
        const SizedBox(height: 24),
        const Center(child: _FooterNote()),
      ],
    );
  }

  Widget _searchBar(BuildContext context) {
    return TextField(
      key: const ValueKey('memory-search'),
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm thông tin đã lưu...',
        prefixIcon: const Icon(LucideIcons.search, size: 16),
        filled: true,
        fillColor: AppColors.inset(context, 0.55),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.roundedPill,
          borderSide: BorderSide(color: AppColors.insetBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedPill,
          borderSide: BorderSide(color: AppColors.insetBorder(context)),
        ),
      ),
    );
  }

  Widget _filterChips(
    BuildContext context, {
    required int all,
    required int set,
    required int unset,
  }) {
    Widget chip(_Filter f, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: ValueKey('memory-filter-${f.name}'),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColors.activeFg(context)
                : AppColors.textSecondary(context),
          ),
          selectedColor: AppColors.activeFill(context),
          backgroundColor: AppColors.chipFill(context),
          onSelected: (_) => setState(() => _filter = f),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_Filter.all, 'Tất cả ($all)'),
          chip(_Filter.set, 'Đã đặt ($set)'),
          chip(_Filter.unset, 'Chưa đặt ($unset)'),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, bool empty) {
    return LiquidGlassCard(
      variant: LiquidGlassVariant.iridescentHero,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFA3D0FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.brain,
              size: 20,
              color: Color(0xFF0D1C2E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tự động học & ghi nhớ',
                  style: AppTypography.h2(
                    context,
                  ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  empty
                      ? 'Bộ nhớ AI đang trống. Thêm sở thích để AI tư vấn đúng ý bạn hơn.'
                      : 'AI chỉ dùng những gì bạn đặt ở đây. Bạn có toàn quyền sửa hoặc xóa.',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref, {
    required String memoryKey,
    required String title,
    AgentMemoryEntry? entry,
    VoidCallback? onEdit,
  }) {
    final pill = _pillStyles[memoryKey] ?? _fallbackPill;
    final updated = entry == null
        ? 'Chưa có ghi nhớ'
        : 'Cập nhật ${DateFormat('dd/MM/yyyy').format(entry.updatedAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pill.bg,
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: pill.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: pill.dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry?.value ?? 'Chưa đặt',
                        style: AppTypography.body(context).copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          height: 1.4,
                          color: entry == null
                              ? AppColors.textMuted(context)
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry != null)
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    color: AppColors.textMuted(context),
                    tooltip: 'Xóa: $title',
                    onPressed: () => _delete(context, ref, memoryKey),
                  ),
              ],
            ),
            const Divider(height: 12, color: _dividerColor),
            Row(
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 12,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    updated,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(
                      entry == null ? LucideIcons.plus : LucideIcons.pencil,
                      size: 16,
                    ),
                    color: AppColors.textSecondary(context),
                    tooltip: entry == null ? 'Thêm: $title' : 'Sửa: $title',
                    onPressed: onEdit,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.circlePlus, size: 18),
      label: const Text('Thêm ghi nhớ'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        backgroundColor: AppColors.inset(context, 0.8),
        foregroundColor: AppColors.textPrimary(context),
        side: BorderSide(color: AppColors.insetBorder(context)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.chipFill(context),
        borderRadius: AppSpacing.roundedPill,
        border: Border.all(color: AppColors.inset(context, 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: 12,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(width: 6),
          Text(
            'Dữ liệu ghi nhớ của bạn',
            style: AppTypography.caption(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.slot, required this.initial});

  final AgentMemorySlot slot;
  final String initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.slot.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: agentMemoryMaxLength,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(hintText: widget.slot.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
