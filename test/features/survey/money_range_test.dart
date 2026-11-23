import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/survey/domain/money_range.dart';

void main() {
  group('moneyRangeLabel', () {
    test('có thu nhập thì đổi khoảng % ra số tiền, cùng đơn vị triệu', () {
      expect(moneyRangeLabel(incomeVnd: 10000000, minPct: 10, maxPct: 20), '1–2tr');
    });

    test('đáp án mở ("từ 30%") hiện "Từ" + mức dưới', () {
      expect(moneyRangeLabel(incomeVnd: 10000000, minPct: 30, maxPct: null), 'Từ 3tr');
    });

    test('chưa có thu nhập thì hiện %', () {
      expect(moneyRangeLabel(incomeVnd: null, minPct: 5, maxPct: 10), '5–10%');
      expect(moneyRangeLabel(incomeVnd: null, minPct: 30, maxPct: null), 'Từ 30%');
    });

    test('dưới một triệu dùng nghìn (k), làm tròn xuống nghìn', () {
      expect(moneyRangeLabel(incomeVnd: 7500000, minPct: 0, maxPct: 5), '0–375k');
      expect(moneyRangeLabel(incomeVnd: 7512345, minPct: 0, maxPct: 5), '0–375k');
    });

    test('khác đơn vị thì mỗi đầu giữ đơn vị riêng; số lẻ triệu có một chữ số thập phân', () {
      expect(moneyRangeLabel(incomeVnd: 10000000, minPct: 5, maxPct: 10), '500k–1tr');
      expect(moneyRangeLabel(incomeVnd: 15000000, minPct: 10, maxPct: 20), '1,5–3tr');
    });

    test('khoảng 0–0 là "Không chi"', () {
      expect(moneyRangeLabel(incomeVnd: 10000000, minPct: 0, maxPct: 0), 'Không chi');
      expect(moneyRangeLabel(incomeVnd: null, minPct: 0, maxPct: 0), 'Không chi');
    });
  });
}
