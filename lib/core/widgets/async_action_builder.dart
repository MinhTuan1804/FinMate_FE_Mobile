import 'dart:async';

import 'package:flutter/material.dart';

/// Bọc callback của nút: nếu callback trả về Future thì tự bật trạng thái đang chạy
/// và khoá nút tới khi xong, để không màn nào phải tự giữ cờ `_saving` chống bấm 2 lần.
class AsyncActionBuilder extends StatefulWidget {
  const AsyncActionBuilder({
    super.key,
    required this.onPressed,
    required this.builder,
    this.loading = false,
  });

  final FutureOr<void> Function()? onPressed;

  /// Cờ loading do màn truyền vào (vd. state của controller) — gộp với trạng thái tự theo dõi.
  final bool loading;
  final Widget Function(BuildContext context, VoidCallback? onPressed, bool loading) builder;

  @override
  State<AsyncActionBuilder> createState() => _AsyncActionBuilderState();
}

class _AsyncActionBuilderState extends State<AsyncActionBuilder> {
  bool _running = false;

  Future<void> _run() async {
    final result = widget.onPressed!();
    if (result is! Future) return;
    setState(() => _running = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.loading || _running;
    // Callback mở dialog/sheet: khi route khác đè lên thì chỉ khoá nút, không quay spinner sau lớp phủ.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    final loading = widget.loading || (_running && onTop);
    return widget.builder(context, busy || widget.onPressed == null ? null : _run, loading);
  }
}

/// Spinner thay cho chữ/icon trên nút Material đang chạy; lấy màu foreground của nút qua IconTheme.
class ButtonLoadingIndicator extends StatelessWidget {
  const ButtonLoadingIndicator({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang xử lý',
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: IconTheme.of(context).color),
      ),
    );
  }
}
