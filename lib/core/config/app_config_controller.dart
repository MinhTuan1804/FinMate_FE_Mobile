import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/config/app_config_repository.dart';

/// Chu kỳ hỏi lại server khi app đang mở. Đặt về [Duration.zero] thì tắt vòng hỏi (dùng trong test).
final appConfigPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 60));

final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(AppConfigController.new);

/// Giữ cấu hình hệ thống đang chạy: bắt đầu bằng bản đệm (hoặc mặc định), rồi hỏi server ngay và định kỳ.
/// Lỗi mạng không làm gì cả: giữ bản đang có, nên mất mạng không bao giờ tự bật popup bảo trì.
class AppConfigController extends Notifier<AppConfig> {
  bool _alive = true;

  @override
  AppConfig build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final interval = ref.read(appConfigPollIntervalProvider);
    if (interval > Duration.zero) {
      final timer = Timer.periodic(interval, (_) => unawaited(refresh()));
      ref.onDispose(timer.cancel);
    }
    unawaited(_start());
    return AppConfig.defaults;
  }

  Future<void> _start() async {
    final repository = ref.read(appConfigRepositoryProvider);
    final cached = await repository.cached();
    if (_alive && cached != null && state.version == 0) state = cached;
    await refresh();
  }

  /// Hỏi server một lần. Dùng cho vòng định kỳ, khi app quay lại và nút "Thử lại" của popup bảo trì.
  Future<void> refresh() async {
    try {
      final fresh = await ref.read(appConfigRepositoryProvider).fetch();
      // Số phiên bản đổi mới thay thế: tránh dựng lại toàn app mỗi phút khi không có gì mới.
      if (_alive && fresh.version != state.version) state = fresh;
    } on Object {
      // giữ bản hiện tại
    }
  }
}
