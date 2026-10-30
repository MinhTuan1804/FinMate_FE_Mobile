import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';

String _tlv(String tag, String value) => '$tag${value.length.toString().padLeft(2, '0')}$value';

String _tlvBytes(String tag, String value) => '$tag${utf8.encode(value).length.toString().padLeft(2, '0')}$value';

/// Dựng một mã VietQR đúng chuẩn (độ dài đúng, CRC đúng) để test không phụ thuộc vào mẫu chụp ngoài đời.
String _qr({String bin = '970422', String account = '0123456789', String service = 'QRIBFTTA', String? amount, String? purpose, String? name, bool byteLengths = false}) {
  final tlv = byteLengths ? _tlvBytes : _tlv;
  final beneficiary = _tlv('00', bin) + _tlv('01', account);
  final merchant = _tlv('00', 'A000000727') + _tlv('01', beneficiary) + _tlv('02', service);
  final body = [
    _tlv('00', '01'),
    _tlv('01', '12'),
    _tlv('38', merchant),
    _tlv('53', '704'),
    if (amount != null) _tlv('54', amount),
    _tlv('58', 'VN'),
    if (name != null) tlv('59', name),
    if (purpose != null) _tlv('62', tlv('08', purpose)),
    '6304',
  ].join();
  return '$body${crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

void main() {
  group('crc16', () {
    test('đúng vector chuẩn của CRC-16/CCITT-FALSE', () {
      expect(crc16('123456789'), 0x29B1);
    });
  });

  group('parseVietQr', () {
    test('đọc BIN, số tài khoản, số tiền, nội dung và tên thụ hưởng', () {
      final data = parseVietQr(_qr(amount: '50000', purpose: 'tien an', name: 'NGUYEN VAN A'));

      expect(data.bankBin, '970422');
      expect(data.accountNumber, '0123456789');
      expect(data.amount, 50000);
      expect(data.message, 'tien an');
      expect(data.beneficiaryName, 'NGUYEN VAN A');
    });

    test('mã không đặt sẵn số tiền thì amount là null; số tiền có phần lẻ chỉ lấy phần nguyên', () {
      expect(parseVietQr(_qr()).amount, isNull);
      expect(parseVietQr(_qr(amount: '125000.00')).amount, 125000);
    });

    test('mã sai CRC bị từ chối: số tài khoản trong đó không đáng tin', () {
      final good = _qr();
      final tampered = '${good.substring(0, good.length - 4)}0000';

      expect(() => parseVietQr(tampered), throwsA(isA<VietQrParseException>().having((e) => e.message, 'message', contains('sai mã kiểm tra'))));
    });

    test('mã chuyển vào SỐ THẺ bị từ chối thay vì coi số thẻ là số tài khoản', () {
      expect(() => parseVietQr(_qr(service: 'QRIBFTTC')), throwsA(isA<VietQrParseException>().having((e) => e.message, 'message', contains('THẺ'))));
    });

    test('chuỗi không phải VietQR hoặc cụt giữa chừng bị từ chối bằng thông báo rõ ràng', () {
      expect(() => parseVietQr('https://example.com'), throwsA(isA<VietQrParseException>()));
      expect(() => parseVietQr('00020101021238'), throwsA(isA<VietQrParseException>()));
    });

    test('tên có dấu vẫn đọc đúng dù nơi sinh mã đếm độ dài theo byte', () {
      final data = parseVietQr(_qr(name: 'NGUYỄN VĂN A', byteLengths: true));

      expect(data.accountNumber, '0123456789');
      expect(data.beneficiaryName, 'NGUYỄN VĂN A');
    });

    test('BIN không đủ 6 chữ số bị từ chối', () {
      expect(() => parseVietQr(_qr(bin: '9704')), throwsA(isA<VietQrParseException>()));
    });
  });

  group('buildVietQrDeeplink', () {
    test('app là ngân hàng GỬI, ba là tài khoản và ngân hàng NHẬN: hai thứ độc lập', () {
      final uri = buildVietQrDeeplink(
        senderAppCode: 'mb',
        receiverAppCode: 'icb',
        accountNumber: '0123456789',
        amount: 50000,
        message: 'tien an',
        beneficiaryName: 'NGUYEN VAN A',
      );

      expect(uri.host, 'dl.vietqr.io');
      expect(uri.path, '/pay');
      expect(uri.queryParameters, {
        'app': 'mb',
        'ba': '0123456789@icb',
        'tn': 'tien an',
        'url': 'https://www.vietqr.io/deeplink',
        'am': '50000',
        'bn': 'NGUYEN VAN A',
      });
    });

    test('luôn có tham số url (thiếu nó app ngân hàng chỉ mở màn hình chủ)', () {
      final uri = buildVietQrDeeplink(senderAppCode: 'mb', receiverAppCode: 'mb', accountNumber: '1234', amount: 1, message: 'x');

      expect(uri.queryParameters.containsKey('url'), isTrue);
      expect(uri.queryParameters.containsKey('bn'), isFalse);
    });
  });
}
