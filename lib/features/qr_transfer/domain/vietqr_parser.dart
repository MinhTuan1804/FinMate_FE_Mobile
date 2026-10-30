/// Bóc mã VietQR (chuẩn EMV-QR của NAPAS) của NGƯỜI NHẬN thành dữ liệu app cần: BIN ngân hàng, số tài khoản, số tiền và nội dung nếu mã có đặt sẵn, tên thụ hưởng (chỉ để hiển thị).
///
/// Khác bản thử đầu: kiểm CRC (mã sai CRC là mã bị sửa hoặc đọc lỗi, không nên tin số tài khoản trong đó), từ chối mã chuyển vào SỐ THẺ (`QRIBFTTC`, số thẻ không phải số tài khoản nên mở app ngân hàng với nó
/// sẽ chuyển sai chỗ), và chịu được độ dài tính theo byte khi tên/nội dung có dấu.
library;

import 'dart:convert';

class VietQrData {
  const VietQrData({
    required this.bankBin,
    required this.accountNumber,
    this.amount,
    this.message,
    this.beneficiaryName,
  });

  final String bankBin;
  final String accountNumber;

  /// Số tiền (đồng nguyên) nếu mã đặt sẵn, null nếu để người chuyển tự nhập.
  final int? amount;

  /// Nội dung chuyển khoản do người tạo mã đặt sẵn (tag 62, subtag 08).
  final String? message;

  /// Tên thụ hưởng (tag 59). Chỉ để người dùng đối chiếu, không dùng để suy ra danh mục.
  final String? beneficiaryName;
}

