import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Số tiền VND là số nguyên (int64); backend đặt tên trường `...Cents` nhưng không có phần lẻ.
BigInt parseCents(Object? value) {
  if (value == null) return BigInt.zero;
  if (value is int) return BigInt.from(value);
  if (value is num) return BigInt.from(value.truncate());
  return BigInt.tryParse(value.toString()) ?? BigInt.zero;
}

/// Số tiền tối đa cho một lần nhập (999.999.999.999 ₫). Backend chấp nhận tới int64 nhưng các báo cáo
/// tổng hợp sẽ tràn số và trả lỗi 500, nên FE chặn sớm.
final maxAmountCents = BigInt.parse('999999999999');

/// Đọc số tiền người dùng nhập ('1.500.000', '1,500,000 ₫'...). Trả về null nếu rỗng, không phải số,
/// âm, hoặc vượt [maxAmountCents]. Số 0 chỉ hợp lệ khi [allowZero] (ví dụ số dư ban đầu).
BigInt? parseAmountInput(String text, {bool allowZero = false}) {
  final clean = text.replaceAll(RegExp(r'[.,\s₫]'), '');
  final value = BigInt.tryParse(clean);
  if (value == null || value < BigInt.zero || value > maxAmountCents) return null;
  if (value == BigInt.zero && !allowZero) return null;
  return value;
}

/// Ví dụ: 150000 -> '150.000 ₫'
String formatVnd(BigInt cents) => '${NumberFormat('#,###', 'vi_VN').format(cents.toInt())} ₫';

/// Như [formatVnd] nhưng không có " ₫" — dùng để điền sẵn ô nhập số tiền (vd sửa nháp) sao cho
/// hiện có dấu chấm phần nghìn ngay từ đầu, không phải đợi người dùng gõ thêm mới thấy.
String formatAmountDigits(BigInt cents) => NumberFormat('#,###', 'vi_VN').format(cents.toInt());

/// Tự thêm dấu chấm phần nghìn khi người dùng đang gõ số tiền (vd gõ "2000" tự hiện "2.000"),
/// để không phải tự đếm số 0. Chỉ giữ chữ số, bỏ mọi ký tự khác người dùng lỡ gõ vào — không
/// chặn gõ (không có ký tự nào bị "nuốt" khó hiểu), chỉ định dạng lại ngay sau mỗi lần gõ.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _digitsOnly = RegExp(r'[^\d]');
  static final _format = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(_digitsOnly, '');
    if (digits.isEmpty) return const TextEditingValue();

    final formatted = _format.format(int.parse(digits));
    // Giữ con trỏ ở cuối: số tiền luôn gõ nối vào cuối (không sửa giữa số), nên không cần tính
    // lại vị trí con trỏ theo từng dấu chấm mới chèn.
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
