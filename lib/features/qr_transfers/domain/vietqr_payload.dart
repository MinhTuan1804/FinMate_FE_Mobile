/// Kết quả đọc được từ một chuỗi QR theo chuẩn EMVCo/VietQR (TLV: tag 2 ký tự + độ dài 2 ký tự +
/// giá trị). Các trường không đọc được (QR hợp lệ nhưng không theo chuẩn VietQR, hoặc thiếu
/// trường) để null — không ném lỗi, màn hình C2 vẫn cho nhập tay phần còn thiếu.
class VietQrPayload {
  final String? bankBin;
  final String? accountNumber;
  final BigInt? amountCents;
  final String? message;
  final String? beneficiaryName;

  const VietQrPayload({this.bankBin, this.accountNumber, this.amountCents, this.message, this.beneficiaryName});

  bool get isEmpty =>
      bankBin == null && accountNumber == null && amountCents == null && message == null && beneficiaryName == null;
}

/// Một phần tử TLV đã tách: [tag] 2 ký tự, [value] phần giá trị thô (chưa parse tiếp).
class _TlvEntry {
  final String tag;
  final String value;
  const _TlvEntry(this.tag, this.value);
}

/// GUID chuẩn VietQR trong field 38 sub-field 00 (napas247/VietQR); dùng để nhận diện field 38
/// đúng là thông tin VietQR trước khi đọc tiếp các sub-field bên trong.
const _vietQrGuid = 'A000000727';

/// Tách một chuỗi TLV phẳng thành danh sách (tag, value), bỏ qua phần dư thừa/hỏng ở cuối thay vì
/// ném lỗi — một QR bị cắt cụt vẫn nên trả về các trường đọc được ở phần đầu.
List<_TlvEntry> _parseTlv(String data) {
  final entries = <_TlvEntry>[];
  var i = 0;
  while (i + 4 <= data.length) {
    final tag = data.substring(i, i + 2);
    final lenStr = data.substring(i + 2, i + 4);
    final len = int.tryParse(lenStr);
    if (len == null) break;
    final valueStart = i + 4;
    final valueEnd = valueStart + len;
    if (valueEnd > data.length) break;
    entries.add(_TlvEntry(tag, data.substring(valueStart, valueEnd)));
    i = valueEnd;
  }
  return entries;
}

String? _findValue(List<_TlvEntry> entries, String tag) {
  for (final e in entries) {
    if (e.tag == tag) return e.value;
  }
  return null;
}

/// Đọc field 38 (merchant account info): sub-field 00 = GUID, sub-field 01 = thông tin ngân hàng
/// thụ hưởng (lồng tiếp bên trong: 00 = BIN ngân hàng, 01 = số tài khoản).
(String? bankBin, String? accountNumber) _parseMerchantAccountInfo(String field38) {
  final sub = _parseTlv(field38);
  final guid = _findValue(sub, '00');
  if (guid != _vietQrGuid) return (null, null);
  final bankAccountInfo = _findValue(sub, '01');
  if (bankAccountInfo == null) return (null, null);
  final nested = _parseTlv(bankAccountInfo);
  return (_findValue(nested, '00'), _findValue(nested, '01'));
}

/// Đọc field 62 (additional data field template): sub-field 08 = nội dung chuyển khoản.
String? _parsePurpose(String field62) {
  final sub = _parseTlv(field62);
  return _findValue(sub, '08');
}

/// VND không có phần thập phân, nhưng field 54 theo chuẩn EMVCo vẫn có thể chứa dấu chấm thập
/// phân (vd "150000.00") — bỏ phần thập phân thay vì cộng nhầm vào số nguyên.
BigInt? _parseAmount(String? field54) {
  if (field54 == null || field54.isEmpty) return null;
  final wholePart = field54.split('.').first;
  return BigInt.tryParse(wholePart);
}

/// Đọc một chuỗi QR đã quét được thành [VietQrPayload]. Không ném lỗi: QR không theo chuẩn
/// VietQR (ví dụ QR URL thông thường) trả về payload rỗng, màn hình gọi nơi khác tự quyết định
/// báo lỗi "không phải mã VietQR" hay cho nhập tay.
VietQrPayload parseVietQrPayload(String raw) {
  final entries = _parseTlv(raw);
  if (entries.isEmpty) return const VietQrPayload();

  String? bankBin;
  String? accountNumber;
  final field38 = _findValue(entries, '38');
  if (field38 != null) {
    final (bin, account) = _parseMerchantAccountInfo(field38);
    bankBin = bin;
    accountNumber = account;
  }

  final amountCents = _parseAmount(_findValue(entries, '54'));

  String? message;
  final field62 = _findValue(entries, '62');
  if (field62 != null) message = _parsePurpose(field62);

  // Field 59 (Merchant/Beneficiary Name) nằm ở cấp top-level, cùng cấp với 54/62 — không lồng
  // trong field 38 như bankBin/accountNumber.
  final beneficiaryName = _findValue(entries, '59');

  return VietQrPayload(
    bankBin: bankBin,
    accountNumber: accountNumber,
    amountCents: amountCents,
    message: message,
    beneficiaryName: beneficiaryName,
  );
}
