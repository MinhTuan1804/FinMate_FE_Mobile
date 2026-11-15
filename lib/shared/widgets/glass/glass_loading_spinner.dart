import 'package:flutter/material.dart';

/// Vòng quay đang tải dùng chung trong các thẻ: kích thước cố định và canh giữa để thẻ không kéo giãn nó thành elip.
class GlassLoadingSpinner extends StatelessWidget {
  const GlassLoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
      ),
    );
  }
}
