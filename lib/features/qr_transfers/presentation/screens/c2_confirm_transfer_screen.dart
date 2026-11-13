import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/qr_transfers/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/controllers/qr_transfer_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// C2 — Xác nhận chuyển khoản. Màn chỉ dùng trường BE thật sự hỗ trợ (POST /qr/transfers):
/// KHÔNG có chọn tài khoản nguồn cụ thể kèm số dư, KHÔNG hiển thị phí chuyển khoản, KHÔNG có
/// "AI tự gợi ý danh mục" — chỉ tra cứu danh mục đã nhớ cho người nhận ([lookupCounterparty]),
/// cho sửa tay. Tất cả trường của người nhận đều sửa được: QR quét thiếu phần nào thì người
/// dùng tự nhập phần đó.
class C2ConfirmTransferScreen extends ConsumerStatefulWidget {
  final String? initialReceiverBankBin;
  final String? initialAccountNumber;
  final String? initialReceiverName;
  final BigInt? initialAmountCents;
  final String? initialMessage;

  const C2ConfirmTransferScreen({
    super.key,
    this.initialReceiverBankBin,
    this.initialAccountNumber,
    this.initialReceiverName,
    this.initialAmountCents,
    this.initialMessage,
  });

  @override
  ConsumerState<C2ConfirmTransferScreen> createState() => _C2ConfirmTransferScreenState();
}

class _C2ConfirmTransferScreenState extends ConsumerState<C2ConfirmTransferScreen> {
  late final TextEditingController _accountController;
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _messageController;

  String? _receiverBankBin;
  String? _senderBankBin;
  String? _categoryId;
  bool _creating = false;
  bool _lookingUp = false;
  CounterpartyOverrideEntity? _lookupResult;
  bool _lookupChecked = false;

