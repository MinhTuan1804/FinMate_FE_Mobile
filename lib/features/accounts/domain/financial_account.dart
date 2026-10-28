import 'package:finmate/core/format/money.dart';

enum AccountType {
  bank('Bank', 'Ngân hàng'),
  eWallet('EWallet', 'Ví điện tử'),
  cash('Cash', 'Tiền mặt');

  final String apiValue;
  final String label;
  const AccountType(this.apiValue, this.label);

  static AccountType fromApi(String value) =>
      AccountType.values.firstWhere((t) => t.apiValue == value, orElse: () => AccountType.cash);
}

/// Tài khoản/ví của người dùng (GET /financial-accounts)
class FinancialAccount {
  final String id;
  final AccountType type;
  final String name;
  final String? providerName;
  final String? packageName;
  final bool isMonitored;
  final BigInt balanceCents;

  const FinancialAccount({
    required this.id,
    required this.type,
    required this.name,
    this.providerName,
    this.packageName,
    this.isMonitored = true,
    required this.balanceCents,
  });

  factory FinancialAccount.fromJson(Map<String, dynamic> json) => FinancialAccount(
        id: json['id'] as String,
        type: AccountType.fromApi(json['accountType'] as String? ?? 'Cash'),
        name: json['accountName'] as String? ?? '',
        providerName: json['providerDisplayName'] as String?,
        packageName: json['packageName'] as String?,
        isMonitored: json['isMonitored'] as bool? ?? true,
        balanceCents: parseCents(json['balanceCents']),
      );
}

/// Ứng dụng ngân hàng/ví mà FinMate có thể theo dõi (GET /financial-accounts/providers)
class AccountProviderInfo {
  final String id;
  final String providerKey;
  final String displayName;
  final String packageName;
  final AccountType type;

  const AccountProviderInfo({
    required this.id,
    required this.providerKey,
    required this.displayName,
    required this.packageName,
    required this.type,
  });

  factory AccountProviderInfo.fromJson(Map<String, dynamic> json) => AccountProviderInfo(
        id: json['id'] as String,
        providerKey: json['providerKey'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        type: AccountType.fromApi(json['accountType'] as String? ?? 'Bank'),
      );
}
