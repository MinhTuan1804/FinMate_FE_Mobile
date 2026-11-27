import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/domain/agent_answer.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import '../../fixtures/fixture.dart';

/// Trợ lý trước, chat dự phòng: câu thống kê và "mua X được không" hỏi agent trước; agent chưa đủ dữ liệu / từ chối / lỗi thì hiện thẻ của chat.
const _summaryJson = {
  'action': 'summary',
  'intent': 'ask_spending',
  'summary': {
    'metric': 'expense',
    'periodLabel': 'tháng này',
    'from': '2026-10-01T00:00:00+07:00',
    'to': '2026-11-01T00:00:00+07:00',
    'totalCents': 110000,
    'incomeCents': 0,
    'expenseCents': 110000,
    'leftCents': -110000,
    'items': [
      {'categorySlug': 'food', 'categoryName': 'Ăn uống', 'amountCents': 110000, 'share': 1},
    ],
  },
};

const _purchaseJson = {
  'action': 'purchase',
  'intent': 'evaluate_purchase',
  'purchase': {'item': 'laptop', 'amountCents': 25000000},
};

class _Repo extends AssistantRepository {
  final Map<String, dynamic> chatJson;
  final AgentAnswer? answer; // null = agent lỗi
  int asked = 0;
  _Repo(this.chatJson, this.answer) : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId, Map<String, dynamic>? itemContext}) async => ChatReply.fromJson(chatJson);

  @override
  Future<AgentAnswer> askAgent(String question) async {
    asked++;
    final a = answer;
    if (a == null) throw Exception('Máy chủ đang bận');
    return a;
  }

  @override
  Future<PurchaseAssessment> purchaseCheck(PurchaseDraft draft) async =>
      PurchaseAssessment.fromJson({'status': 'assessable', 'verdict': 'fits_plan', 'summary': 'x', 'warnings': []});
}

Future<AssistantController> _ask(Map<String, dynamic> chatJson, AgentAnswer? answer, [String text = 'câu hỏi']) async {
  final c = AssistantController(repository: _Repo(chatJson, answer), retryEvery: null);
  await c.send(text);
  return c;
}

void main() {
  const answered = AgentAnswer(status: AgentAnswer.answered);

  test('thống kê: hỏi trợ lý trước, trợ lý trả lời được thì chỉ hiện thẻ của trợ lý', () async {
    final c = await _ask(_summaryJson, answered);
    expect(c.state.messages.whereType<AgentCard>(), hasLength(1));
    expect(c.state.messages.whereType<SummaryCard>(), isEmpty);
  });

  test('thống kê: trợ lý chưa đủ dữ liệu hoặc từ chối thì hiện thẻ số liệu của chat', () async {
    for (final status in [AgentAnswer.insufficientData, AgentAnswer.refused]) {
      final c = await _ask(_summaryJson, AgentAnswer(status: status));
      expect(c.state.messages.whereType<SummaryCard>(), hasLength(1), reason: status);
      expect(c.state.messages.whereType<AgentCard>(), isEmpty, reason: status);
    }
  });

  test('thống kê: trợ lý lỗi (429, 503...) thì cũng hiện thẻ của chat, không báo lỗi', () async {
    final c = await _ask(_summaryJson, null);
    expect(c.state.messages.whereType<SummaryCard>(), hasLength(1));
    expect(c.state.messages.whereType<AssistantText>(), isEmpty);
  });

  test('mua X được không: trợ lý trả lời được thì không dựng thẻ khoản định mua; không thì thẻ khoản định mua của chat', () async {
    final ok = await _ask(_purchaseJson, answered);
    expect(ok.state.messages.whereType<AgentCard>(), hasLength(1));
    expect(ok.state.messages.whereType<PurchaseCard>(), isEmpty);

    final fallback = await _ask(_purchaseJson, const AgentAnswer(status: AgentAnswer.insufficientData));
    expect(fallback.state.messages.whereType<PurchaseCard>(), hasLength(1));
    expect(fallback.state.messages.whereType<AgentCard>(), isEmpty);
  });

  test('câu ghi giao dịch không hỏi trợ lý', () async {
    final repo = _Repo({
      'action': 'confirm',
      'intent': 'add_expense',
      'draft': {'kind': 'expense', 'amountCents': 50000, 'transactionType': 'debit', 'description': 'ăn phở', 'missingFields': []},
    }, answered);
    final c = AssistantController(repository: repo, retryEvery: null);
    await c.send('ăn phở 50k');
    expect(repo.asked, 0);
  });
}
