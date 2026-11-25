import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/groups/domain/join_link.dart';

void main() {
  test('link tham gia nhóm: lấy ra mã', () {
    expect(parseGroupJoinLink('https://finmate.app/join/6R1W-xlxHY3V04gaiB2-EA'), '6R1W-xlxHY3V04gaiB2-EA');
    expect(parseGroupJoinLink('  https://finmate.app/join/abc/ '), 'abc');
  });

  test('QR khác không bị nhận nhầm là link tham gia nhóm', () {
    expect(parseGroupJoinLink('00020101021238570010A000000727'), isNull); // VietQR
    expect(parseGroupJoinLink('https://dl.vietqr.io/pay?app=vcb'), isNull);
    expect(parseGroupJoinLink('https://khac.vn/join/abc'), isNull);
    expect(parseGroupJoinLink('https://finmate.app/join'), isNull);
    expect(parseGroupJoinLink('https://finmate.app/other/abc'), isNull);
    expect(parseGroupJoinLink(''), isNull);
  });
}
