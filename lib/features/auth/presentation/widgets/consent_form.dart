import 'package:flutter/material.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Khung chung của hai màn đồng ý: nội dung cuộn được trong thẻ kính Liquid Glass,
/// ô tick bắt buộc, nút đồng ý chỉ bấm được sau khi tick.
class ConsentForm extends StatefulWidget {
  final String title;
  final List<Widget> content;
  final String checkboxLabel;
  final String acceptLabel;
  final Future<void> Function() onAccept;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ConsentForm({
    super.key,
    required this.title,
    required this.content,
    required this.checkboxLabel,
    required this.acceptLabel,
    required this.onAccept,
    this.secondaryLabel,
    this.onSecondary,
  });

  static Widget point(BuildContext context, String label, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: text),
            ],
          ),
          style: AppTypography.body(context),
        ),
      );

  @override
  State<ConsentForm> createState() => _ConsentFormState();
}

class _ConsentFormState extends State<ConsentForm> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientGlassBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ZenvestSurfaceSheet(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: AppTypography.h2(context)),
                        const SizedBox(height: 16),
                        ...widget.content,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  value: _checked,
                  onChanged:
                      _busy ? null : (v) => setState(() => _checked = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    widget.checkboxLabel,
                    style: AppTypography.body(context).copyWith(fontSize: 13),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: AppTypography.caption(context)
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              FilledButton(
                onPressed: _checked && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.acceptLabel),
              ),
              if (widget.secondaryLabel != null)
                TextButton(
                  onPressed: _busy ? null : widget.onSecondary,
                  child: Text(widget.secondaryLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
