import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/app_config/domain/app_config.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(apiClient: ref.watch(apiClientProvider)),
);

/// `GET /api/v1/app-config` — AllowAnonymous, không cần đăng nhập (màn đăng nhập cũng cần hiện popup bảo trì).
class AppConfigRepository {
  final ApiClient apiClient;

  AppConfigRepository({required this.apiClient});

  Future<AppConfigEntity> getConfig() async {
    final response = await apiClient.get(
      '/api/v1/app-config',
      fromJsonT: (json) => AppConfigEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
