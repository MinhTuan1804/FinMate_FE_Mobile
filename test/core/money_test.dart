import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/format/money.dart';

void main() {
  group('parseCents', () {
    test('nhận int, String và null', () {
      expect(parseCents(45000), BigInt.from(45000));
      expect(parseCents('45000'), BigInt.from(45000));
      expect(parseCents(null), BigInt.zero);
    });

    test('nhận num có phần thập phân bằng cách cắt bỏ', () {
      expect(parseCents(1500.0), BigInt.from(1500));
    });
  });

  group('parseAmountInput', () {
    test('chấp nhận số có dấu chấm/phẩy/khoảng trắng/₫ ngăn cách', () {
      expect(parseAmountInput('1.500.000'), BigInt.from(1500000));
      expect(parseAmountInput('1,500,000 ₫'), BigInt.from(1500000));
      expect(parseAmountInput(' 45000 '), BigInt.from(45000));
    });

    test('từ chối rỗng, chữ, âm, số 0 và vượt giới hạn tối đa', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('abc'), isNull);
      expect(parseAmountInput('-5'), isNull);
      expect(parseAmountInput('0'), isNull);
      expect(parseAmountInput('1000000000000'), isNull); // vượt giới hạn 999.999.999.999 ₫
      expect(parseAmountInput('9223372036854775807'), isNull); // backend nhận được nhưng làm hỏng báo cáo (tràn số)
      expect(parseAmountInput('999999999999'), BigInt.parse('999999999999'));
    });
  });

  test('parseAmountInput(allowZero) cho phép số 0 (số dư ban đầu) nhưng vẫn từ chối số âm, chữ và vượt giới hạn', () {
    expect(parseAmountInput('0', allowZero: true), BigInt.zero);
    expect(parseAmountInput('0.000', allowZero: true), BigInt.zero);
    expect(parseAmountInput('-1', allowZero: true), isNull);
    expect(parseAmountInput('abc', allowZero: true), isNull);
    expect(parseAmountInput('1000000000000', allowZero: true), isNull);
    expect(parseAmountInput('', allowZero: true), isNull);
  });

  test('formatVnd định dạng chuẩn vi-VN', () {
    expect(formatVnd(BigInt.from(150000)), '150.000 ₫');
    expect(formatVnd(BigInt.zero), '0 ₫');
    expect(formatVnd(BigInt.from(34955000)), '34.955.000 ₫');
  });
}
