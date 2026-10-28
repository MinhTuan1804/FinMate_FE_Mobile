import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/speech_end_detector.dart';
import 'package:finmate/features/assistant/data/voice_recorder.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';

/// Chatbot ghi chép và hỏi chi tiêu bằng ngôn ngữ tự nhiên
class AssistantScreen extends ConsumerStatefulWidget {
  /// 'voice' hoặc 'scan': vào chat là bắt đầu nói / mở chọn ảnh hóa đơn
  final String? startWith;

  const AssistantScreen({super.key, this.startWith});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  Timer? _recordLimit;
  StreamSubscription<double>? _levelSub;
  SpeechEndDetector _detector = SpeechEndDetector();

  /// 0..1 để vẽ thanh âm lượng khi đang ghi
  double _level = 0;

  /// Giữ lại để dispose dùng được (không đọc `ref` sau khi widget đã bị hủy)
  late final VoiceRecorder _recorder;
  bool _listening = false;

  /// STT trên server nhận tối đa 60 giây
  static const _maxRecording = Duration(seconds: 55);

  static const _suggestions = ['ăn phở 45k', 'tháng này tôi tiêu bao nhiêu?'];

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureAccount(ref.read(accountsControllerProvider).valueOrNull);
      if (widget.startWith == 'voice') _toggleVoice();
      if (widget.startWith == 'scan') _pickReceipt();
    });
  }

  @override
  void dispose() {
    _recordLimit?.cancel();
    _levelSub?.cancel();
    if (_listening) _recorder.cancel();
    _input.dispose();
    super.dispose();
  }

  /// Mặc định gửi vào ví tiền mặt (nếu có), nếu không thì tài khoản đầu tiên
  void _ensureAccount(List<FinancialAccount>? accounts) {
    final controller = ref.read(assistantControllerProvider.notifier);
    if (accounts == null || accounts.isEmpty) return;
    final selected = ref.read(assistantControllerProvider).selectedAccountId;
    if (selected != null && accounts.any((a) => a.id == selected)) return;
    final fallback = accounts.firstWhere((a) => a.type == AccountType.cash, orElse: () => accounts.first);
    controller.selectAccount(fallback.id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Bấm mic: bắt đầu ghi âm, bấm lần nữa để dừng và gửi. Server đổi giọng thành chữ rồi xử lý như câu chat (Rasa trước).
  Future<void> _toggleVoice() async {
    final recorder = _recorder;
    if (_listening) {
      await _finishRecording();
      return;
    }
    switch (await recorder.start()) {
      case VoiceStart.denied:
        _snack('Cần quyền micro để ghi âm. Vào Cài đặt > Ứng dụng > FinMate > Quyền > Micro để bật.');
        return;
      case VoiceStart.failed:
        _snack('Không bật được micro. Bạn có thể nhập bằng bàn phím.');
        return;
      case VoiceStart.started:
        break;
    }
    if (!mounted) {
      await recorder.cancel();
      return;
    }
    _detector = SpeechEndDetector();
    setState(() {
      _listening = true;
      _level = 0;
    });
    _recordLimit?.cancel();
    _recordLimit = Timer(_maxRecording, _finishRecording);
    _levelSub?.cancel();
    _levelSub = recorder.levels(_detector.interval).listen(_onLevel);
  }

  /// Mỗi mẫu âm lượng: vẽ thanh nghe và tự dừng khi người dùng nói xong (hoặc không ai nói)
  void _onLevel(double db) {
    if (!_listening || !mounted) return;
    setState(() => _level = ((db + 60) / 60).clamp(0.0, 1.0));
    switch (_detector.feed(db)) {
      case SpeechSignal.listening:
        break;
      case SpeechSignal.ended:
        _finishRecording();
      case SpeechSignal.noSpeech:
        _abortRecording();
    }
  }

  /// Không ai nói: bỏ bản ghi, không gửi gì
  Future<void> _abortRecording() async {
    _recordLimit?.cancel();
    _levelSub?.cancel();
    if (!_listening) return;
    setState(() => _listening = false);
    await _recorder.cancel();
    _snack('Mình chưa nghe thấy gì, bạn thử lại nhé');
  }

  Future<void> _finishRecording() async {
    _recordLimit?.cancel();
    _levelSub?.cancel();
    if (!_listening) return;
    setState(() => _listening = false); // tắt ngay để không dừng hai lần (tự dừng và bấm tay cùng lúc)
    final path = await _recorder.stop();
    if (!mounted) return;
    if (path == null) {
      _snack('Mình chưa nghe thấy gì, bạn thử lại nhé');
      return;
    }
    ref.read(assistantControllerProvider.notifier).sendVoice(path);
  }

  /// Bấm quét: chọn nguồn ảnh rồi gửi thẳng vào chat
  Future<void> _pickReceipt() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.scanLine), title: const Text('Quét bill'), onTap: () => Navigator.pop(ctx, 'scan')),
            ListTile(leading: const Icon(LucideIcons.camera), title: const Text('Chụp ảnh'), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(LucideIcons.image), title: const Text('Chọn ảnh từ thư viện'), onTap: () => Navigator.pop(ctx, 'gallery')),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final source = ref.read(receiptImageSourceProvider);
    try {
      final path = switch (choice) {
        'scan' => await source.scanBill(),
        'camera' => await source.pickFromCamera(),
        _ => await source.pickFromGallery(),
      };
      if (path == null || !mounted) return;
      ref.read(assistantControllerProvider.notifier).scanReceipt(path);
    } on ImageSourceException catch (e) {
      _snack('${e.message} Bạn có thể bật quyền trong Cài đặt > Ứng dụng > FinMate > Quyền.');
    }
  }

  void _send(String text) => ref.read(assistantControllerProvider.notifier).send(text);

  Future<void> _submitInput() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(assistantControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const <FinancialAccount>[];
    ref.listen(accountsControllerProvider, (_, next) => _ensureAccount(next.valueOrNull));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = accounts.where((a) => a.id == state.selectedAccountId).firstOrNull;

    final messages = state.messages;
    final itemCount = messages.length + (state.isSending ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý FinMate')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty && !state.isSending
                  ? _buildEmpty(context)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: itemCount,
                      itemBuilder: (context, i) {
                        if (state.isSending && i == 0) return _typing(context, scanning: messages.isNotEmpty && messages.last is ImageNote);
                        final message = messages[messages.length - 1 - (i - (state.isSending ? 1 : 0))];
                        return _messageView(message);
                      },
                    ),
            ),
            if (accounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    key: const ValueKey('account-chip'),
                    onSelected: (id) => ref.read(assistantControllerProvider.notifier).selectAccount(id),
                    itemBuilder: (context) => [
                      for (final a in accounts) PopupMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: AppSpacing.roundedPill,
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.wallet, size: 14),
                        const SizedBox(width: 6),
                        Text('Ghi vào: ${selected?.name ?? 'chọn tài khoản'}', style: AppTypography.caption(context)),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown, size: 14),
                      ]),
                    ),
                  ),
                ),
              ),
            _buildInput(context, state.isSending),
          ],
        ),
      ),
    );
  }

  Widget _messageView(ChatMessage message) => switch (message) {
        UserText m => UserBubble(text: m.text),
        ImageNote m => ImageBubble(path: m.path),
        AssistantText m => AssistantBubble(text: m.text),
        SavedCard m => SavedCardView(tx: m.tx),
        SummaryCard m => SummaryCardView(summary: m.summary),
        DraftCard m => DraftCardView(card: m),
        DraftBatchCard m => DraftBatchCardView(card: m),
        GoalDraftCard m => GoalDraftCardView(card: m),
        ErrorNote m => ErrorNoteView(note: m, onRetry: () => ref.read(assistantControllerProvider.notifier).retry(m.id)),
      };

  Widget _typing(BuildContext context, {bool scanning = false}) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(scanning ? 'Đang đọc hóa đơn...' : 'Đang trả lời...', style: AppTypography.caption(context)),
        ),
      );

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sparkles, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Bạn muốn ghi gì hôm nay?', style: AppTypography.h3(context)),
            const SizedBox(height: 4),
            Text('Nhắn tự nhiên, FinMate sẽ ghi chép hoặc trả lời giúp bạn.', textAlign: TextAlign.center, style: AppTypography.caption(context)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _send(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, bool sending) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitInput(),
              decoration: InputDecoration(hintText: _listening ? 'Đang nghe... nói xong mình sẽ tự gửi' : (sending ? 'Đang xử lý...' : 'Nhắn: "ăn phở 45k"...')),
            ),
          ),
          IconButton(
            key: const ValueKey('scan-button'),
            tooltip: 'Quét hóa đơn',
            onPressed: sending ? null : _pickReceipt,
            icon: const Icon(LucideIcons.scanLine, size: 22),
            color: AppColors.primary,
          ),
          IconButton(
            key: const ValueKey('mic-button'),
            tooltip: _listening ? 'Dừng và gửi' : 'Nói để ghi chép',
            onPressed: sending ? null : _toggleVoice,
            icon: Icon(_listening ? LucideIcons.square : LucideIcons.mic, size: 22),
            color: _listening ? AppColors.danger : AppColors.primary,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (context, value, _) => IconButton(
              key: const ValueKey('send-button'),
              onPressed: value.text.trim().isEmpty || sending ? null : _submitInput,
              icon: const Icon(LucideIcons.send, size: 22),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
    if (!_listening) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(key: const ValueKey('voice-level'), value: _level, minHeight: 4, color: AppColors.danger),
        ),
        row,
      ],
    );
  }
}
