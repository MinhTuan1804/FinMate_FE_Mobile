import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import '../../fixtures/fixture.dart';

void main() {
  test('GroupInvitationPreviewEntity.fromJson đọc group_invitation_preview.json thật', () {
    final preview = GroupInvitationPreviewEntity.fromJson(fixtureData('group_invitation_preview') as Map<String, dynamic>);

    expect(preview.groupName, 'Gia đình');
    expect(preview.groupType, GroupType.family);
    expect(preview.role, GroupRole.member);
    expect(preview.invitedBy, 'Người dùng A');
  });

  group('GroupInvitationsRepository', () {
    test('preview gửi token, trả về bản xem trước', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_invitation_preview'));
      final repo = GroupInvitationsRepository(apiClient: testApiClient(adapter));

      final preview = await repo.preview('tok-123');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/group-invitations/preview');
      expect(req.data, {'token': 'tok-123'});
      expect(preview.groupName, 'Gia đình');
    });

    test('accept gửi token, trả về groupId', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': {'groupId': 'g1'}}));
      final repo = GroupInvitationsRepository(apiClient: testApiClient(adapter));

      final groupId = await repo.accept('tok-123');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/group-invitations/accept');
      expect(req.data, {'token': 'tok-123'});
      expect(groupId, 'g1');
    });
  });
}
