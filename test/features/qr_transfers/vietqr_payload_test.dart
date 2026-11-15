import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/qr_transfers/domain/vietqr_payload.dart';

/// Ghép một phần tử TLV theo chuẩn EMVCo: tag (2 ký tự) + độ dài (2 ký tự, 0-pad) + giá trị.
String _tlv(String tag, String value) => '$tag${value.length.toString().padLeft(2, '0')}$value';

/// Field 38 (merchant account info) hợp lệ theo chuẩn VietQR: GUID A000000727 + sub-field 01
/// lồng bên trong chứa BIN ngân hàng (00) và số tài khoản (01).
String _field38(String bankBin, String accountNumber) {
  final nested = _tlv('00', bankBin) + _tlv('01', accountNumber);
  final guid = _tlv('00', 'A000000727');
  final beneficiary = _tlv('01', nested);
  return _tlv('38', guid + beneficiary);
}

String _field62WithPurpose(String purpose) => _tlv('62', _tlv('08', purpose));

void main() {
  group('parseVietQrPayload', () {
    test('đọc đủ ngân hàng + số tài khoản + số tiền + nội dung', () {
      final raw = _tlv('00', '01') +
          _field38('970436', '0123456789') +
          _tlv('54', '150000') +
          _tlv('58', 'VN') +
          _field62WithPurpose('Thanh toan tien an trua');

      final result = parseVietQrPayload(raw);

      expect(result.bankBin, '970436');
      expect(result.accountNumber, '0123456789');
      expect(result.amountCents, BigInt.from(150000));
      expect(result.message, 'Thanh toan tien an trua');
    });

    test('đọc tên người thụ hưởng (field 59, top-level, không lồng trong field 38)', () {
      final raw = _tlv('00', '01') +
          _field38('970436', '0123456789') +
          _tlv('54', '150000') +
          _tlv('58', 'VN') +
          _tlv('59', 'NGUYEN VAN A') +
          _field62WithPurpose('Thanh toan tien an trua');

      final result = parseVietQrPayload(raw);

      expect(result.beneficiaryName, 'NGUYEN VAN A');
      expect(result.bankBin, '970436');
      expect(result.accountNumber, '0123456789');
    });

    test('thiếu field 59 thì beneficiaryName null, không ảnh hưởng field khác', () {
      final raw = _tlv('00', '01') + _field38('970436', '0123456789') + _tlv('54', '50000');

      final result = parseVietQrPayload(raw);

      expect(result.beneficiaryName, isNull);
      expect(result.bankBin, '970436');
    });

    test('thiếu field số tiền (54) vẫn đọc được ngân hàng/tài khoản/nội dung', () {
      final raw = _tlv('00', '01') + _field38('970436', '0123456789') + _field62WithPurpose('Ca phe');

      final result = parseVietQrPayload(raw);

      expect(result.bankBin, '970436');
      expect(result.accountNumber, '0123456789');
      expect(result.amountCents, isNull);
      expect(result.message, 'Ca phe');
    });

    test('thiếu field nội dung (62) vẫn đọc được ngân hàng/tài khoản/số tiền', () {
      final raw = _tlv('00', '01') + _field38('970436', '0123456789') + _tlv('54', '50000');

      final result = parseVietQrPayload(raw);

      expect(result.bankBin, '970436');
      expect(result.accountNumber, '0123456789');
      expect(result.amountCents, BigInt.from(50000));
      expect(result.message, isNull);
    });

    test('độ dài hỏng (không phải số) thì dừng đọc an toàn, không ném lỗi', () {
      // "38XX..." có phần độ dài "XX" không phải số -> dừng lại ngay tại đó.
      const raw = '000201' '38XXkhong-hop-le' '5406100000';

      final result = parseVietQrPayload(raw);

      expect(result.isEmpty, isTrue);
    });

    test('chuỗi rỗng hoặc quá ngắn trả về payload rỗng, không ném lỗi', () {
      expect(parseVietQrPayload('').isEmpty, isTrue);
      expect(parseVietQrPayload('01').isEmpty, isTrue);
    });

    test('field 38 không có GUID VietQR (merchant khác) thì không đoán bừa bank/account', () {
      final nonVietQrField38 = _tlv('38', _tlv('00', 'D000000001') + _tlv('02', 'somemerchant'));
      final raw = _tlv('00', '01') + nonVietQrField38 + _tlv('54', '20000');

      final result = parseVietQrPayload(raw);

      expect(result.bankBin, isNull);
      expect(result.accountNumber, isNull);
      expect(result.amountCents, BigInt.from(20000));
    });
  });
}
