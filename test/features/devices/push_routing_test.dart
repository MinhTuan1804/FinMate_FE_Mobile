import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/devices/data/push_messaging.dart';
import 'package:finmate/features/notifications_inbox/presentation/screens/notifications_inbox_screen.dart';

void main() {
  test('bấm push mở đúng màn theo data BE gửi kèm', () {
    expect(routeForPush({'type': 'transaction_auto_committed'}), ('/transactions', null));
    expect(routeForPush({'type': 'transaction_review'}), ('/transactions', null));
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'budget_risk'}), ('/planning/budgets', null));
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'bill_due'}), ('/planning/recurring', null));
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'anomaly'}), ('/analytics/alerts', null));
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'group_approval_req', 'groupId': 'g1'}), ('/group-approvals', 'g1'));
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'group_budget', 'groupId': 'g1'}), ('/group-detail', 'g1'));
    // Thiếu groupId thì không mở màn nhóm (builder ép kiểu extra String) mà về danh sách cảnh báo
    expect(routeForPush({'action': 'forecast_alert', 'kind': 'group_budget'}), ('/analytics/alerts', null));
    expect(routeForPush({'action': 'subscription_expiring'}), ('/profile/subscription', null));
    expect(routeForPush({'action': 'support_access_request', 'ticketId': 't1'}), ('/support-ticket', 't1'));
    expect(routeForPush({'action': 'support_ticket'}), ('/notifications', null));
    expect(routeForPush({'action': 'budget_alert'}), ('/planning/budgets', null));
    expect(routeForPush({'action': 'goal_deadline', 'goalId': 'x'}), ('/planning/goals', null));
    expect(routeForPush({'action': 'loan_due', 'loanId': 'x'}), ('/planning/loans', null));
    expect(routeForPush({}), ('/notifications', null));
  });

  test('bấm thông báo trong hộp thư mở đúng màn theo loại', () {
    expect(routeForInboxType('BalanceChange'), '/transactions');
    expect(routeForInboxType('BudgetThreshold'), '/planning/budgets');
    expect(routeForInboxType('RecurringBillDue'), '/planning/recurring');
    expect(routeForInboxType('Unknown'), isNull);
  });
}
