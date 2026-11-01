import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_providers.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/finance_widgets.dart';

/// Màn CÁCH QUẢN LÝ CỦA TÔI: các cách đang dùng (chính trước), giá trị tham số đang có hiệu lực (đánh dấu phần đã chỉnh), chỉnh tham số
/// (ngưỡng cảnh báo T1/T2, giờ nhắc...) và ngừng dùng. Dữ liệu giao dịch, ngân sách, mục tiêu không bị ảnh hưởng khi ngừng dùng một cách.
class MyMethodsScreen extends ConsumerWidget {
  const MyMethodsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, UserMethod method) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ParamEditor(userMethod: method),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu tham số.')));
    }
  }

  Future<void> _end(BuildContext context, WidgetRef ref, UserMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ngừng dùng "${method.method.name}"?'),
        content: const Text('Giao dịch, ngân sách và mục tiêu của bạn không bị ảnh hưởng. Bạn có thể chọn lại cách này bất cứ lúc nào.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Giữ lại')),
          FilledButton(key: const Key('confirm_end'), onPressed: () => Navigator.pop(context, true), child: const Text('Ngừng dùng')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(financeMethodsRepositoryProvider).endMethod(method.id);
      refreshFinanceMethods(ref);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(myMethodsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Cách quản lý của tôi', style: AppTypography.h3(context))),
      body: SafeArea(
        child: methods.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FinanceFailure(message: errorMessage(error), onRetry: () => ref.invalidate(myMethodsProvider)),
          data: (list) {
            final sorted = [...list]..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0)); // cách chính lên đầu
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text(
                      'Bạn chưa dùng cách nào. Hãy xem gợi ý hoặc tự chọn một cách bên dưới.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(context),
                    ),
                  ),
                for (final method in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _UserMethodCard(
                      userMethod: method,
                      onEdit: () => _edit(context, ref, method),
                      onEnd: () => _end(context, ref, method),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('see_recommendation'),
                  onPressed: () => context.push('/finance-recommendation'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Xem gợi ý cho tôi'),
                ),
                TextButton(
                  key: const Key('redo_survey'),
                  onPressed: () => context.push('/finance-survey'),
                  child: const Text('Làm lại khảo sát'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserMethodCard extends StatelessWidget {
  const _UserMethodCard({required this.userMethod, required this.onEdit, required this.onEnd});

  final UserMethod userMethod;
  final VoidCallback onEdit;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final method = userMethod.method;
    final editable = method.params.any((p) => p.userEditable);
    return FinanceCard(
      key: Key('method_${method.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(method.name, style: AppTypography.h3(context))),
              if (!method.available)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text('Đã ngừng cung cấp', key: Key('unavailable_${method.code}'), style: AppTypography.caption(context).copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: AppSpacing.roundedPill),
                child: Text(
                  userMethod.isPrimary ? 'Cách chính' : 'Cách bổ trợ',
                  style: AppTypography.caption(context).copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(method.summary, style: AppTypography.caption(context)),
          if (method.params.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Tham số đang dùng', style: AppTypography.bodyMedium(context)),
            const SizedBox(height: AppSpacing.xs),
            for (final param in method.params)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(param.label, style: AppTypography.body(context))),
                    Text(
                      param.format(userMethod.valueOf(param)),
                      key: Key('value_${param.key}'),
                      style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (userMethod.overrides.containsKey(param.key))
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Text('(đã chỉnh)', style: AppTypography.caption(context)),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (editable)
                FilledButton.tonal(key: Key('edit_${method.code}'), onPressed: onEdit, child: const Text('Chỉnh tham số')),
              TextButton(key: Key('end_${method.code}'), onPressed: onEnd, child: const Text('Ngừng dùng')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bảng chỉnh tham số người dùng sửa được. Kiểm khoảng min-max ngay trên máy; ràng buộc giữa các tham số (vd. T1 < T2) do backend kiểm và lỗi hiện ngay dưới form.
/// Chỉ gửi những tham số THỰC SỰ đổi so với giá trị đang có hiệu lực. "Về mặc định" gửi null cho mọi tham số đã chỉnh (xóa ghi đè).
class _ParamEditor extends ConsumerStatefulWidget {
  const _ParamEditor({required this.userMethod});

  final UserMethod userMethod;

  @override
  ConsumerState<_ParamEditor> createState() => _ParamEditorState();
}

class _ParamEditorState extends ConsumerState<_ParamEditor> {
  final _formKey = GlobalKey<FormState>();
  late final List<ParamDef> _params = widget.userMethod.method.params.where((p) => p.userEditable).toList(growable: false);
  late final Map<String, TextEditingController> _controllers = {
    for (final p in _params)
      if (p.type != 'minutes') p.key: TextEditingController(text: '${widget.userMethod.valueOf(p)}'),
  };
  late final Map<String, int> _minutes = {
    for (final p in _params)
      if (p.type == 'minutes') p.key: widget.userMethod.valueOf(p),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send(Map<String, int?> changes) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(financeMethodsRepositoryProvider).updateMethodParams(widget.userMethod.id, changes);
      refreshFinanceMethods(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = errorMessage(error);
          _saving = false;
        });
      }
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = <String, int?>{};
    for (final p in _params) {
      final value = p.type == 'minutes' ? _minutes[p.key]! : int.parse(_controllers[p.key]!.text.trim());
      if (value != widget.userMethod.valueOf(p)) changes[p.key] = value;
    }
    if (changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    _send(changes);
  }

  void _reset() => _send({for (final key in widget.userMethod.overrides.keys) key: null});

  Future<void> _pickTime(ParamDef p) async {
    final value = _minutes[p.key]!;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60));
    if (picked != null) setState(() => _minutes[p.key] = picked.hour * 60 + picked.minute);
  }

  String? _validate(ParamDef p, String? text) {
    final value = int.tryParse((text ?? '').trim());
    if (value == null) return 'Nhập một số';
    if (value < p.min || value > p.max) return 'Từ ${p.format(p.min)} đến ${p.format(p.max)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chỉnh tham số: ${widget.userMethod.method.name}', style: AppTypography.h3(context)),
              const SizedBox(height: AppSpacing.md),
              for (final p in _params)
                if (p.type == 'minutes')
                  ListTile(
                    key: Key('param_${p.key}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.label),
                    trailing: Text(p.format(_minutes[p.key]!), style: AppTypography.tabular(AppTypography.bodyLarge(context))),
                    onTap: _saving ? null : () => _pickTime(p),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: TextFormField(
                      key: Key('param_${p.key}'),
                      controller: _controllers[p.key],
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: p.label,
                        helperText: 'Từ ${p.format(p.min)} đến ${p.format(p.max)} (mặc định ${p.format(p.defaultValue)})',
                        suffixText: switch (p.type) { 'percent' => '%', 'cents' => '₫', _ => null },
                      ),
                      validator: (text) => _validate(p, text),
                    ),
                  ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(_error!, key: const Key('param_error'), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
                ),
              Row(
                children: [
                  if (widget.userMethod.overrides.isNotEmpty)
                    TextButton(key: const Key('reset_params'), onPressed: _saving ? null : _reset, child: const Text('Về mặc định')),
                  const Spacer(),
                  ElevatedButton(
                    key: const Key('save_params'),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Lưu'),
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
