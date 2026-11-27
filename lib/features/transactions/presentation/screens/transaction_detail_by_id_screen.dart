import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/transactions/data/transaction_links_repository.dart';
import 'package:finmate/features/transactions/presentation/screens/transaction_detail_screen.dart';

/// Mở chi tiết giao dịch khi chỉ có id (bấm push nghi trùng, hoàn tiền, chuyển ví, khoản vay): tải từ server rồi hiện màn chi tiết thường.
class TransactionDetailByIdScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailByIdScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(transactionDetailProvider(transactionId)).when(
          data: (tx) => TransactionDetailScreen(transaction: tx),
          loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Chi tiết giao dịch')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(transactionDetailProvider(transactionId)),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
