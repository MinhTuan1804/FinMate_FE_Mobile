import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/domain/group.dart';

/// Repository riêng cho người ĐƯỢC MỜI: xem trước và nhận lời mời bằng mã (token).
/// Khác với [GroupsRepository] (của chủ nhóm/quản lý), các API này không cần đã là thành viên.
final groupInvitationsRepositoryProvider = Provider<GroupInvitationsRepository>(
  (ref) => GroupInvitationsRepository(apiClient: ref.watch(apiClientProvider)),
);

class GroupInvitationsRepository {
  final ApiClient apiClient;
  GroupInvitationsRepository({required this.apiClient});

  Future<GroupInvitationPreviewEntity> preview(String token) async {
    final res = await apiClient.post<GroupInvitationPreviewEntity>(
      '/api/v1/group-invitations/preview',
      data: {'token': token},
      fromJsonT: (json) => GroupInvitationPreviewEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as GroupInvitationPreviewEntity;
  }

  /// Trả về id của nhóm đã tham gia.
  Future<String> accept(String token) async {
    final res = await apiClient.post<String>(
      '/api/v1/group-invitations/accept',
      data: {'token': token},
      fromJsonT: (json) => (json as Map<String, dynamic>)['groupId'] as String,
    );
    return res.data as String;
  }
}
