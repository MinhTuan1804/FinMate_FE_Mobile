import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final notificationBridgeProvider = Provider<NotificationBridge>((ref) => sharedNotificationBridge);

/// Quyền đọc thông báo đang bật hay không (UI invalidate khi quay lại app từ màn hình cài đặt).
final notificationAccessEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationBridgeProvider).isNotificationAccessEnabled(),
);

/// Tăng mỗi khi scope vừa gọi xong `flushQueue` (mở/quay lại app). Màn "Chờ duyệt" tải lại nháp theo tick này
/// để việc tải luôn diễn ra SAU lệnh đẩy hàng đợi, thay vì chạy song song với nó.
final notificationFlushTickProvider = StateProvider<int>((ref) => 0);

/// Gói ứng dụng cần theo dõi: tài khoản đang theo dõi, có packageName, không trùng, giữ thứ tự gốc.
List<String> monitoredPackagesOf(List<FinancialAccount> accounts) => {
      for (final a in accounts)
        if (a.isMonitored && (a.packageName?.trim().isNotEmpty ?? false)) a.packageName!.trim(),
    }.toList();

/// Đẩy danh sách gói xuống native và xả hàng đợi thông báo mỗi lần mở/quay lại app.
class NotificationCaptureScope extends ConsumerStatefulWidget {
  const NotificationCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationCaptureScope> createState() => _NotificationCaptureScopeState();
}

class _NotificationCaptureScopeState extends ConsumerState<NotificationCaptureScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWithNative();
    // fireImmediately: danh sách có thể đã tải xong trước khi scope được dựng.
    // Chỉ đẩy khi đã đăng nhập và danh sách là kết quả tải thật: chưa đăng nhập/offline controller phát data([]) giả,
    // đẩy nó sẽ xoá danh sách ở native (đăng xuất đã được clearSession lo). Đổi người dùng thì controller được tạo lại và listener chạy lại.
    ref.listenManual(accountsControllerProvider, (_, next) {
      if (ref.read(currentUserIdProvider) == null || next is! AsyncData<List<FinancialAccount>>) return;
      _pushPackages(next.value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncWithNative();
  }

  // Await tuần tự để lệnh tới native đúng thứ tự; không log gì vì có thể chứa nội dung thông báo.
  Future<void> _syncWithNative() async {
    final bridge = ref.read(notificationBridgeProvider);
    try {
      await bridge.flushQueue();
      if (await bridge.consumeSessionExpired() && mounted) {
        // Native bị từ chối refresh lúc app đóng: dọn gói theo dõi/baseUrl còn sót TRƯỚC khi báo hết phiên.
        await bridge.clearSession();
        if (mounted) ref.read(sessionExpiredProvider.notifier).state = true;
      }
    } catch (_) {
      // Lỗi cầu nối không được làm hỏng giao diện; lần resume sau sẽ thử lại.
    }
    if (!mounted) return;
    ref.read(notificationFlushTickProvider.notifier).state++;
    ref.invalidate(notificationAccessEnabledProvider);
  }

  Future<void> _pushPackages(List<FinancialAccount> accounts) async {
    try {
      await ref.read(notificationBridgeProvider).setMonitoredPackages(monitoredPackagesOf(accounts));
    } catch (_) {
      // Giữ danh sách cũ ở native; lần tải tài khoản sau sẽ đẩy lại.
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
