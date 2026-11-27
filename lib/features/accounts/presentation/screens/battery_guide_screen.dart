import 'package:flutter/material.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Hướng dẫn giữ FinMate chạy nền để không bỏ lỡ thông báo ngân hàng. Nhiều hãng (nhất là Xiaomi, Oppo, Vivo) tự tắt app chạy nền
/// để tiết kiệm pin, làm độ phủ dữ liệu tụt. Phần của hãng máy người dùng (BE trả trong data-coverage) được mở sẵn và đưa lên đầu.
class BatteryGuideScreen extends StatelessWidget {
  /// `manufacturer` thiết bị báo lên (vd "Xiaomi", "samsung"); null = không biết.
  final String? manufacturer;

  const BatteryGuideScreen({super.key, this.manufacturer});

  static const _guides = <(String, List<String>, List<String>)>[
    ('Xiaomi / Redmi / POCO', ['xiaomi', 'redmi', 'poco'], [
      'Cài đặt → Ứng dụng → Quản lý ứng dụng → FinMate.',
      'Bật "Tự khởi động" (Autostart).',
      'Tiết kiệm pin → chọn "Không giới hạn".',
      'Mở danh sách app gần đây, nhấn giữ FinMate và chọn biểu tượng khóa để không bị dọn.',
    ]),
    ('Samsung', ['samsung'], [
      'Cài đặt → Ứng dụng → FinMate → Pin → chọn "Không hạn chế".',
      'Cài đặt → Chăm sóc thiết bị → Pin → Giới hạn sử dụng nền: bỏ FinMate khỏi "Ứng dụng ngủ" và "Ứng dụng ngủ sâu".',
    ]),
    ('Oppo / Realme / OnePlus', ['oppo', 'realme', 'oneplus'], [
      'Cài đặt → Pin → Quản lý mức tiêu thụ pin của ứng dụng → FinMate.',
      'Bật "Cho phép hoạt động nền" và "Cho phép tự khởi chạy".',
    ]),
    ('Vivo / iQOO', ['vivo', 'iqoo'], [
      'Cài đặt → Pin → Mức tiêu thụ điện nền cao → bật cho FinMate.',
      'i Manager → Quản lý ứng dụng → Tự khởi động → bật FinMate.',
    ]),
    ('Huawei / Honor', ['huawei', 'honor'], [
      'Cài đặt → Pin → Khởi chạy ứng dụng → FinMate: tắt "Quản lý tự động".',
      'Bật cả ba mục: tự khởi chạy, khởi chạy phụ, chạy nền.',
    ]),
    ('Máy khác (Android gốc, Google Pixel...)', [], [
      'Cài đặt → Ứng dụng → FinMate → Pin → chọn "Không hạn chế" (hoặc "Không tối ưu hóa").',
    ]),
  ];

  bool _matches(List<String> keys) {
    final m = manufacturer?.toLowerCase();
    return m != null && keys.any(m.contains);
  }

  @override
  Widget build(BuildContext context) {
    final mine = _guides.where((g) => _matches(g.$2)).toList();
    final ordered = [...mine, ..._guides.where((g) => !mine.contains(g))];
    return Scaffold(
      appBar: AppBar(title: const Text('Giữ FinMate chạy nền')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Điện thoại có thể tự tắt FinMate để tiết kiệm pin, khi đó FinMate không đọc được thông báo ngân hàng và báo cáo, dự báo sẽ thiếu giao dịch. '
            'Làm theo hướng dẫn cho đúng hãng máy của bạn, rồi kiểm tra quyền đọc thông báo vẫn đang bật.',
            style: AppTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final g in ordered)
            Card(
              child: ExpansionTile(
                key: ValueKey('battery-guide-${g.$1}'),
                initiallyExpanded: mine.contains(g),
                title: Text(mine.contains(g) ? '${g.$1} (máy của bạn)' : g.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final (i, step) in g.$3.indexed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${i + 1}. $step')),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const ValueKey('battery-guide-open-notification-settings'),
            onPressed: sharedNotificationBridge.openNotificationAccessSettings,
            child: const Text('Kiểm tra quyền đọc thông báo'),
          ),
        ],
      ),
    );
  }
}
