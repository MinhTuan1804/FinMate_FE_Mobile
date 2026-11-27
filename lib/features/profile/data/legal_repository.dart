import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/domain/legal_document.dart';

final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => LegalRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Văn bản pháp lý đã xuất bản (công khai, không cần đăng nhập). BE chỉ trả bản đã xuất bản, không lộ nháp.
class LegalRepository {
  final ApiClient apiClient;

  LegalRepository({required this.apiClient});

  /// [kind] là `terms` hoặc `privacy`.
  Future<LegalDocument> getDocument(String kind) async {
    final response = await apiClient.get(
      '/api/v1/legal/$kind',
      fromJsonT: (json) => LegalDocument.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? const LegalDocument(version: 0, updatedAt: null, sections: []);
  }
}

/// Văn bản pháp lý theo loại (`terms` | `privacy`). Lỗi mạng/server hoặc văn bản rỗng cho ra `null`:
/// màn hình đọc dùng bản có sẵn trong app thay vì để người dùng không đọc được điều khoản.
final legalDocumentProvider = FutureProvider.autoDispose.family<LegalDocument?, String>((ref, kind) async {
  try {
    final doc = await ref.watch(legalRepositoryProvider).getDocument(kind);
    return doc.sections.isEmpty ? null : doc;
  } on Object {
    return null;
  }
});
