import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/shared/widgets/glass/glass_notification_card.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/devices/data/devices_repository.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/routes/app_router.dart';

const _pushChannel = MethodChannel('com.finmate.app/push');

/// ScaffoldMessenger gốc của MaterialApp, để hiện push đến khi app đang mở trên mọi màn.
final pushMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Nhận push FCM. BE gửi theo Firebase Installation ID (FirebaseAdmin `MulticastMessage.Fids`), KHÔNG phải registration token
/// kiểu cũ của getToken(): gửi token cũ vào Fids thì FCM trả Unregistered. Nên app đăng ký bằng register()/onRegistered (trả FID).
/// Đăng nhập: register() rồi gửi FID lên BE mỗi khi FCM báo (mỗi lần mở app và khi FID đổi). Đăng xuất: unregister() để máy này
/// thôi nhận push của tài khoản cũ (BE tự gỡ FID chết ở lần gửi sau).
/// Chỉ chạy ở engine chính trên Android: bong bóng trợ lý dùng lại FinMateApp nhưng không khởi tạo Firebase.
final pushMessagingProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || Firebase.apps.isEmpty) return;

  final messaging = FirebaseMessaging.instance;
  String? fid;

  Future<void> sendToBackend() async {
    final id = fid;
    if (id == null || ref.read(currentUserIdProvider) == null) return;
    try {
      await ref.read(devicesRepositoryProvider).registerDevice(token: id, platform: 'Android');
    } catch (e) {
      // Push hỏng không được chặn việc dùng app
      debugPrint('Push registration failed: $e');
    }
  }

  final registeredSub = messaging.onRegistered.listen((id) {
    fid = id;
    sendToBackend();
  });

  Future<void> onSignedIn() async {
    try {
      await messaging.requestPermission();
      await messaging.register();
      await sendToBackend(); // FID đã có từ trước thì onRegistered có thể không bắn lại
      // Mở app từ thông báo khi app đã tắt hẳn
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFrom(ref, initial);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> onSignedOut() async {
    try {
      await messaging.unregister();
    } catch (_) {}
  }

  ref.listen<String?>(currentUserIdProvider, (prev, next) {
    if (next != null && next != prev) {
      onSignedIn();
    } else if (next == null && prev != null) {
      onSignedOut();
    }
  }, fireImmediately: true);

  // Mở app từ thông báo khi app đang chạy nền
  final openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFrom(ref, m));
  // App đang mở thì Android không tự hiện push: hiện đúng thẻ thông báo kính của Hộp thư (GlassNotificationCard),
  // bấm thẻ đi đúng màn như khi bấm thông báo hệ thống, bấm X để đóng.
  final foregroundSub = FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    final messenger = pushMessengerKey.currentState;
    if (n == null || messenger == null) return;
    // Cũng đăng lên thanh thông báo (bản im lặng, MainActivity.kt) để còn lại sau khi thẻ ẩn, như app ngân hàng
    final id = m.messageId;
    if (id != null) {
      _pushChannel.invokeMethod('show', {'id': id, 'title': n.title ?? 'FinMate', 'body': n.body ?? ''}).catchError((_) {});
    }
    final (icon, color) = switch (m.data['type']) {
      'transaction_review' => (LucideIcons.clipboardCheck, GlassColors.warning),
      'transaction_auto_committed' => (LucideIcons.arrowLeftRight, GlassColors.accentSkyBlue),
      _ => (LucideIcons.bell, GlassColors.slateAnchor),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: GlassNotificationCard(
          level: 3, // nổi trên nội dung app: kính modal đục + blur, không thì chữ phía sau xuyên qua
          icon: icon,
          iconColor: color,
          title: n.title ?? 'FinMate',
          body: n.body ?? '',
          metaText: 'Vừa xong · chạm để xem',
          unread: true,
          onTap: () {
            messenger.hideCurrentSnackBar();
            // Đã xem qua thẻ trong app thì bỏ bản trên thanh thông báo
            if (id != null) _pushChannel.invokeMethod('cancel', {'id': id}).catchError((_) {});
            _openFrom(ref, m);
          },
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ));
  });
  ref.onDispose(() {
    openedSub.cancel();
    foregroundSub.cancel();
    registeredSub.cancel();
  });
});

/// Bấm push → mở đúng màn theo `data` BE gửi kèm (`type` cho giao dịch, `action` + `kind`/id cho phần còn lại).
/// Push không mang data (nhắc khoản vay, góp mục tiêu, vượt ngân sách...) hoặc loại lạ → hộp thư thông báo.
Future<void> _openFrom(Ref ref, RemoteMessage message) async {
  final router = ref.read(routerProvider);
  final data = message.data;
  final (path, extra) = routeForPush(data);
  debugPrint('Push tap → $path');

  // Về Trang chủ làm gốc rồi mới push màn đích, để nút Back quay về Trang chủ. Phải đợi go() dựng xong khung hình:
  // push gọi ngay sau go cùng một lượt bị lần dựng của go đè mất, app đứng lại ở Trang chủ.
  router.go('/home');
  await SchedulerBinding.instance.endOfFrame;
  router.push(path, extra: extra);
  if (data['type'] == 'transaction_review') {
    ref.read(transactionControllerProvider.notifier).setDraftsOnly(true);
  }
}

@visibleForTesting
(String, Object?) routeForPush(Map<String, dynamic> data) {
  final groupId = data['groupId'] as String?;
  final ticketId = data['ticketId'] as String?;
  return switch (data['type'] ?? data['action']) {
    'transaction_review' || 'transaction_auto_committed' => ('/transactions', null),
    'forecast_alert' => switch (data['kind']) {
        'group_approval_req' when groupId != null => ('/group-approvals', groupId),
        String k when k.startsWith('group_') && groupId != null => ('/group-detail', groupId),
        'budget_risk' => ('/planning/budgets', null),
        'bill_due' || 'bill_status_check' => ('/planning/recurring', null),
        'low_balance' || 'income_late' => ('/forecast', null),
        'purchase_reminder' => ('/analytics/purchase-check', null),
        'weekly_digest' => ('/analytics/insights', null),
        'goal_market_shift' => ('/planning/goals', null),
        _ => ('/analytics/alerts', null), // bất thường, đổi giá, thị trường...: danh sách cảnh báo
      },
    'group_owner_changed' when groupId != null => ('/group-detail', groupId),
    'budget_alert' => ('/planning/budgets', null),
    'goal_completed' || 'goal_deadline' => ('/planning/goals', null),
    'loan_due' => ('/planning/loans', null),
    'subscription_activated' || 'subscription_expiring' => ('/profile/subscription', null),
    // Yêu cầu truy cập hỗ trợ hiện ngay trong chi tiết phiếu
    'support_ticket' || 'support_access_request' when ticketId != null => ('/support-ticket', ticketId),
    _ => ('/notifications', null),
  };
}
