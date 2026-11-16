import 'package:flutter/painting.dart';

/// `#RRGGBB` (hoặc không có `#`) -> màu đục; sai dạng thì null để nơi gọi dùng màu mặc định.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final clean = hex.trim().replaceFirst('#', '');
  if (clean.length != 6) return null;
  final value = int.tryParse(clean, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// So sánh hai mã màu không phân biệt hoa thường và dấu `#`
bool sameHexColor(String? a, String? b) {
  if (a == null || b == null) return false;
  return a.trim().replaceFirst('#', '').toUpperCase() == b.trim().replaceFirst('#', '').toUpperCase();
}
