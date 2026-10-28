import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/assistant/data/transfer_hints.dart';

FinancialAccount _account(String id, String name, {AccountType type = AccountType.cash, String? provider}) =>
    FinancialAccount(id: id, type: type, name: name, providerName: provider, balanceCents: BigInt.zero);

void main() {
  final wallet = _account('wallet', 'Ví');
  final savings = _account('savings', 'Tiết kiệm', type: AccountType.bank);
  final momo = _account('momo', 'MoMo', type: AccountType.eWallet);
  final accounts = [wallet, savings, momo];

  ({String? from, String? to}) hints(String? text, [List<FinancialAccount>? list]) {
    final h = transferAccountHints(text, list ?? accounts);
    return (from: h.fromId, to: h.toId);
  }

  group('đích', () {
    test('"chuyển sang tiết kiệm": đích là Tiết kiệm, chưa rõ nguồn', () {
      expect(hints('chuyển sang tiết kiệm'), (from: null, to: 'savings'));
    });

    test('các từ chỉ đích khác: vào, về, qua, đến, tới', () {
      expect(hints('nạp vào momo').to, 'momo');
      expect(hints('chuyển về ví').to, 'wallet');
      expect(hints('chuyển qua tiết kiệm').to, 'savings');
      expect(hints('chuyển đến tiết kiệm').to, 'savings');
      expect(hints('chuyển tới tiết kiệm').to, 'savings');
    });

    test('bỏ qua từ đệm "tài khoản", "quỹ", "thẻ"', () {
      expect(hints('chuyển tiền sang tài khoản tiết kiệm').to, 'savings');
      expect(hints('chuyển khoản vào quỹ tiết kiệm').to, 'savings');
    });
  });

  group('nguồn', () {
    test('"từ ví sang tiết kiệm": đủ hai đầu', () {
      expect(hints('chuyển từ ví sang tiết kiệm'), (from: 'wallet', to: 'savings'));
    });

    test('"rút từ tiết kiệm về ví": chiều ngược lại', () {
      expect(hints('rút từ tiết kiệm về ví'), (from: 'savings', to: 'wallet'));
    });

    test('chỉ có "từ": nguồn có, đích chưa rõ', () {
      expect(hints('rút từ tiết kiệm'), (from: 'savings', to: null));
    });
  });

  group('khớp tên tài khoản', () {
    test('khớp không phân biệt dấu và hoa thường', () {
      expect(hints('CHUYEN SANG TIET KIEM').to, 'savings');
    });

    test('khớp theo tên nhà cung cấp', () {
      final bank = _account('main', 'TK chính', type: AccountType.bank, provider: 'Vietcombank');
      expect(hints('chuyển sang vietcombank', [wallet, bank]).to, 'main');
    });

    test('"ví momo" chọn MoMo chứ không phải ví tiền mặt tên "Ví"', () {
      expect(hints('nạp vào ví momo').to, 'momo');
    });

    test('tên dài hơn vẫn khớp khi câu nói chỉ một phần: "tiết kiệm" với "Quỹ tiết kiệm du lịch"', () {
      final trip = _account('trip', 'Quỹ tiết kiệm du lịch', type: AccountType.bank);
      expect(hints('chuyển sang tiết kiệm', [wallet, trip]).to, 'trip');
    });
  });

  group('không đoán bừa', () {
    test('không có từ chỉ hướng: không gợi ý gì', () {
      expect(hints('chuyển tiền'), (from: null, to: null));
      expect(hints('chuyển 2 triệu'), (from: null, to: null));
    });

    test('tên lạ hoặc không khớp tài khoản nào', () {
      expect(hints('chuyển sang ngân hàng xyz'), (from: null, to: null));
      expect(hints('chuyển cho mẹ'), (from: null, to: null));
    });

    test('hai tài khoản cùng khớp ngang nhau thì không chọn', () {
      final a = _account('a', 'Tiết kiệm A', type: AccountType.bank);
      final b = _account('b', 'Tiết kiệm B', type: AccountType.bank);
      expect(hints('chuyển sang tiết kiệm', [wallet, a, b]).to, isNull);
    });

    test('nguồn và đích cùng một tài khoản: bỏ cả hai', () {
      expect(hints('chuyển từ tiết kiệm sang tiết kiệm'), (from: null, to: null));
    });

    test('văn bản rỗng hoặc null, danh sách tài khoản rỗng', () {
      expect(hints(null), (from: null, to: null));
      expect(hints(''), (from: null, to: null));
      expect(hints('chuyển sang tiết kiệm', const []), (from: null, to: null));
    });
  });
}
