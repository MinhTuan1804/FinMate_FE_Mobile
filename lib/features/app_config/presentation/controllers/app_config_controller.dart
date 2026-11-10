import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/app_config/data/app_config_repository.dart';
import 'package:finmate/features/app_config/domain/app_config.dart';

/// Cấu hình công khai hiện tại. `.autoDispose` vì chỉ cần khi màn test đang mở; không cache xuyên phiên.
final appConfigProvider = FutureProvider.autoDispose<AppConfigEntity>(
  (ref) => ref.watch(appConfigRepositoryProvider).getConfig(),
);
