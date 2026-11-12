import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/qr_transfers/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/controllers/qr_transfer_controller.dart';

final _dateTimeFormat = DateFormat('dd/MM HH:mm');

String _statusLabel(String value) => switch (value) {
      'Pending' => 'Đang chờ',
      'Matched' => 'Đã khớp',
      'Cancelled' => 'Đã hủy',
      _ => value,
    };

Color _statusColor(String value) => switch (value) {
      'Pending' => AppColors.secondary,
      'Matched' => AppColors.safe,
      'Cancelled' => AppColors.danger,
      _ => AppColors.secondary,
    };

/// Màn test QR chuyển khoản: tạo ý định chuyển tiền (không có camera — nhập tay để test),
/// xem/lọc/hủy các lần đã quét, và quản lý danh mục đã nhớ cho từng người nhận.
class QrTransferScreen extends ConsumerStatefulWidget {
  const QrTransferScreen({super.key});

  @override
  ConsumerState<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends ConsumerState<QrTransferScreen> {
  final _accountController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  String? _receiverBankBin;
  String? _senderBankBin;
  String? _categoryId;
  bool _creating = false;
  bool _lookingUp = false;
  CounterpartyOverrideEntity? _lookupResult;
  bool _lookupChecked = false;

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  BigInt? _parseCents(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : BigInt.parse(digits);
  }

  Future<void> _lookupCounterparty() async {
    final bin = _receiverBankBin;
    final account = _accountController.text.trim();
    if (bin == null || account.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _lookingUp = true;
      _lookupChecked = false;
    });
    try {
      final result = await ref.read(qrTransferRepositoryProvider).lookupCounterparty(bankBin: bin, accountNumber: account);
      if (mounted) {
        setState(() {
          _lookupResult = result;
          _lookupChecked = true;
          if (result != null) _categoryId = result.categoryId;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _create() async {
    final receiverBin = _receiverBankBin;
    final senderBin = _senderBankBin;
    final amount = _parseCents(_amountController.text);
    final account = _accountController.text.trim();
    if (receiverBin == null || senderBin == null || account.isEmpty || amount == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    try {
      await ref.read(qrTransferRepositoryProvider).createTransfer(
            receiverBankBin: receiverBin,
            receiverAccountNumber: account,
            receiverName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            senderBankBin: senderBin,
            amountCents: amount,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
            categoryId: _categoryId,
          );
      if (!mounted) return;
      ref.invalidate(qrTransfersControllerProvider);
      ref.invalidate(counterpartyOverridesControllerProvider);
      setState(() {
        _accountController.clear();
        _nameController.clear();
        _amountController.clear();
        _messageController.clear();
        _categoryId = null;
        _lookupResult = null;
        _lookupChecked = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo ý định chuyển tiền. Mở app ngân hàng để hoàn tất.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _cancelTransfer(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(qrTransfersControllerProvider.notifier).cancel(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _editOverrideCategory(CounterpartyOverrideEntity override) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!mounted || categories.isEmpty) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Đổi danh mục đã nhớ'),
        children: [
          for (final c in categories)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, c.id), child: Text(c.name)),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(counterpartyOverridesControllerProvider.notifier).update(override.id, chosen);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _deleteOverride(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(counterpartyOverridesControllerProvider.notifier).delete(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bankDropdown({
    required String keyName,
    required String label,
    required List<QrBankEntity> banks,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(keyName),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final b in banks)
          DropdownMenuItem(value: b.bin, child: Text(b.canMatchNotifications ? '${b.name} (tự khớp)' : b.name)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildCreateForm(BuildContext context, List<QrBankEntity> banks) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return _sectionCard(
      title: 'Tạo ý định chuyển tiền (nhập tay để test, không quét camera)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bankDropdown(
            keyName: 'qr-receiver-bank',
            label: 'Ngân hàng người nhận',
            banks: banks,
            value: _receiverBankBin,
            onChanged: (v) => setState(() {
              _receiverBankBin = v;
              _lookupChecked = false;
              _lookupResult = null;
            }),
          ),
          TextField(
            key: const ValueKey('qr-receiver-account'),
            controller: _accountController,
            decoration: const InputDecoration(labelText: 'Số tài khoản người nhận'),
          ),
          TextField(
            key: const ValueKey('qr-receiver-name'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tên người nhận (tùy chọn)'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('qr-lookup-counterparty'),
              onPressed: _lookingUp ? null : _lookupCounterparty,
              child: const Text('Tra cứu danh mục đã nhớ'),
            ),
          ),
          if (_lookupChecked)
            Text(
              _lookupResult == null
                  ? 'Chưa có danh mục nào được nhớ cho người nhận này.'
                  : 'Đã nhớ: ${_lookupResult!.categoryName}.',
              style: AppTypography.caption(context),
            ),
          const SizedBox(height: AppSpacing.sm),
          _bankDropdown(
            keyName: 'qr-sender-bank',
            label: 'Ngân hàng của bạn (người gửi)',
            banks: banks,
            value: _senderBankBin,
            onChanged: (v) => setState(() => _senderBankBin = v),
          ),
          TextField(
            key: const ValueKey('qr-amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
          ),
          TextField(
            key: const ValueKey('qr-message'),
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Nội dung chuyển khoản (tùy chọn)'),
          ),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, __) => const SizedBox.shrink(),
            data: (categories) => DropdownButtonFormField<String?>(
              key: const ValueKey('qr-category'),
              // Danh mục đã nhớ (lookupCounterparty) có thể không còn trong danh sách hiện tại (vd đã bị
              // xoá/ẩn) — chỉ pre-select khi id đó thực sự có trong items, tránh crash DropdownButtonFormField.
              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Danh mục (tùy chọn — để trống dùng danh mục đã nhớ hoặc để AI đoán)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Không chọn —')),
                for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            key: const ValueKey('qr-create-transfer'),
            onPressed: _creating ? null : _create,
            child: const Text('Tạo ý định chuyển'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersSection(BuildContext context, AsyncValue<List<QrTransferEntity>> async) {
    final controller = ref.read(qrTransfersControllerProvider.notifier);
    return _sectionCard(
      title: 'Lần quét đã tạo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final entry in const [(null, 'Tất cả'), ('Pending', 'Đang chờ'), ('Matched', 'Đã khớp'), ('Cancelled', 'Đã hủy')])
                ChoiceChip(
                  key: ValueKey('qr-status-filter-${entry.$1 ?? 'all'}'),
                  label: Text(entry.$2),
                  selected: controller.status == entry.$1,
                  onSelected: (_) => controller.setStatusFilter(entry.$1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (e, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
                TextButton(onPressed: () => ref.invalidate(qrTransfersControllerProvider), child: const Text('Thử lại')),
              ],
            ),
            data: (transfers) {
              if (transfers.isEmpty) {
                return Text('Chưa có lần quét nào.', style: AppTypography.caption(context));
              }
              return Column(
                children: [
                  for (final t in transfers)
                    Padding(
                      key: ValueKey('qr-transfer-${t.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.receiverName ?? t.receiverAccountNumber} · ${t.formattedAmount}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(_statusLabel(t.status), style: TextStyle(color: _statusColor(t.status), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(
                            '${t.receiverBankName} → gửi từ ${t.senderBankName} · ${_dateTimeFormat.format(t.scannedAt)}'
                            '${t.categoryName != null ? ' · ${t.categoryName}' : ''}',
                            style: AppTypography.caption(context),
                          ),
                          if (t.isExpired) Text('Đã quá hạn, khó khớp.', style: AppTypography.caption(context).copyWith(color: AppColors.warning)),
                          if (t.isPending)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                key: ValueKey('qr-cancel-${t.id}'),
                                onPressed: () => _cancelTransfer(t.id),
                                child: const Text('Hủy'),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverridesSection(BuildContext context, AsyncValue<List<CounterpartyOverrideEntity>> async) {
    return _sectionCard(
      title: 'Danh mục đã nhớ cho từng người nhận',
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
            TextButton(onPressed: () => ref.invalidate(counterpartyOverridesControllerProvider), child: const Text('Thử lại')),
          ],
        ),
        data: (overrides) {
          if (overrides.isEmpty) {
            return Text('Chưa nhớ danh mục cho ai.', style: AppTypography.caption(context));
          }
          return Column(
            children: [
              for (final o in overrides)
                Padding(
                  key: ValueKey('qr-override-${o.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.displayName ?? o.accountNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${o.bankName} · ${o.categoryName}', style: AppTypography.caption(context)),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('qr-edit-override-${o.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editOverrideCategory(o),
                      ),
                      IconButton(
                        key: ValueKey('qr-delete-override-${o.id}'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteOverride(o.id),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(qrBanksProvider);
    final transfersAsync = ref.watch(qrTransfersControllerProvider);
    final overridesAsync = ref.watch(counterpartyOverridesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QR chuyển khoản')),
      body: banksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage(e), style: AppTypography.caption(context).copyWith(color: AppColors.danger)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: () => ref.invalidate(qrBanksProvider), child: const Text('Thử lại')),
            ],
          ),
        ),
        data: (banks) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildCreateForm(context, banks),
            const SizedBox(height: AppSpacing.lg),
            _buildTransfersSection(context, transfersAsync),
            const SizedBox(height: AppSpacing.lg),
            _buildOverridesSection(context, overridesAsync),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
