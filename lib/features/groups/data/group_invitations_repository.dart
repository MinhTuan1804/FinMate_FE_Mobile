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
  /// [defaultFinancialAccountId]: ví của chính mình; server chỉ lưu lại — khi góp quỹ/ghi chi FE vẫn phải tự truyền ví.
  Future<String> accept({required String? token, String? defaultFinancialAccountId}) async {
    final res = await apiClient.post<String>(
      '/api/v1/group-invitations/accept',
      data: {
        if (token != null) 'token': token,
        if (defaultFinancialAccountId != null) 'defaultFinancialAccountId': defaultFinancialAccountId,
      },
      fromJsonT: (json) => (json as Map<String, dynamic>)['groupId'] as String,
    );
    return res.data as String;
  }

  /// Từ chối: token sai hoặc của người khác 404; đã xử lý/hết hạn 422 GROUP_INVITATION_INVALID.
  Future<void> decline({required String? token}) async {
    await apiClient.post<void>(
      '/api/v1/group-invitations/decline',
      data: {if (token != null) 'token': token},
      fromJsonT: (_) {},
    );
  }
}
