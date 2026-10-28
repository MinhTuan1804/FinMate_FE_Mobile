import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Một trang giao dịch; nextCursor == null nghĩa là hết dữ liệu
class TransactionPage {
  final List<TransactionEntity> items;
  final String? nextCursor;

  const TransactionPage({required this.items, this.nextCursor});
}
