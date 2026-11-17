import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import 'package:finmate/routes/app_router.dart';

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
  // resumed có thể bắn liên tiếp nhiều lần trong 1 khoảng ngắn (nhiều visibilityChanged) — không
  // có chốt này, nhiều lượt gọi chồng lên nhau cùng đọc "pendingRoute" trước khi lượt trước kịp
  // xoá, dẫn tới push trùng route nhiều lần (màn hình/":Hoàn tất" chồng instance cũ-mới lẫn lộn).
  bool _syncing = false;

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
  // Chốt _syncing: resumed có thể bắn liên tiếp nên bỏ qua lượt gọi mới nếu lượt trước chưa xong,
  // thay vì chạy chồng — tránh đọc/push trùng "pendingRoute" (xem khai báo _syncing).
  Future<void> _syncWithNative() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final bridge = ref.read(notificationBridgeProvider);
      try {
        await bridge.flushQueue();
        if (await bridge.consumeSessionExpired() && mounted) {
          // Native bị từ chối refresh lúc app đóng: dọn gói theo dõi/baseUrl còn sót TRƯỚC khi báo hết phiên.
          await bridge.clearSession();
          if (mounted) ref.read(sessionExpiredProvider.notifier).state = true;
        } else if (mounted) {
          // Issue D: flushQueue có thể vừa khiến BE Auto-commit (Flow 1) hoặc gộp Transfer một giao
          // dịch mới — không ai gọi onDataChanged cho đường này (chỉ createTransaction/confirmDraft ở
          // transaction_controller.dart mới gọi), nên số dư/Thu nhập/Chi tiêu ở Trang chủ bị đứng im
          // cho tới khi có thao tác khác vô tình invalidate. Gọi lại bất kể có gì mới hay không — cũng
          // rẻ như mọi lần mở/quay lại app khác, đúng những gì refreshDerivedData() làm ở nơi khác
          // (không gọi lại được hàm đó thẳng: nó nhận Ref của notifier, không nhận WidgetRef ở đây).
          await ref.read(accountsControllerProvider.notifier).load();
          await ref.read(planningControllerProvider.notifier).loadPlanningData(silent: true);
          ref.invalidate(monthlySummaryProvider);
          ref.invalidate(categoryBreakdownProvider);
          ref.invalidate(forecastProvider);
        }
      } catch (_) {
        // Lỗi cầu nối không được làm hỏng giao diện; lần resume sau sẽ thử lại.
      }
      await _consumePendingRoute();
      if (!mounted) return;
      ref.read(notificationFlushTickProvider.notifier).state++;
      ref.invalidate(notificationAccessEnabledProvider);
    } finally {
      _syncing = false;
    }
  }

  // Route widget yêu cầu (vd "Bù đắp ngân sách →" trên W1, ghi qua OpenPlanningCallback phía native)
  // — đọc qua đúng cơ chế `home_widget` W1 đang dùng ổn định để lấy dữ liệu, không qua Intent/
  // MethodChannel (từng bị nghi rơi mất qua lớp Background-Activity-Launch-workaround của Glance).
  // Không có tín hiệu "native chủ động đẩy" nên phải tự kiểm tra lại mỗi lần app resume.
  Future<void> _consumePendingRoute() async {
    final route = await HomeWidget.getWidgetData<String>('pendingRoute');
    if (route == null || route.isEmpty) return;
    await HomeWidget.saveWidgetData<String>('pendingRoute', '');
    if (!mounted) return;
    // "/quick-create" không phải route thật (CreateTransactionBottomSheet là 1 modal, không có
    // path riêng) — nút "Ghi chép" trên W2 ghi route ảo này, mở thẳng sheet qua navigator context
    // thay vì push 1 GoRoute không tồn tại.
    if (route == '/quick-create') {
      final quickCreateContext = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (quickCreateContext != null && quickCreateContext.mounted) {
        CreateTransactionBottomSheet.show(quickCreateContext);
      }
      return;
    }
    // push (không phải go): go() thay cả stack nên không còn gì bên dưới để Navigator.maybePop
    // (dùng bởi K1WidgetConfigScreen's Hoàn tất/X) quay lại — giữ lịch sử để back hoạt động đúng.
    ref.read(routerProvider).push(route);
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
