/// Nhãn của một đáp án "chi cho X khoảng bao nhiêu": khoảng % thu nhập đổi ra số tiền gọn ("1–2tr", "500k–1tr", "Từ 3tr").
/// Chưa có thu nhập thì hiện % ("10–20%"). Số tiền làm tròn xuống nghìn đồng như backend tính kế hoạch.
String moneyRangeLabel({required int? incomeVnd, required int minPct, int? maxPct}) {
  if (maxPct == 0) return 'Không chi';

  if (incomeVnd == null || incomeVnd <= 0) {
    return maxPct == null ? 'Từ $minPct%' : '$minPct–$maxPct%';
  }

  final low = _share(incomeVnd, minPct);
  if (maxPct == null) return 'Từ ${_compact(low)}';

  final high = _share(incomeVnd, maxPct);
  if (low == 0) return '0–${_compact(high)}';
  // Cùng là triệu thì chỉ ghi đơn vị một lần ("1–2tr"), khác đơn vị thì mỗi đầu giữ đơn vị riêng ("500k–1tr").
  if (low >= _million && high >= _million) return '${_millions(low)}–${_millions(high)}tr';
  return '${_compact(low)}–${_compact(high)}';
}

const _million = 1000000;

int _share(int income, int pct) => income * pct ~/ 100 ~/ 1000 * 1000;

String _compact(int vnd) => vnd >= _million ? '${_millions(vnd)}tr' : (vnd == 0 ? '0' : '${vnd ~/ 1000}k');

/// Triệu với tối đa một chữ số thập phân, dấu phẩy kiểu Việt ("1,5"); bỏ ",0".
String _millions(int vnd) {
  final tenths = vnd ~/ 100000;
  final whole = tenths ~/ 10;
  final fraction = tenths % 10;
  return fraction == 0 ? '$whole' : '$whole,$fraction';
}