  @override
  void initState() {
    super.initState();
    _receiverBankBin = widget.initialReceiverBankBin;
    _accountController = TextEditingController(text: widget.initialAccountNumber ?? '');
    _nameController = TextEditingController(text: widget.initialReceiverName ?? '');
    _amountController = TextEditingController(text: widget.initialAmountCents?.toString() ?? '');
    _messageController = TextEditingController(text: widget.initialMessage ?? '');
    if (_receiverBankBin != null && widget.initialAccountNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupCounterparty());
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  BigInt? _parseAmount(String text) => parseAmountInput(text);

  Future<void> _lookupCounterparty() async {
    final bin = _receiverBankBin;
    final account = _accountController.text.trim();
    if (bin == null || account.isEmpty) return;
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
    } catch (_) {
      // Tra cứu thất bại (vd mất mạng tạm thời) không chặn luồng chuyển tiền — người dùng vẫn
      // chọn danh mục tay được, hoặc để trống cho AI đoán như lúc khớp thông báo thật.
      if (mounted) setState(() => _lookupChecked = true);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  QrBankEntity? _findBank(List<QrBankEntity> banks, String? bin) {
    if (bin == null) return null;
    for (final b in banks) {
      if (b.bin == bin) return b;
    }
    return null;
  }

  /// Mở app ngân hàng người gửi qua liên kết sâu VietQR Kit (dl.vietqr.io) với giao dịch đã điền
  /// sẵn. Không có mã app của bên nào (ngân hàng chưa hỗ trợ deep-link), hoặc mở thất bại (chưa
  /// cài app, hệ điều hành không tìm được handler) → KHÔNG rollback ý định đã tạo, chỉ hiện hộp
  /// thoại hướng dẫn chuyển tay kèm số tài khoản/số tiền để người dùng tự copy.
  Future<void> _openBankAppOrShowManualInstructions({
    required String receiverBin,
    required String senderBin,
    required String account,
    required BigInt amount,
  }) async {
    final receiverBanks = ref.read(qrBanksProvider).value ?? const <QrBankEntity>[];
    final senderBanks = ref.read(linkedSenderBanksProvider).value ?? const <QrBankEntity>[];
    final receiverAppCode = _findBank(receiverBanks, receiverBin)?.appCode;
    final senderAppCode = _findBank(senderBanks, senderBin)?.appCode;

    if (receiverAppCode == null || receiverAppCode.isEmpty || senderAppCode == null || senderAppCode.isEmpty) {
      if (mounted) await _showManualTransferDialog(account: account, amount: amount);
      return;
    }

    final message = _messageController.text.trim();
    final deepLink = Uri.parse('https://dl.vietqr.io/pay').replace(queryParameters: {
      'app': senderAppCode,
      'ba': '$account@$receiverAppCode',
      'am': amount.toString(),
      if (message.isNotEmpty) 'tn': message,
      'url': 'https://www.vietqr.io/deeplink',
    });

    try {
      final opened = await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      if (!opened && mounted) await _showManualTransferDialog(account: account, amount: amount);
    } catch (_) {
      if (mounted) await _showManualTransferDialog(account: account, amount: amount);
    }
  }

  Future<void> _showManualTransferDialog({required String account, required BigInt amount}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Không tự mở được app ngân hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ý định chuyển tiền đã được ghi nhận. Mở app ngân hàng và chuyển tay với thông tin:'),
            const SizedBox(height: 12),
            SelectableText('Số tài khoản: $account'),
            SelectableText('Số tiền: ${formatVnd(amount)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu')),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final receiverBin = _receiverBankBin;
    final senderBin = _senderBankBin;
    final account = _accountController.text.trim();
    final amount = _parseAmount(_amountController.text);
    if (receiverBin == null || senderBin == null || account.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ ngân hàng người nhận, số tài khoản, số tiền và ngân hàng gửi.')),
      );
      return;
    }

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

      await _openBankAppOrShowManualInstructions(
        receiverBin: receiverBin,
        senderBin: senderBin,
        account: account,
        amount: amount,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận ý định chuyển tiền. FinMate sẽ tự khớp khi nhận được thông báo ngân hàng.')),
      );
      context.go('/home');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _bankDropdown({
    required Key key,
    required String label,
    required List<QrBankEntity> banks,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: banks.any((b) => b.bin == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
      ),
      items: [for (final b in banks) DropdownMenuItem(value: b.bin, child: Text(b.name))],
      onChanged: onChanged,
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(qrBanksProvider);
    final linkedSenderBanksAsync = ref.watch(linkedSenderBanksProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final noLinkedSenderBanks = linkedSenderBanksAsync.maybeWhen(data: (list) => list.isEmpty, orElse: () => false);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Xác nhận chuyển khoản', style: GlassTypography.headlineMd()),
        ),
        body: SafeArea(
          child: banksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => ref.invalidate(qrBanksProvider), child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
            data: (banks) => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      GlassCard(
                        level: 2,
                        borderRadius: GlassRadius.roundedCardLarge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NGƯỜI NHẬN TIỀN', style: GlassTypography.labelCaps()),
                            const SizedBox(height: 12),
                            _bankDropdown(
                              key: const ValueKey('c2-receiver-bank'),
                              label: 'Ngân hàng người nhận',
                              banks: banks,
                              value: _receiverBankBin,
                              onChanged: (v) => setState(() {
                                _receiverBankBin = v;
                                _lookupChecked = false;
                                _lookupResult = null;
                              }),
                            ),
                            const SizedBox(height: 10),
                            _textField(
                              key: const ValueKey('c2-receiver-account'),
                              controller: _accountController,
                              label: 'Số tài khoản người nhận',
                            ),
                            const SizedBox(height: 10),
                            _textField(
                              key: const ValueKey('c2-receiver-name'),
                              controller: _nameController,
                              label: 'Tên người nhận (tùy chọn)',
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const ValueKey('c2-lookup-counterparty'),
                                onPressed: _lookingUp ? null : _lookupCounterparty,
                                icon: const Icon(LucideIcons.search, size: 16),
                                label: const Text('Tra cứu danh mục đã nhớ'),
                              ),
                            ),
                            if (_lookupChecked)
                              Text(
                                _lookupResult == null
                                    ? 'Chưa có danh mục nào được nhớ cho người nhận này.'
                                    : 'Đã nhớ: ${_lookupResult!.categoryName}.',
                                style: GlassTypography.bodySm(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderRadius: GlassRadius.roundedCardLarge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SỐ TIỀN', style: GlassTypography.labelCaps()),
                            const SizedBox(height: 12),
                            _textField(
                              key: const ValueKey('c2-amount'),
                              controller: _amountController,
                              label: 'Số tiền (₫)',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderRadius: GlassRadius.roundedCardLarge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NGUỒN TIỀN', style: GlassTypography.labelCaps()),
                            const SizedBox(height: 12),
                            linkedSenderBanksAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              error: (e, __) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                                  TextButton(
                                    onPressed: () => ref.invalidate(linkedSenderBanksProvider),
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                              data: (linkedBanks) {
                                if (linkedBanks.isEmpty) {
                                  return Text(
                                    'Chưa liên kết ngân hàng nào hỗ trợ chuyển khoản QR — thêm tài khoản ngân hàng trong Hồ sơ trước.',
                                    style: GlassTypography.bodySm(color: GlassColors.danger),
                                  );
                                }
                                return _bankDropdown(
                                  key: const ValueKey('c2-sender-bank'),
                                  label: 'Ngân hàng của bạn (người gửi)',
                                  banks: linkedBanks,
                                  value: _senderBankBin,
                                  onChanged: (v) => setState(() => _senderBankBin = v),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderRadius: GlassRadius.roundedCardLarge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('NỘI DUNG & DANH MỤC', style: GlassTypography.labelCaps()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _textField(
                              key: const ValueKey('c2-message'),
                              controller: _messageController,
                              label: 'Nội dung chuyển khoản (tùy chọn)',
                            ),
                            const SizedBox(height: 10),
                            categoriesAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (e, __) => const SizedBox.shrink(),
                              data: (categories) => DropdownButtonFormField<String?>(
                                key: const ValueKey('c2-category'),
                                initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                                decoration: InputDecoration(
                                  labelText: 'Danh mục (để trống dùng danh mục đã nhớ nếu có)',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.55),
                                  border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('— Không chọn —')),
                                  for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GlassBottomDock(
                  actions: [
                    GlassPrimaryButton(
                      key: const ValueKey('c2-confirm-transfer'),
                      label: 'Xác nhận chuyển',
                      icon: LucideIcons.send,
                      loading: _creating,
                      onPressed: noLinkedSenderBanks ? null : _confirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
