import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final dataExportRepositoryProvider = Provider<DataExportRepository>(
  (ref) => DataExportRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Yêu cầu gần nhất của gói dữ liệu cá nhân; null khi chưa từng yêu cầu.
final latestPersonalDataExportProvider = FutureProvider.autoDispose<PersonalDataExport?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final list = await ref.watch(dataExportRepositoryProvider).listPersonalData();
  return list.isEmpty ? null : list.first;
});

/// Một yêu cầu gói dữ liệu cá nhân. [status]: `Pending` | `Running` | `Ready` | `Failed` | `Expired`.
class PersonalDataExport {
  final String id;
  final String status;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final String? failureReason;

  const PersonalDataExport({required this.id, required this.status, this.requestedAt, this.expiresAt, this.failureReason});

  bool get isWorking => status == 'Pending' || status == 'Running';
  bool get isReady => status == 'Ready';

  factory PersonalDataExport.fromJson(Map<String, dynamic> json) => PersonalDataExport(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '')?.toLocal(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toLocal(),
        failureReason: json['failureReason'] as String?,
      );
}

/// Xuất dữ liệu (BE Phase 91): CSV giao dịch tải ngay, và gói toàn bộ dữ liệu cá nhân (xác thực bằng mã email, dựng nền, tải ZIP).
/// Tệp tải về được ghi vào thư mục tạm của app để mở khung chia sẻ / lưu của máy.
class DataExportRepository {
  final ApiClient apiClient;
  static const _base = '/api/v1/exports';

  DataExportRepository({required this.apiClient});

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// CSV giao dịch đã xác nhận từ [from] đến [to] (gồm cả hai ngày). [semicolon] cho Excel đặt vùng Việt Nam (tách cột bằng `;`).
  Future<File> downloadTransactionsCsv({required DateTime from, required DateTime to, String? accountId, bool semicolon = false}) async {
    final bytes = await apiClient.getBytes('$_base/transactions.csv', queryParameters: {
      'from': _day(from),
      'to': _day(to),
      if (accountId != null) 'accountId': accountId,
      'delimiter': semicolon ? 'semicolon' : 'comma',
    });
    return _save('finmate-giao-dich-${_day(from)}-${_day(to)}.csv', bytes);
  }

  /// Gửi mã 6 số tới email của tài khoản.
  Future<void> sendPersonalDataOtp() => apiClient.post('$_base/personal-data/otp', fromJsonT: (json) => json);

  Future<PersonalDataExport> requestPersonalData(String code) async {
    final res = await apiClient.post(
      '$_base/personal-data',
      data: {'code': code},
      fromJsonT: (json) => PersonalDataExport.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<List<PersonalDataExport>> listPersonalData() async {
    final res = await apiClient.get(
      '$_base/personal-data',
      fromJsonT: (json) => [for (final e in (json as List? ?? const [])) PersonalDataExport.fromJson(e as Map<String, dynamic>)],
    );
    return res.data ?? const [];
  }

  /// Lấy link dùng một lần rồi tải ZIP ngay (link sống vài phút và chết sau lần tải).
  Future<File> downloadPersonalData(String id) async {
    final link = await apiClient.post(
      '$_base/personal-data/$id/download-link',
      fromJsonT: (json) => (json as Map<String, dynamic>)['url'] as String,
    );
    final bytes = await apiClient.getBytes(link.data!);
    return _save('finmate-du-lieu-${_day(DateTime.now())}.zip', bytes);
  }

  Future<File> _save(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
