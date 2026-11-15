import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/support/data/support_image_source.dart';
import 'package:finmate/features/support/data/support_repository.dart';
import 'package:finmate/features/support/presentation/controllers/support_controller.dart';
import 'package:finmate/features/support/presentation/screens/support_screen.dart';

const _maxSubject = 200;
const _maxBody = 4000;
const _maxImages = 5;

/// Màn H17: Gửi yêu cầu hỗ trợ mới (theo Figma). Gửi đúng các trường BE nhận (loại, tiêu đề, nội dung) rồi đính kèm ảnh đã chọn
/// vào tin nhắn đầu tiên. Mức ưu tiên, nhật ký chẩn đoán và lưu bản nháp trong Figma chưa có ở BE nên không hiển thị.
class SupportCreateScreen extends ConsumerStatefulWidget {
  const SupportCreateScreen({super.key});

  @override
  ConsumerState<SupportCreateScreen> createState() => _SupportCreateScreenState();
}

class _SupportCreateScreenState extends ConsumerState<SupportCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = supportCategories.first;
  final List<PickedImage> _images = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) return;
    try {
      final picked = await ref.read(supportImageSourceProvider).pickFromGallery();
      if (picked != null && mounted) setState(() => _images.add(picked));
    } catch (e) {
      if (mounted) setState(() => _error = supportErrorMessage(e));
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(supportRepositoryProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final detail = await repo.createTicket(category: _category, subject: _subject.text.trim(), body: _body.text.trim());
      ref.invalidate(supportTicketsProvider);
      var failedImages = 0;
      for (final img in _images) {
        try {
          await repo.addAttachment(ticketId: detail.ticket.id, messageId: detail.messages.first.id, filePath: img.path, fileName: img.name);
        } catch (_) {
          failedImages++;
        }
      }
      messenger.showSnackBar(SnackBar(
        content: Text(failedImages == 0 ? 'Đã tạo yêu cầu hỗ trợ.' : 'Đã tạo yêu cầu, nhưng $failedImages ảnh chưa gửi được. Bạn có thể gửi lại trong chi tiết yêu cầu.'),
      ));
      router.pushReplacement('/support-ticket', extra: detail.ticket.id);
    } catch (e) {
      if (mounted) setState(() => _error = supportErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi yêu cầu mới'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [TextButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Hủy'))],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  LiquidGlassCard(
                    variant: LiquidGlassVariant.subtle,
                    padding: const EdgeInsets.all(12),
                    borderColor: AppColors.danger.withValues(alpha: 0.4),
                    child: Text(_error!, style: AppTypography.caption(context).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                ],
                _label(context, 'Chủ đề / Phân loại sự cố', required: true),
                DropdownButtonFormField<String>(
                  key: const ValueKey('support-category'),
                  initialValue: _category,
                  isExpanded: true,
                  items: [for (final c in supportCategories) DropdownMenuItem(value: c, child: Text(supportCategoryLabel(c)))],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                _label(context, 'Tiêu đề sự cố', required: true),
                TextFormField(
                  key: const ValueKey('support-subject'),
                  controller: _subject,
                  maxLength: _maxSubject,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Ví dụ: Không tải được lịch sử giao dịch', counterText: ''),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề.' : null,
                ),
                const SizedBox(height: 16),
                _label(context, 'Mô tả chi tiết', required: true),
                TextFormField(
                  key: const ValueKey('support-body'),
                  controller: _body,
                  maxLength: _maxBody,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(hintText: 'Mô tả những gì bạn thấy, các bước đã thử, thời điểm xảy ra...', alignLabelWithHint: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nội dung.' : null,
                ),
                const SizedBox(height: 8),
                _label(context, 'Đính kèm ảnh chụp màn hình'),
                for (var i = 0; i < _images.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: Icon(LucideIcons.image, size: 18, color: AppColors.slateOn(context)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_images[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13.5))),
                          IconButton(
                            key: ValueKey('remove-image-$i'),
                            tooltip: 'Bỏ ảnh',
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            onPressed: () => setState(() => _images.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_images.length < _maxImages)
                  InkWell(
                    key: const ValueKey('add-image'),
                    borderRadius: AppSpacing.roundedLarge,
                    onTap: _pickImage,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: AppSpacing.roundedLarge,
                        border: Border.all(color: AppColors.slateOn(context).withValues(alpha: 0.5), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.circlePlus, size: 18, color: AppColors.slateOn(context)),
                          const SizedBox(width: 8),
                          Text('Thêm ảnh minh họa', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slateOn(context))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                LiquidGlassPillButton(
                  key: const ValueKey('support-submit'),
                  label: _busy ? 'Đang gửi...' : 'Gửi yêu cầu hỗ trợ',
                  icon: LucideIcons.send,
                  isFullWidth: true,
                  onPressed: _busy ? () {} : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger))],
        ),
        style: AppTypography.bodyMedium(context),
      ),
    );
  }
}