class VietQrParseException implements Exception {
  VietQrParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// CRC-16/CCITT-FALSE (đa thức 0x1021, khởi tạo 0xFFFF) trên các byte UTF-8, đúng như EMV-QR quy định.
int crc16(String text) {
  var crc = 0xFFFF;
  for (final byte in utf8.encode(text)) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}

/// Một cấp TLV (2 chữ số ID + 2 chữ số độ dài + giá trị) thành `{tag: value}`. Độ dài tính theo KÝ TỰ hoặc theo BYTE UTF-8 tùy nơi sinh mã (chuẩn công khai không nói rõ), nên cả hai cách đều được thử.
typedef _TlvParser = Map<String, String> Function(String data);

Map<String, String> _parseTlvChars(String data) {
  final result = <String, String>{};
  var i = 0;
  while (i + 4 <= data.length) {
    final tag = data.substring(i, i + 2);
    final len = int.tryParse(data.substring(i + 2, i + 4));
    if (len == null) throw VietQrParseException('Mã QR sai định dạng (độ dài không hợp lệ ở tag $tag).');
    final end = i + 4 + len;
    if (end > data.length) throw VietQrParseException('Mã QR sai định dạng (thiếu dữ liệu ở tag $tag).');
    result[tag] = data.substring(i + 4, end);
    i = end;
  }
  if (i != data.length) throw VietQrParseException('Mã QR sai định dạng (dư dữ liệu cuối chuỗi).');
  return result;
}

Map<String, String> _parseTlvBytes(String data) {
  final bytes = utf8.encode(data);
  final result = <String, String>{};
  var i = 0;
  while (i + 4 <= bytes.length) {
    final tag = utf8.decode(bytes.sublist(i, i + 2), allowMalformed: true);
    final len = int.tryParse(utf8.decode(bytes.sublist(i + 2, i + 4), allowMalformed: true));
    if (len == null) throw VietQrParseException('Mã QR sai định dạng (độ dài không hợp lệ ở tag $tag).');
    final end = i + 4 + len;
    if (end > bytes.length) throw VietQrParseException('Mã QR sai định dạng (thiếu dữ liệu ở tag $tag).');
    result[tag] = utf8.decode(bytes.sublist(i + 4, end), allowMalformed: true);
    i = end;
  }
  if (i != bytes.length) throw VietQrParseException('Mã QR sai định dạng (dư dữ liệu cuối chuỗi).');
  return result;
}

/// Mã dịch vụ NAPAS: chuyển nhanh vào TÀI KHOẢN (`QRIBFTTA`) hay vào THẺ (`QRIBFTTC`).
const _cardServiceCode = 'QRIBFTTC';

/// Parse nội dung đã quét. Ném [VietQrParseException] (thông điệp tiếng Việt dùng thẳng được cho người dùng) nếu không phải mã VietQR chuyển khoản hợp lệ.
///
/// Cách đếm độ dài được chọn theo KẾT QUẢ CẤU TRÚC chứ không theo "lỗi độ dài": thử đếm theo ký tự và chỉ nhận khi cả mã (kể cả các tầng lồng nhau) đọc ra đủ thông tin thụ hưởng; nếu không thì thử đếm theo
/// byte; cả hai đều hỏng thì báo lỗi của cách đầu. Một cách đếm sai gần như không bao giờ cho ra mã hợp lệ vì độ dài lệch làm các tag phía sau vỡ.
VietQrData parseVietQr(String raw) {
  final text = raw.trim();
  if (!text.startsWith('0002')) throw VietQrParseException('Đây không phải mã VietQR chuyển khoản.');

  final crcAt = text.lastIndexOf('6304');
  String? crc;
  if (crcAt >= 0 && text.length == crcAt + 8) {
    final expected = text.substring(crcAt + 4).toUpperCase();
    crc = expected;
    final actual = crc16(text.substring(0, crcAt + 4)).toRadixString(16).toUpperCase().padLeft(4, '0');
    if (expected != actual) throw VietQrParseException('Mã QR bị lỗi hoặc đã bị chỉnh sửa (sai mã kiểm tra). Hãy quét lại.');
  }

  try {
    return _extract(text, _parseTlvChars, crc);
  } on VietQrParseException catch (first) {
    try {
      return _extract(text, _parseTlvBytes, crc);
    } on VietQrParseException {
      throw first;
    }
  }
}

VietQrData _extract(String text, _TlvParser parse, String? crc) {
  final top = parse(text);

  // Mã có CRC thì tag 63 phải đọc ra đúng giá trị đó: nếu không thì cách đếm độ dài đã lệch (các tag sau tên/nội dung có dấu bị đọc sai) và phải thử cách còn lại.
  if (crc != null && top['63']?.toUpperCase() != crc) throw VietQrParseException('Mã QR sai định dạng (không đọc được mã kiểm tra).');

  final merchantRaw = top['38'];
  if (merchantRaw == null) throw VietQrParseException('Không tìm thấy thông tin thụ hưởng trong mã. Có thể đây không phải mã VietQR.');

  final merchant = parse(merchantRaw);
  final beneficiaryRaw = merchant['01'];
  if (beneficiaryRaw == null) throw VietQrParseException('Mã QR thiếu thông tin ngân hàng hoặc tài khoản thụ hưởng.');

  if (merchant['02'] == _cardServiceCode) {
    throw VietQrParseException('Mã này chuyển vào số THẺ chứ không phải số tài khoản, FinMate chưa hỗ trợ. Hãy dùng mã chuyển vào tài khoản.');
  }

  final beneficiary = parse(beneficiaryRaw);
  final bankBin = beneficiary['00'];
  final account = beneficiary['01'];
  if (bankBin == null || !RegExp(r'^\d{6}$').hasMatch(bankBin) || account == null || account.isEmpty) {
    throw VietQrParseException('Mã QR thiếu mã ngân hàng hoặc số tài khoản thụ hưởng.');
  }

  // "50000" hoặc "50000.00": chỉ lấy phần nguyên, VND không có số lẻ.
  final amountRaw = top['54'];
  final amount = (amountRaw == null || amountRaw.isEmpty) ? null : int.tryParse(amountRaw.split('.').first);

  String? message;
  final additionalRaw = top['62'];
  if (additionalRaw != null) {
    final purpose = parse(additionalRaw)['08'];
    if (purpose != null && purpose.isNotEmpty) message = purpose;
  }

  final name = top['59'];
  return VietQrData(
    bankBin: bankBin,
    accountNumber: account,
    amount: (amount != null && amount > 0) ? amount : null,
    message: message,
    beneficiaryName: (name != null && name.isNotEmpty) ? name : null,
  );
}

/// Liên kết mở app ngân hàng của NGƯỜI GỬI với màn chuyển tiền đã điền sẵn, qua dịch vụ chuyển tiếp `dl.vietqr.io`. `app` là app người dùng sẽ mở trên máy họ, `ba` là tài khoản VÀ ngân hàng của người
/// NHẬN: hai thứ độc lập nhau (chuyển khác ngân hàng là chuyện bình thường). Đã thử thật trên MB Bank và VietinBank; thiếu `url` thì app ngân hàng chỉ mở màn hình chủ nên KHÔNG bỏ tham số nào ở đây.
///
/// [host] và [returnUrl] lấy từ cấu hình hệ thống (admin đặt), không viết cứng trong app.
///
/// Lưu ý riêng tư: số tài khoản, số tiền, nội dung đi qua máy chủ [host] (bên thứ ba) để chuyển tiếp.
Uri buildVietQrDeeplink({
  required String host,
  required String returnUrl,
  required String senderAppCode,
  required String receiverAppCode,
  required String accountNumber,
  required int amount,
  required String message,
  String? beneficiaryName,
}) {
  final params = <String, String>{
    'app': senderAppCode,
    'ba': '$accountNumber@$receiverAppCode',
    'tn': message,
    'url': returnUrl,
    if (amount > 0) 'am': amount.toString(),
    if (beneficiaryName != null && beneficiaryName.isNotEmpty) 'bn': beneficiaryName,
  };
  return Uri.https(host, '/pay', params);
}
