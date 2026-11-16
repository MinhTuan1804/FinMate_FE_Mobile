import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/speech_end_detector.dart';
import 'package:finmate/features/assistant/data/voice_recorder.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/chat_cards.dart';

/// Chatbot ghi chép và hỏi chi tiêu bằng ngôn ngữ tự nhiên
class AssistantScreen extends ConsumerStatefulWidget {
  final String? startWith;

  const AssistantScreen({super.key, this.startWith});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _plusKey = GlobalKey();
  bool _actionsOpen =
      false; // người dùng bấm ">" để mở lại nút + và mic khi đang gõ
  Timer? _recordLimit;
  StreamSubscription<double>? _levelSub;
  SpeechEndDetector _detector = SpeechEndDetector();

  double _level = 0;
  late final VoiceRecorder _recorder;
  bool _listening = false;

  static const _maxRecording = Duration(seconds: 55);

  final _sentAt = <int, DateTime>{};

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderProvider);
    _inputFocus.addListener(() {
      if (!mounted) return;
      setState(() => _actionsOpen = false);
    });
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
    _inputFocus.dispose();
    super.dispose();
  }

  void _ensureAccount(List<FinancialAccount>? accounts) {
    final controller = ref.read(assistantControllerProvider.notifier);
    if (accounts == null || accounts.isEmpty) return;
    final selected = ref.read(assistantControllerProvider).selectedAccountId;
    if (selected != null && accounts.any((a) => a.id == selected)) return;
    final fallback = accounts.firstWhere(
      (a) => a.type == AccountType.cash,
      orElse: () => accounts.first,
    );
    controller.selectAccount(fallback.id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleVoice() async {
    final recorder = _recorder;
    if (_listening) {
      await _finishRecording();
      return;
    }
    switch (await recorder.start()) {
      case VoiceStart.denied:
        _snack(
          'Cần quyền micro để ghi âm. Vào Cài đặt > Ứng dụng > FinMate > Quyền > Micro để bật.',
        );
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
    setState(() => _listening = false);
    final path = await _recorder.stop();
    if (!mounted) return;
    if (path == null) {
      _snack('Mình chưa nghe thấy gì, bạn thử lại nhé');
      return;
    }
    ref.read(assistantControllerProvider.notifier).sendVoice(path);
  }

  Future<void> _pickReceipt() async {
    final box = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    // Menu mở phía trên nút +, giống menu đính kèm của Messenger
    const menuHeight = 3 * 52.0 + 2 + 16;
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy - menuHeight - 8,
      overlay.size.width - origin.dx - box.size.width,
      overlay.size.height - origin.dy + 8,
    );
    PopupMenuEntry<String> item(String value, String label, IconData icon) =>
        PopupMenuItem<String>(
          value: value,
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppTypography.bodyLarge(context)),
              ),
              const SizedBox(width: 16),
              Icon(icon, size: 20, color: AppColors.slateOn(context)),
            ],
          ),
        );
    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface(context).withValues(alpha: 0.96),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.glassBorder(context)),
      ),
      constraints: const BoxConstraints(minWidth: 240),
      items: [
        item('scan', 'Quét bill', LucideIcons.scanLine),
        const PopupMenuDivider(height: 1),
        item('camera', 'Chụp ảnh', LucideIcons.camera),
        const PopupMenuDivider(height: 1),
        item('gallery', 'Chọn ảnh từ thư viện', LucideIcons.image),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'scan') {
      // "Quét bill" mở màn quét hóa đơn riêng (D4); kết quả rà soát rồi mới lưu
      context.push('/scan-receipt');
      return;
    }
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
      _snack(
        '${e.message} Bạn có thể bật quyền trong Cài đặt > Ứng dụng > FinMate > Quyền.',
      );
    }
  }

  Future<void> _submitInput() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(assistantControllerProvider.notifier).send(text);
  }

  /// Giờ hiển thị của tin nhắn: ghi nhận lúc tin nhắn xuất hiện lần đầu (mô hình tin nhắn không lưu thời điểm)
  String _timeOf(int id) =>
      DateFormat('HH:mm').format(_sentAt.putIfAbsent(id, DateTime.now));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final accounts =
        ref.watch(accountsControllerProvider).valueOrNull ??
        const <FinancialAccount>[];
    ref.listen(
      accountsControllerProvider,
      (_, next) => _ensureAccount(next.valueOrNull),
    );
    final selected = accounts
        .where((a) => a.id == state.selectedAccountId)
        .firstOrNull;

    final messages = state.messages;
    final sendingOffset = state.isSending ? 1 : 0;
    // Thêm một mục cho nhãn ngày giờ ở đầu cuộc trò chuyện (danh sách đảo chiều nên nó nằm cuối)
    final itemCount =
        messages.length + sendingOffset + (messages.isEmpty ? 0 : 1);

    return Scaffold(
      body: AmbientGlassBackground(
        // top: false để nền header phủ lên tận mép trên (sau thanh trạng thái); header tự cộng phần đệm này
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: messages.isEmpty && !state.isSending
                    ? _buildEmpty(context)
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: itemCount,
                        itemBuilder: (context, i) {
                          if (state.isSending && i == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: AiRow(
                                child: AssistantBubble(
                                  text:
                                      messages.isNotEmpty &&
                                          messages.last is ImageNote
                                      ? 'Đang đọc hóa đơn...'
                                      : 'Đang trả lời...',
                                ),
                              ),
                            );
                          }
                          final mi = i - sendingOffset;
                          if (mi == messages.length) {
                            return _buildDayDivider(context, messages.first.id);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _messageView(
                              messages[messages.length - 1 - mi],
                            ),
                          );
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
                      onSelected: (id) => ref
                          .read(assistantControllerProvider.notifier)
                          .selectAccount(id),
                      itemBuilder: (context) => [
                        for (final a in accounts)
                          PopupMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: _pillDecoration(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.wallet,
                              size: 14,
                              color: AppColors.primaryAction(context),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Ghi vào: ${selected?.name ?? 'chọn tài khoản'}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.chevronDown, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _buildInput(context, state.isSending),
            ],
          ),
        ),
      ),
    );
  }

  /// Nền viên thuốc kính nhạt dùng chung cho chip và nút tròn (Figma E1)
  BoxDecoration _pillDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.surfaceSubtle(context).withValues(alpha: 0.65),
    borderRadius: AppSpacing.roundedPill,
    border: Border.all(color: AppColors.glassBorder(context)),
  );

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final secondary = AppTypography.caption(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8 + MediaQuery.paddingOf(context).top,
        16,
        8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder(context)),
        ),
      ),
      child: Row(
        children: [
          if (canPop)
            LiquidGlassIconButton(
              icon: LucideIcons.arrowLeft,
              tooltip: 'Quay lại',
              size: 40,
              iconSize: 18,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: AppSpacing.minTouchTarget),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatar(context),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'FinMate AI',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLarge(context)
                                    .copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      height: 1.3,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ExcludeSemantics(
                              child: Icon(
                                LucideIcons.badgeCheck,
                                size: 15,
                                color: AppColors.slateOn(context),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.safe,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Đang trực tuyến • Trợ lý tài chính',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          LiquidGlassIconButton(
            key: const ValueKey('open-ai-memory'),
            icon: LucideIcons.ellipsisVertical,
            tooltip: 'Bộ nhớ AI',
            size: 40,
            iconSize: 18,
            onPressed: () => context.push('/assistant/memory'),
          ),
        ],
      ),
    );
  }

  /// Avatar trợ lý: viền chuyển màu xanh-hồng, lõi trắng, chấm trực tuyến
  Widget _buildAvatar(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  AppColors.secondary.withValues(alpha: 0.7),
                  AppColors.surfaceSubtle(context),
                  AppColors.tertiary.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  LucideIcons.sparkles,
                  size: 20,
                  color: AppColors.slateOn(context),
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.safe,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface(context), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nhãn "HÔM NAY • 12:45" ở đầu cuộc trò chuyện
  Widget _buildDayDivider(BuildContext context, int firstMessageId) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: _pillDecoration(context),
          child: Text(
            'HÔM NAY • ${_timeOf(firstMessageId)}',
            style: AppTypography.caption(context).copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55,
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageView(ChatMessage message) => switch (message) {
    UserText m => UserBubble(text: m.text, time: _timeOf(m.id)),
    ImageNote m => ImageBubble(path: m.path),
    AssistantText m => AiRow(child: AssistantBubble(text: m.text)),
    SavedCard m => AiRow(child: SavedCardView(tx: m.tx)),
    SummaryCard m => AiRow(child: SummaryCardView(summary: m.summary)),
    DraftCard m => AiRow(child: DraftCardView(card: m)),
    DraftBatchCard m => AiRow(child: DraftBatchCardView(card: m)),
    GoalDraftCard m => AiRow(child: GoalDraftCardView(card: m)),
    PurchaseCard m => AiRow(child: PurchaseCardView(card: m)),
    ErrorNote m => AiRow(
      child: ErrorNoteView(
        note: m,
        onRetry: () =>
            ref.read(assistantControllerProvider.notifier).retry(m.id),
      ),
    ),
  };

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(context)),
              ),
              child: Icon(
                LucideIcons.sparkles,
                size: 28,
                color: AppColors.slateOn(context),
              ),
            ),
            const SizedBox(height: 14),
            Text('Bạn muốn ghi gì hôm nay?', style: AppTypography.h3(context)),
            const SizedBox(height: 4),
            Text(
              'Nhắn tự nhiên, FinMate sẽ ghi chép hoặc trả lời giúp bạn.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, bool sending) {
    final actionColor = AppColors.primaryAction(context);
    final onAction = AppColors.onPrimaryAction(context);
    // Đang gõ thì thu nút + và mic lại thành ">" (như Messenger); đang ghi âm vẫn phải thấy nút dừng
    final showActions = !_inputFocus.hasFocus || _actionsOpen || _listening;
    ButtonStyle roundStyle({Color? foreground}) => IconButton.styleFrom(
      fixedSize: const Size(40, 40),
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.surfaceSubtle(context).withValues(alpha: 0.65),
      foregroundColor: foreground ?? AppColors.textPrimary(context),
      shape: CircleBorder(
        side: BorderSide(color: AppColors.glassBorder(context)),
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.surface(context).withValues(alpha: 0.88),
          borderRadius: AppSpacing.roundedPill,
          border: Border.all(color: AppColors.glassBorder(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryAction(context).withValues(alpha: 0.1),
              blurRadius: 25,
              spreadRadius: -5,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              child: showActions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('scan-button'),
                          tooltip: 'Đính kèm hóa đơn',
                          onPressed: sending ? null : _pickReceipt,
                          style: roundStyle(),
                          icon: Icon(LucideIcons.plus, key: _plusKey, size: 18),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          key: const ValueKey('mic-button'),
                          tooltip: _listening
                              ? 'Dừng và gửi'
                              : 'Nói để ghi chép',
                          onPressed: sending ? null : _toggleVoice,
                          style: roundStyle(
                            foreground: _listening ? AppColors.danger : null,
                          ),
                          icon: Icon(
                            _listening ? LucideIcons.square : LucideIcons.mic,
                            size: 18,
                          ),
                        ),
                      ],
                    )
                  : IconButton(
                      key: const ValueKey('expand-actions'),
                      tooltip: 'Hiện thêm tùy chọn',
                      onPressed: () => setState(() => _actionsOpen = true),
                      style: roundStyle(),
                      icon: const Icon(LucideIcons.chevronRight, size: 18),
                    ),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                onTapOutside: (_) => _inputFocus.unfocus(),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitInput(),
                style: AppTypography.body(context),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  hintMaxLines: 1,
                  hintText: _listening
                      ? 'Đang nghe... nói xong mình sẽ tự gửi'
                      : (sending
                            ? 'Đang xử lý...'
                            : 'Nhắn hoặc nói với FinMate...'),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (context, value, _) => IconButton(
                key: const ValueKey('send-button'),
                tooltip: 'Gửi',
                onPressed: value.text.trim().isEmpty || sending
                    ? null
                    : _submitInput,
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  backgroundColor: actionColor,
                  foregroundColor: onAction,
                  disabledBackgroundColor: actionColor.withValues(alpha: 0.35),
                  disabledForegroundColor: onAction.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(LucideIcons.arrowUp, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
    if (!_listening) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            key: const ValueKey('voice-level'),
            value: _level,
            minHeight: 4,
            color: AppColors.danger,
          ),
        ),
        row,
      ],
    );
  }
}
