import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import '../../fixtures/fixture.dart';

void main() {
  test('GroupEntity.fromJson đọc groups.json thật', () {
    final list = (fixtureData('groups') as List).map((e) => GroupEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].name, 'Gia đình');
    expect(list[0].type, GroupType.family);
    expect(list[0].transactionVisibility, GroupTransactionVisibility.full);
    expect(list[0].myRole, GroupRole.owner);
    expect(list[0].myPermissions, [GroupPermission.viewOverview, GroupPermission.viewActivity]);
    expect(list[0].isOwner, isTrue);
    expect(list[1].myRole, GroupRole.member);
    expect(list[1].isOwner, isFalse);
  });

  test('GroupMemberEntity.fromJson đọc group_members.json thật', () {
    final list = (fixtureData('group_members') as List).map((e) => GroupMemberEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].role, GroupRole.owner);
    expect(list[0].permissions, [GroupPermission.viewOverview]);
    expect(list[1].role, GroupRole.member);
    expect(list[1].permissions, isNull);
  });

  test('GroupActivityEntity.fromJson đọc group_activities.json thật', () {
    final list = (fixtureData('group_activities') as List).map((e) => GroupActivityEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].type, GroupActivityType.groupCreated);
    expect(list[1].type, GroupActivityType.memberJoined);
    expect(list[1].subjectId, 'u2');
  });

  test('GroupInvitationEntity.fromJson đọc group_invitations.json thật', () {
    final list =
        (fixtureData('group_invitations') as List).map((e) => GroupInvitationEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].email, 'ban@example.com');
    expect(list[0].role, GroupRole.member);
    expect(list[0].emailSent, isTrue);
    expect(list[1].email, isNull);
    expect(list[1].role, GroupRole.viewer);
  });

  test('GroupCategoryEntity.fromJson đọc group_categories.json thật', () {
    final list =
        (fixtureData('group_categories') as List).map((e) => GroupCategoryEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].name, 'Ăn uống chung');
    expect(list[0].iconName, 'utensils');
    expect(list[1].iconName, isNull);
  });

  test('GroupTransactionEntity.fromJson đọc group_transactions.json thật', () {
    final list = (fixtureData('group_transactions') as List)
        .map((e) => GroupTransactionEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(list, hasLength(2));
    expect(list[0].memberName, 'Người dùng A');
    expect(list[0].amountCents, BigInt.from(150000));
    expect(list[0].transactionType, TransactionType.expense);
    expect(list[0].groupCategoryId, 'gc1');
    expect(list[0].sharedAt, isNotNull);
    expect(list[1].transactionType, TransactionType.income);
    expect(list[1].groupCategoryId, isNull);
    expect(list[1].sharedAt, isNull);
  });

  test('GroupMonthlyReportEntity.fromJson đọc group_monthly_report.json thật', () {
    final report = GroupMonthlyReportEntity.fromJson(fixtureData('group_monthly_report') as Map<String, dynamic>);

    expect(report.year, 2026);
    expect(report.month, 11);
    expect(report.totalSpentCents, BigInt.from(150000));
    expect(report.totalIncomeCents, BigInt.from(500000));
    expect(report.byCategory, hasLength(1));
    expect(report.byCategory[0].categoryName, 'Ăn uống chung');
    expect(report.byMember, hasLength(2));
    expect(report.byMember[0].memberName, 'Người dùng A');
    expect(report.byMember[1].incomeCents, BigInt.from(500000));
  });

  test('GroupShareRuleEntity.fromJson đọc group_share_rules.json thật', () {
    final list = (fixtureData('group_share_rules') as List)
        .map((e) => GroupShareRuleEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(list, hasLength(2));
    expect(list[0].financialAccountId, '78b154c6-c8d8-4b6d-9367-981772ce5382');
    expect(list[0].categoryId, isNull);
    expect(list[1].financialAccountId, isNull);
    expect(list[1].categoryId, '97ce1e37-b3f6-4394-8ff7-b1dd50ddea83');
  });

  test('GroupBudgetEntity.fromJson đọc group_budgets.json thật', () {
    final list = (fixtureData('group_budgets') as List).map((e) => GroupBudgetEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].isTotal, isTrue);
    expect(list[0].limitCents, BigInt.from(2000000));
    expect(list[0].percentUsed, 75);
    expect(list[0].statusLevel, GroupBudgetStatusLevel.warning);
    expect(list[1].isTotal, isFalse);
    expect(list[1].categoryName, 'Di chuyển');
    expect(list[1].isOverLimit, isTrue);
    expect(list[1].statusLevel, GroupBudgetStatusLevel.danger);
  });

  test('GroupContributionEntity.fromJson đọc group_goal_contributions.json thật', () {
    final list = (fixtureData('group_goal_contributions') as List)
        .map((e) => GroupContributionEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(list, hasLength(2));
    expect(list[0].memberName, 'Người dùng A');
    expect(list[0].amountCents, BigInt.from(2000000));
    expect(list[0].note, 'Góp đầu');
    expect(list[1].note, isNull);
  });

  test('SavingsGoalEntity.fromJson đọc group_goals.json thật (DTO dùng chung với mục tiêu cá nhân)', () {
    final list = (fixtureData('group_goals') as List).map((e) => SavingsGoalEntity.fromJson(e as Map<String, dynamic>)).toList();

    expect(list, hasLength(2));
    expect(list[0].title, 'Du lịch hè');
    expect(list[0].targetAmountCents, BigInt.from(10000000));
    expect(list[0].currentAmountCents, BigInt.from(3000000));
    expect(list[1].status, 'completed');
    expect(list[1].isCompleted, isTrue);
  });

  test('GroupType/GroupRole/GroupTransactionVisibility map PascalCase hai chiều với API', () {
    expect(GroupType.family.apiValue, 'Family');
    expect(GroupType.fromApi('Other'), GroupType.other);
    expect(GroupRole.owner.apiValue, 'Owner');
    expect(GroupRole.fromApi('Viewer'), GroupRole.viewer);
    expect(GroupTransactionVisibility.full.apiValue, 'Full');
    expect(GroupTransactionVisibility.fromApi('Summary'), GroupTransactionVisibility.summary);
    expect(GroupPermission.manageBudgets.apiValue, 'ManageBudgets');
    expect(GroupPermission.fromApi('InviteMembers'), GroupPermission.inviteMembers);
    expect(GroupPermission.fromApi('KhongTonTai'), isNull);
  });

  group('GroupsRepository', () {
    test('getGroups/getGroup gọi đúng path GET', () async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/groups/g1')) {
          return respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]});
        }
        return respondFixture('groups');
      });
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getGroups();
      expect(list, hasLength(2));
      expect(adapter.requests.first.path, '/api/v1/groups');

      final one = await repo.getGroup('g1');
      expect(one.id, 'g1');
    });

    test('createGroup gửi type PascalCase', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createGroup(name: 'Gia đình', type: GroupType.family);

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups');
      expect(req.data, {'name': 'Gia đình', 'type': 'Family'});
    });

    test('updateGroup chỉ gửi trường được truyền (trường null giữ nguyên theo API)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.updateGroup(id: 'g1', transactionVisibility: GroupTransactionVisibility.summary);

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/groups/g1');
      expect(req.data, {'transactionVisibility': 'Summary'});
    });

    test('deleteGroup gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.deleteGroup('g1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1');
    });

    test('getActivities gửi limit theo query', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_activities'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.getActivities('g1', limit: 20);

      final req = adapter.requests.single;
      expect(req.path, '/api/v1/groups/g1/activities');
      expect(req.queryParameters, {'limit': 20});
    });

    test('getMembers gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_members'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getMembers('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/members');
    });

    test('updateMember gửi role và các quyền dạng PascalCase, chỉ gửi trường được truyền', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_members') as List)[1]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.updateMember(
        groupId: 'g1',
        userId: 'u2',
        role: GroupRole.manager,
        grantedPermissions: [GroupPermission.manageBudgets],
        revokedPermissions: [GroupPermission.inviteMembers],
      );

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/groups/g1/members/u2');
      expect(req.data, {
        'role': 'Manager',
        'grantedPermissions': ['ManageBudgets'],
        'revokedPermissions': ['InviteMembers'],
      });
    });

    test('removeMember gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.removeMember(groupId: 'g1', userId: 'u2');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/members/u2');
    });

    test('setAlerts gọi PUT với body enabled', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.setAlerts(groupId: 'g1', enabled: false);

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/v1/groups/g1/alerts');
      expect(req.data, {'enabled': false});
    });

    test('leaveGroup gọi POST đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.leaveGroup('g1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/leave');
    });

    test('transferOwnership gọi POST với newOwnerUserId', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.transferOwnership(groupId: 'g1', newOwnerUserId: 'u2');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/transfer-ownership');
      expect(req.data, {'newOwnerUserId': 'u2'});
    });

    test('createInvitation gửi role PascalCase, bỏ email khi để trống (mời qua link)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_invitations') as List)[1]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createInvitation(groupId: 'g1', role: GroupRole.viewer);

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/invitations');
      expect(req.data, {'role': 'Viewer'});
    });

    test('createInvitation gửi email khi có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_invitations') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createInvitation(groupId: 'g1', email: 'ban@example.com', role: GroupRole.member);

      final req = adapter.requests.single;
      expect(req.data, {'email': 'ban@example.com', 'role': 'Member'});
    });

    test('getInvitations gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_invitations'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getInvitations('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/invitations');
    });

    test('revokeInvitation gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.revokeInvitation(groupId: 'g1', invitationId: 'inv1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/invitations/inv1');
    });

    test('getTransactions gọi đúng path và query, mặc định limit=100', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_transactions'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getTransactions(groupId: 'g1', year: 2026, month: 11);

      expect(list, hasLength(2));
      final req = adapter.requests.single;
      expect(req.path, '/api/v1/groups/g1/transactions');
      expect(req.queryParameters, {'year': 2026, 'month': 11, 'limit': 100});
    });

    test('reclassifyTransaction gọi PATCH với groupCategoryId (có thể null để bỏ phân loại)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.reclassifyTransaction(groupId: 'g1', transactionId: 'gtx1', groupCategoryId: null);

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/groups/g1/transactions/gtx1');
      expect(req.data, {'groupCategoryId': null});
    });

    test('removeTransaction gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.removeTransaction(groupId: 'g1', transactionId: 'gtx1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/transactions/gtx1');
    });

    test('getMonthlyReport gọi đúng path và query', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_monthly_report'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final report = await repo.getMonthlyReport(groupId: 'g1', year: 2026, month: 11);

      expect(report.totalSpentCents, BigInt.from(150000));
      final req = adapter.requests.single;
      expect(req.path, '/api/v1/groups/g1/reports/monthly');
      expect(req.queryParameters, {'year': 2026, 'month': 11});
    });

    test('getCategories gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_categories'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getCategories('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/categories');
    });

    test('createCategory gửi name và iconName khi có', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_categories') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createCategory(groupId: 'g1', name: 'Ăn uống chung', iconName: 'utensils');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/categories');
      expect(req.data, {'name': 'Ăn uống chung', 'iconName': 'utensils'});
    });

    test('deleteCategory gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.deleteCategory(groupId: 'g1', categoryId: 'gc1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/categories/gc1');
    });

    test('getShareRules gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_share_rules'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getShareRules('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/share-rules');
    });

    test('createShareRule gửi financialAccountId/categoryId (có thể để trống một bên)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_share_rules') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createShareRule(groupId: 'g1', financialAccountId: 'acc1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/share-rules');
      expect(req.data, {'financialAccountId': 'acc1', 'categoryId': null});
    });

    test('deleteShareRule gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.deleteShareRule(groupId: 'g1', ruleId: 'gsr1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/share-rules/gsr1');
    });

    test('getBudgets gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_budgets'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getBudgets('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/budgets');
    });

    test('createBudget gửi categoryId/groupCategoryId/limitCents (null = ngân sách tổng)', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_budgets') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createBudget(groupId: 'g1', limitCents: BigInt.from(2000000));

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/budgets');
      expect(req.data, {'categoryId': null, 'groupCategoryId': null, 'limitCents': 2000000});
    });

    test('updateBudgetLimit gọi PATCH với limitCents mới', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_budgets') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.updateBudgetLimit(groupId: 'g1', budgetId: 'gb1', limitCents: BigInt.from(3000000));

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/groups/g1/budgets/gb1');
      expect(req.data, {'limitCents': 3000000});
    });

    test('deleteBudget gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.deleteBudget(groupId: 'g1', budgetId: 'gb1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/v1/groups/g1/budgets/gb1');
    });

    test('getGoals gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_goals'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getGoals('g1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/goals');
    });

    test('createGoal gửi name/targetCents/deadline', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.createGoal(groupId: 'g1', name: 'Du lịch hè', targetCents: BigInt.from(10000000));

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/goals');
      expect(req.data, {'name': 'Du lịch hè', 'targetCents': 10000000});
    });

    test('updateGoal chỉ gửi trường được truyền', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.updateGoal(groupId: 'g1', goalId: 'gg1', targetCents: BigInt.from(12000000));

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/v1/groups/g1/goals/gg1');
      expect(req.data, {'targetCents': 12000000});
    });

    test('cancelGoal gọi POST .../cancel', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.cancelGoal(groupId: 'g1', goalId: 'gg1');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/goals/gg1/cancel');
    });

    test('contributeToGoal gửi amountCents/note', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]}));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      await repo.contributeToGoal(groupId: 'g1', goalId: 'gg1', amountCents: BigInt.from(500000), note: 'Góp thêm');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/groups/g1/goals/gg1/contribute');
      expect(req.data, {'amountCents': 500000, 'note': 'Góp thêm'});
    });

    test('getGoalContributions gọi đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('group_goal_contributions'));
      final repo = GroupsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getGoalContributions(groupId: 'g1', goalId: 'gg1');

      expect(list, hasLength(2));
      expect(adapter.requests.single.path, '/api/v1/groups/g1/goals/gg1/contributions');
    });
  });

  group('groupsControllerProvider', () {
    test('tải danh sách khi có người dùng; chưa đăng nhập thì rỗng và không gọi API', () async {
      final adapter = RouteAdapter((o) => respondFixture('groups'));
      final userId = StateProvider<String?>((ref) => null);
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      container.listen(groupsControllerProvider, (_, __) {});
      await pumpEventQueue();
      expect(adapter.requests, isEmpty);
      expect(container.read(groupsControllerProvider).value, isEmpty);

      container.read(userId.notifier).state = 'u1';
      await pumpEventQueue();
      expect(container.read(groupsControllerProvider).value, hasLength(2));
    });

    test('create/delete/leave đều tải lại danh sách', () async {
      var writes = 0;
      final adapter = RouteAdapter((o) {
        if (o.method != 'GET') {
          writes++;
          return respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]});
        }
        return respondFixture('groups');
      });
      final userId = StateProvider<String?>((ref) => 'u1');
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
      ]);
      addTearDown(container.dispose);
      container.listen(groupsControllerProvider, (_, __) {});
      await pumpEventQueue();
      final getsBefore = adapter.requests.where((r) => r.method == 'GET').length;

      final notifier = container.read(groupsControllerProvider.notifier);
      await notifier.create(name: 'Gia đình');
      await notifier.delete('g1');
      await notifier.leave('g1');

      expect(writes, 3);
      final getsAfter = adapter.requests.where((r) => r.method == 'GET').length;
      expect(getsAfter, getsBefore + 3);
    });
  });
}
