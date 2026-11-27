import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final dataCoverageRepositoryProvider = Provider<DataCoverageRepository>(
  (ref) => DataCoverageRepository(apiClient: ref.watch(apiClientProvider)),
);

class DataCoverageRepository {
  final ApiClient apiClient;

  DataCoverageRepository({required this.apiClient});

  /// [days] từ 7 đến 90 (BE trả 400 ngoài khoảng này); mặc định 30.
  Future<DataCoverage> getCoverage({int days = 30}) async {
    final response = await apiClient.get(
      '/api/v1/me/data-coverage',
      queryParameters: {'days': days},
      fromJsonT: (json) => DataCoverage.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const DataCoverage(windowDays: 30, coveragePercent: null, level: CoverageLevel.unknown, accounts: [], devices: []);
  }
}

/// Độ phủ dữ liệu để hiện trên màn Tài khoản & ví. Chỉ là thông tin phụ nên lỗi cho ra `null` (không hiện gì)
/// thay vì chặn màn hình hay báo lỗi.
final dataCoverageProvider = FutureProvider.autoDispose<DataCoverage?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  try {
    return await ref.watch(dataCoverageRepositoryProvider).getCoverage();
  } on Object {
    return null;
  }
});
