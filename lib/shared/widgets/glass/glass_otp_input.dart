import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Ô nhập mã OTP 6 số kiểu "boxed digits" (DESIGN.md a6). Không thêm dependency mới: dùng một
/// [TextField] vô hình phủ lên 6 ô hiển thị để điều khiển focus/bàn phím một cách đáng tin cậy.
class GlassOtpInput extends StatefulWidget {
  final int length;
  final void Function(String code)? onChanged;
  final void Function(String code)? onCompleted;

  const GlassOtpInput({super.key, this.length = 6, this.onChanged, this.onCompleted});

  @override
  State<GlassOtpInput> createState() => GlassOtpInputState();
}

class GlassOtpInputState extends State<GlassOtpInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clear() {
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) => _digitBox(i)),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: widget.length,
              decoration: const InputDecoration(counterText: ''),
              onChanged: (value) {
                setState(() {});
                widget.onChanged?.call(value);
                if (value.length == widget.length) widget.onCompleted?.call(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitBox(int index) {
    final text = _controller.text;
    final filled = index < text.length;
    final isActive = index == text.length && _focusNode.hasFocus;

    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? GlassColors.accentSkyBlue : Colors.white.withValues(alpha: 0.75),
          width: isActive ? 2 : 1.5,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
      child: Text(
        filled ? text[index] : '',
        style: GlassTypography.displayHero().copyWith(fontSize: 22),
      ),
    );
  }
}
