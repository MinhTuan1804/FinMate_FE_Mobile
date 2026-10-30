import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/config/app_config_controller.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';
import 'package:finmate/features/qr_transfer/presentation/controllers/qr_providers.dart';
import 'package:finmate/features/qr_transfer/presentation/widgets/bank_picker_sheet.dart';

/// Xác nhận chuyển tiền sau khi quét (hoặc nhập tay) rồi mở app ngân hàng. Việc ở đây chỉ là GHI Ý ĐỊNH chuyển tiền để FinMate tự gắn người nhận và danh mục khi thông báo ngân hàng về; tiền do app ngân hàng của
/// bạn chuyển, FinMate không chạm vào.
class QrTransferScreen extends ConsumerStatefulWidget {
  const QrTransferScreen({super.key, this.scanned});

  /// Dữ liệu đọc từ mã QR. Null = nhập tay: người dùng tự chọn ngân hàng nhận và gõ số tài khoản.
  final VietQrData? scanned;

  @override
  ConsumerState<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends ConsumerState<QrTransferScreen> {
  static const _lookupDebounce = Duration(milliseconds: 600);

  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  Timer? _lookupTimer;

  String? _receiverBin;
  String? _senderBin;
  String? _categoryId;
  CounterpartyOverride? _remembered;
  bool _busy = false;
  String? _error;

  /// Cấu hình quét QR do admin đặt (trần số tiền, nội dung mặc định, máy chủ chuyển tiếp).
  QrTransferConfig get _qr => ref.read(appConfigProvider).qrTransfer;

  @override
  void initState() {
    super.initState();
    final scanned = widget.scanned;
    _receiverBin = scanned?.bankBin;
    _accountCtrl.text = scanned?.accountNumber ?? '';
    _amountCtrl.text = scanned?.amount?.toString() ?? '';
    _messageCtrl.text = scanned?.message ?? _qr.defaultMessage;
    _senderBin = ref.read(lastSenderBankBinProvider);
    if (scanned != null) WidgetsBinding.instance.addPostFrameCallback((_) => _lookupRemembered());
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  /// Tra danh mục đã nhớ cho người nhận này để đặt sẵn. Lỗi thì bỏ qua: đây là bước không bắt buộc, server vẫn tự gắn danh mục đã nhớ khi tạo.
  Future<void> _lookupRemembered() async {
    final bin = _receiverBin;
    final account = _accountCtrl.text.trim();
    if (bin == null || account.length < 4) return;
    try {
      final found = await ref.read(qrTransferRepositoryProvider).lookupOverride(bankBin: bin, accountNumber: account);
      if (!mounted) return;
      setState(() {
        _remembered = found;
        if (found != null && _categoryId == null) _categoryId = found.categoryId;
      });
    } on Object {
      // giữ nguyên, không chặn luồng
    }
  }

  void _onAccountChanged(String _) {
    _lookupTimer?.cancel();
    _lookupTimer = Timer(_lookupDebounce, _lookupRemembered);
    setState(() => _remembered = null);
  }

  int? get _amount {
    final value = int.tryParse(_amountCtrl.text.trim());
    return (value != null && value > 0 && value <= _qr.maxAmount) ? value : null;
  }

  Future<bool> _openBankApp(QrBank sender, QrBank receiver, int amount) async {
    final uri = buildVietQrDeeplink(
      host: _qr.deeplinkHost,
      returnUrl: _qr.deeplinkReturnUrl,
      senderAppCode: sender.appCode,
      receiverAppCode: receiver.appCode,
      accountNumber: _accountCtrl.text.trim(),
      amount: amount,
      message: _messageCtrl.text.trim().isEmpty ? _qr.defaultMessage : _messageCtrl.text.trim(),
      beneficiaryName: widget.scanned?.beneficiaryName,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<void> _submit(List<QrBank> banks, {bool recordIntent = true}) async {
    final amount = _amount;
    final sender = banks.where((b) => b.bin == _senderBin).firstOrNull;
    final receiver = banks.where((b) => b.bin == _receiverBin).firstOrNull;
    if (amount == null || sender == null || receiver == null || _accountCtrl.text.trim().length < 4) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    QrTransfer? created;
    if (recordIntent) {
      try {
        created = await ref.read(qrTransferRepositoryProvider).createTransfer(
              receiverBankBin: receiver.bin,
              receiverAccountNumber: _accountCtrl.text.trim(),
              receiverName: widget.scanned?.beneficiaryName,
              senderBankBin: sender.bin,
              amount: amount,
              message: _messageCtrl.text.trim().isEmpty ? _qr.defaultMessage : _messageCtrl.text.trim(),
              categoryId: _categoryId,
            );
      } on ApiException catch (e) {
        _fail(e.message);
        return;
      } on Object {
        _fail('Không ghi nhận được lần chuyển này. Kiểm tra mạng rồi thử lại.');
        return;
      }
    }

    ref.read(lastSenderBankBinProvider.notifier).state = sender.bin;
    final launched = await _openBankApp(sender, receiver, amount);
    if (!mounted) return;
    if (!launched) {
      // Không mở được app thì không để lại bản ghi chờ vô nghĩa.
      if (created != null) unawaited(ref.read(qrTransferRepositoryProvider).cancelTransfer(created.id).catchError((_) {}));
      _fail('Không mở được app ${sender.name}. Hãy chắc đã cài app này trên máy rồi thử lại.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(recordIntent
          ? 'Đã mở app ${sender.name}. Khi thông báo chuyển khoản về, FinMate sẽ tự gắn người nhận cho giao dịch.'
          : 'Đã mở app ${sender.name}.'),
    ));
    context.go('/home');
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _pickReceiver(List<QrBank> banks) async {
    final picked = await showBankPicker(context, banks: banks, title: 'Ngân hàng của người nhận', selectedBin: _receiverBin);
    if (picked == null) return;
    setState(() {
      _receiverBin = picked.bin;
      _remembered = null;
    });
    _lookupRemembered();
  }

  Future<void> _pickSender(List<QrBank> banks) async {
    final picked = await showBankPicker(context, banks: banks, title: 'Bạn dùng app ngân hàng nào để chuyển?', selectedBin: _senderBin, showMatchHint: true);
    if (picked != null) setState(() => _senderBin = picked.bin);
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(qrBanksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.scanned == null ? 'Nhập thông tin người nhận' : 'Chuyển tiền')),
      body: banksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorRetry(message: 'Không tải được danh sách ngân hàng.', onRetry: () => ref.invalidate(qrBanksProvider)),
        data: (banks) => _buildForm(context, banks),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<QrBank> banks) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final receiver = banks.where((b) => b.bin == _receiverBin).firstOrNull;
    final sender = banks.where((b) => b.bin == _senderBin).firstOrNull;
    final scanned = widget.scanned;

    if (scanned != null && receiver == null) {
      return _ErrorRetry(
        message: 'Ngân hàng của người nhận (mã ${scanned.bankBin}) chưa có trong danh sách hỗ trợ mở app tự động. Bạn vẫn có thể tự mở app ngân hàng để chuyển.',
        onRetry: () => context.pop(),
        retryLabel: 'Quay lại',
      );
    }

    final amount = _amount;
    final ready = !_busy && amount != null && sender != null && receiver != null && _accountCtrl.text.trim().length >= 4;
    final categories = ref.watch(categoriesProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionTitle('Người nhận'),
          if (scanned != null)
            _InfoCard(
              icon: LucideIcons.landmark,
              title: receiver!.name,
              lines: [scanned.accountNumber, if (scanned.beneficiaryName != null) scanned.beneficiaryName!],
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              leading: const Icon(LucideIcons.landmark, size: 20),
              title: Text(receiver?.name ?? 'Chọn ngân hàng của người nhận'),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => _pickReceiver(banks),
            ),
            TextField(
              controller: _accountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(32)],
              decoration: const InputDecoration(labelText: 'Số tài khoản người nhận'),
              onChanged: _onAccountChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('Số tiền và nội dung'),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            style: AppTypography.tabular(AppTypography.h3(context)),
            decoration: InputDecoration(
              labelText: 'Số tiền (VND)',
              helperText: amount == null ? 'Bắt buộc: FinMate dùng số tiền này để khớp với thông báo ngân hàng thật.' : formatVnd(BigInt.from(amount)),
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _messageCtrl,
            maxLength: _qr.maxMessageLength,
            decoration: const InputDecoration(labelText: 'Nội dung chuyển khoản', helperText: 'Nên viết không dấu: nhiều ngân hàng không nhận dấu tiếng Việt.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Danh mục'),
          Text(
            _remembered != null
                ? 'Đã nhớ danh mục "${_remembered!.categoryName}" cho người nhận này. Đổi lại bên dưới nếu muốn.'
                : 'Chọn một danh mục thì lần sau chuyển cho đúng người này FinMate tự gắn luôn. Không chọn thì để AI đoán.',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: AppSpacing.md),
          categories.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('Không tải được danh mục.', style: AppTypography.caption(context)),
            data: (list) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ChoiceChip(label: const Text('Để AI đoán'), selected: _categoryId == null, onSelected: (_) => setState(() => _categoryId = null)),
                for (final c in list)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c.slug), size: 16),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('Mở bằng app ngân hàng của bạn'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: const Icon(LucideIcons.landmark, size: 20),
            title: Text(sender?.name ?? 'Chọn app ngân hàng để chuyển'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _pickSender(banks),
          ),
          if (sender != null && !sender.canMatchNotifications)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _Notice(
                icon: LucideIcons.circleAlert,
                color: AppColors.warning,
                text: 'FinMate chưa đọc được thông báo của ${sender.name}, nên giao dịch sau khi chuyển sẽ không tự gắn người nhận. Bạn vẫn chuyển tiền bình thường.',
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Notice(icon: LucideIcons.circleAlert, color: AppColors.danger, text: _error!, live: true),
            if (sender != null && receiver != null && amount != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _busy ? null : () => _submit(banks, recordIntent: false), child: const Text('Vẫn mở app ngân hàng (không ghi nhận)')),
              ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: ready ? () => _submit(banks) : null,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.externalLink, size: 18),
            label: Text(_busy ? 'Đang xử lý...' : 'Ghi nhận và mở app ngân hàng'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Số tài khoản, số tiền và nội dung được chuyển tiếp qua dịch vụ ${_qr.deeplinkHost} để mở đúng app ngân hàng. FinMate không chuyển tiền thay bạn.',
            style: AppTypography.caption(context).copyWith(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.h3(context)),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.lines});

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge(context)),
                for (final line in lines) Text(line, style: AppTypography.tabular(AppTypography.body(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text, this.live = false});

  final IconData icon;
  final Color color;
  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: live,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppSpacing.roundedMedium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: AppTypography.caption(context))),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry, this.retryLabel = 'Thử lại'});

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      );
}
