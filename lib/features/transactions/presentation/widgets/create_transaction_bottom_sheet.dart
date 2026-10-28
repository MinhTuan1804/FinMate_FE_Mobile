import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

/// Bottom Sheet nhập liệu giao dịch (BR-21 -> BR-24). Giọng nói và OCR chưa sẵn sàng nên bị vô hiệu.
class CreateTransactionBottomSheet extends ConsumerStatefulWidget {
  final int initialTab;

  const CreateTransactionBottomSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTransactionBottomSheet(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<CreateTransactionBottomSheet> createState() => _CreateTransactionBottomSheetState();
}

class _CreateTransactionBottomSheetState extends ConsumerState<CreateTransactionBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);

  // Thủ công
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  bool _isSaving = false;
  String? _classicError;

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Tài khoản đang chọn (mặc định là tài khoản đầu tiên nếu chưa chọn hoặc không còn tồn tại)
  String _effectiveId(String? selected, List<FinancialAccount> accounts, {int fallbackIndex = 0}) {
    if (selected != null && accounts.any((a) => a.id == selected)) return selected;
    return accounts[math.min(fallbackIndex, accounts.length - 1)].id;
  }

  Future<void> _handleClassicSave(List<FinancialAccount> accounts) async {
    if (_isSaving) return;
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) {
      setState(() => _classicError = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    final from = _effectiveId(_accountId, accounts);
    final to = _effectiveId(_toAccountId, accounts, fallbackIndex: 1);
    final isTransfer = _type == TransactionType.transfer;
    if (isTransfer && accounts.length < 2) {
      setState(() => _classicError = 'Cần ít nhất 2 tài khoản để chuyển tiền');
      return;
    }
    if (isTransfer && from == to) {
      setState(() => _classicError = 'Tài khoản nguồn và đích không được trùng nhau');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(transactionControllerProvider.notifier);
    final description = _descController.text.trim();

    setState(() {
      _isSaving = true;
      _classicError = null;
    });
    try {
      if (isTransfer) {
        await controller.transferInternal(
          amountCents: amount,
          fromAccountId: from,
          toAccountId: to,
          description: description.isEmpty ? 'Chuyển tiền nội bộ' : description,
          date: DateTime.now(),
        );
      } else {
        await controller.createTransaction(
          accountId: from,
          categoryId: _categoryId,
          amountCents: amount,
          type: _type,
          description: description,
          date: DateTime.now(),
        );
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã thêm giao dịch thành công!'), backgroundColor: AppColors.safe),
      );
    } catch (e) {
      if (mounted) setState(() => _classicError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createWallet() async {
    final balanceController = TextEditingController(text: '0');
    final balance = await showDialog<BigInt>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo ví tiền mặt'),
        content: TextField(
          controller: balanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Số dư hiện có (VNĐ)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final text = balanceController.text.trim();
              final value = text.isEmpty ? BigInt.zero : parseAmountInput(text, allowZero: true);
              if (value != null) Navigator.pop(ctx, value);
            },
            child: const Text('Tạo ví'),
          ),
        ],
      ),
    );
    balanceController.dispose();
    if (balance == null || !mounted) return;

    try {
      await ref.read(accountsControllerProvider.notifier).create(
            name: 'Ví tiền mặt',
            type: AccountType.cash,
            initialBalanceCents: balance,
          );
    } catch (e) {
      if (mounted) setState(() => _classicError = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = math.min(media.size.height * 0.75, media.size.height - keyboard - media.padding.top - 16);

    // Đẩy sheet lên trên bàn phím để không che ô nhập
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(LucideIcons.sparkles, size: 18), text: 'AI Text'),
                Tab(icon: Icon(LucideIcons.mic, size: 18), text: 'Giọng nói'),
                Tab(icon: Icon(LucideIcons.scanLine, size: 18), text: 'Hóa đơn'),
                Tab(icon: Icon(LucideIcons.pencil, size: 18), text: 'Thủ công'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAssistantTab(),
                  _buildAssistantTab(
                    icon: LucideIcons.mic,
                    description: 'Nói tự nhiên, FinMate chuyển thành chữ để bạn kiểm tra rồi gửi cho trợ lý.',
                    button: 'Nói để ghi chép',
                    route: '/assistant?start=voice',
                  ),
                  _buildAssistantTab(
                    icon: LucideIcons.scanLine,
                    description: 'Chụp hoặc chọn ảnh hóa đơn, FinMate đọc số tiền và cửa hàng để bạn kiểm tra rồi lưu.',
                    button: 'Quét hóa đơn',
                    route: '/assistant?start=scan',
                  ),
                  _buildClassicTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorText(String message) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );

  // AI Text / Giọng nói / Hóa đơn: chuyển sang màn trợ lý (chat)
  Widget _buildAssistantTab({
    IconData icon = LucideIcons.sparkles,
    String description = 'Nhắn tự nhiên như "ăn phở 45k", FinMate tự ghi chép hoặc trả lời câu hỏi chi tiêu của bạn.',
    String button = 'Mở trợ lý',
    String route = '/assistant',
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 36, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body(context),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(route);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
            child: Text(button),
          ),
        ],
      ),
    );
  }


  // 4. Thủ công (BR-24, BR-26, BR-27)
  Widget _buildClassicTab(bool isDark) {
    return ref.watch(accountsControllerProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage(e), textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => ref.read(accountsControllerProvider.notifier).load(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
          data: (accounts) => accounts.isEmpty ? _buildNoAccount() : _buildClassicForm(accounts),
        );
  }

  Widget _buildNoAccount() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wallet, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Bạn chưa có tài khoản nào', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Tạo một ví để bắt đầu ghi chép giao dịch.', style: AppTypography.caption(context), textAlign: TextAlign.center),
            if (_classicError != null) _errorText(_classicError!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createWallet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
              ),
              child: const Text('Tạo ví tiền mặt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountDropdown({
    required String label,
    required IconData icon,
    required List<FinancialAccount> accounts,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildClassicForm(List<FinancialAccount> accounts) {
    final from = _effectiveId(_accountId, accounts);
    final to = _effectiveId(_toAccountId, accounts, fallbackIndex: 1);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (label, type) in const [
                ('Chi tiêu', TransactionType.expense),
                ('Thu nhập', TransactionType.income),
                ('Chuyển tiền', TransactionType.transfer),
              ]) ...[
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(label)),
                    selected: _type == type,
                    onSelected: (v) {
                      if (v) setState(() => _type = type);
                    },
                  ),
                ),
                if (type != TransactionType.transfer) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền (VNĐ)',
              prefixIcon: Icon(LucideIcons.coins, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          if (_type == TransactionType.transfer) ...[
            _accountDropdown(
              label: 'Từ tài khoản',
              icon: LucideIcons.arrowUpRight,
              accounts: accounts,
              value: from,
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            _accountDropdown(
              label: 'Đến tài khoản',
              icon: LucideIcons.arrowDownLeft,
              accounts: accounts,
              value: to,
              onChanged: (v) => setState(() => _toAccountId = v),
            ),
          ] else ...[
            DropdownButtonFormField<String?>(
              key: ValueKey('cat-$_categoryId-${categories.length}'),
              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Danh mục', prefixIcon: Icon(LucideIcons.tag, size: 20)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Chưa phân loại')),
                ...categories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(categoryIcon(c.slug), size: 18),
                        const SizedBox(width: 8),
                        Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            _accountDropdown(
              label: 'Tài khoản',
              icon: LucideIcons.wallet,
              accounts: accounts,
              value: from,
              onChanged: (v) => setState(() => _accountId = v),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(LucideIcons.fileText, size: 20)),
          ),
          if (_classicError != null) _errorText(_classicError!),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _handleClassicSave(accounts),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Lưu giao dịch'),
          ),
        ],
      ),
    );
  }
}
