import 'package:finmate/core/format/money.dart';

/// Một giá thị trường mà mục tiêu tiết kiệm có thể theo, ví dụ vàng (GET /saving-goals/market-topics).
/// BE chỉ trả chủ đề đang bật và đã có giá xác nhận.
class MarketTopic {
  /// Mã gửi lại khi tạo/sửa mục tiêu (`marketTopic`), ví dụ `gold`.
  final String key;
  final String label;

  /// Giá hiện tại (đồng; với vàng là giá bán ra mỗi lượng).
  final BigInt priceCents;
  final DateTime? asOf;

  /// Tên mục tiêu chứa một trong các từ này thì app GỢI Ý chọn chủ đề; không bao giờ tự gắn.
  final List<String> nameKeywords;

  const MarketTopic({
    required this.key,
    required this.label,
    required this.priceCents,
    required this.asOf,
    required this.nameKeywords,
  });

  factory MarketTopic.fromJson(Map<String, dynamic> json) => MarketTopic(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        priceCents: parseCents(json['priceCents']),
        asOf: DateTime.tryParse(json['asOf'] as String? ?? '')?.toLocal(),
        nameKeywords: [for (final k in (json['nameKeywords'] as List? ?? const [])) (k as String).toLowerCase()],
      );

  /// Tên mục tiêu có nhắc tới chủ đề này không (so sánh không phân biệt hoa thường).
  bool suggestedFor(String goalName) {
    final name = goalName.toLowerCase();
    return nameKeywords.any((k) => k.isNotEmpty && name.contains(k));
  }
}
