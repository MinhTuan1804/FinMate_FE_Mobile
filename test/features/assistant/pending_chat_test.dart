import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/assistant/data/assistant_repository.dart';
import 'package:finmate/features/assistant/data/pending_message_store.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import '../../fixtures/fixture.dart';

/// Mất mạng thì câu (hoặc giọng nói) được giữ ở máy và tự phân tích khi có mạng lại; không hiện lỗi, không mất, không phân tích hai lần.
class _Repo extends AssistantRepository {
  bool down = false;
  final List<String> chatted = [];
  final List<String?> requestIds = [];
  final List<String> voiced = [];

  _Repo() : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async {
    if (down) throw NetworkException();
    chatted.add(text);
    requestIds.add(clientRequestId);
    return ChatReply.fromJson(fixtureData('chat_saved') as Map<String, dynamic>);
  }

  @override
  Future<VoiceReply> voiceChat(String filePath, {String? accountId, String? clientRequestId}) async {
    if (down) throw NetworkException();
    voiced.add(filePath);
    requestIds.add(clientRequestId);
    return VoiceReply(transcript: 'ăn phở 45k', chat: ChatReply.fromJson(fixtureData('chat_saved') as Map<String, dynamic>));
  }
}

class _ThrowingRepo extends AssistantRepository {
  _ThrowingRepo() : super(apiClient: testApiClient(RouteAdapter((o) => respondJson({'success': true}))));

  @override
  Future<ChatReply> chat(String text, {String? accountId, String? clientRequestId}) async => throw ApiException(code: 'VALIDATION_ERROR', message: 'sai');
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late PendingMessageStore store;
  late _Repo repo;
  late int dataChanged;

  AssistantController controller() => AssistantController(repository: repo, pending: store, retryEvery: null, onDataChanged: () => dataChanged++);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('pending_chat_test');
    store = PendingMessageStore(db, voiceDir: () async => dir);
    repo = _Repo();
    dataChanged = 0;
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('mất mạng khi nhắn: không hiện lỗi, câu được giữ ở máy và có lời báo', () async {
    repo.down = true;
    final c = controller();

    await c.send('ăn phở 45k');

    expect(c.state.messages.whereType<ErrorNote>(), isEmpty);
    expect(c.state.messages.whereType<AssistantText>().single.text, contains('giữ'));
    expect((await store.all()).map((m) => m.content), ['ăn phở 45k']);
    expect(c.state.isSending, isFalse);
  });

  test('có mạng lại: phân tích câu đã giữ bằng đúng mã cũ, hiện kết quả, rồi xóa khỏi hàng chờ', () async {
    repo.down = true;
    final c = controller();
    await c.send('ăn phở 45k');
    final saved = (await store.all()).single;
    repo.down = false;

    await c.retryPending();

    expect(repo.chatted, ['ăn phở 45k']);
    expect(repo.requestIds, [saved.id]);
    expect(c.state.messages.whereType<SavedCard>(), hasLength(1));
    expect(await store.all(), isEmpty);
    expect(dataChanged, 1);
  });

  test('vẫn mất mạng: câu ở lại hàng chờ, không thêm lời báo hay thẻ lỗi', () async {
    repo.down = true;
    final c = controller();
    await c.send('ăn phở 45k');
    final before = c.state.messages.length;

    await c.retryPending();

    expect(await store.all(), hasLength(1));
    expect(c.state.messages.length, before);
  });

  test('nhiều câu chờ: xử lý theo thứ tự, dừng ngay khi mất mạng lại để câu sau không bị vượt mặt', () async {
    repo.down = true;
    final c = controller();
    await c.send('ăn phở 45k');
    await c.send('đổ xăng 70k');
    repo.down = false;

    await c.retryPending();

    expect(repo.chatted, ['ăn phở 45k', 'đổ xăng 70k']);
    expect(await store.all(), isEmpty);
  });

  test('giọng nói khi mất mạng: giữ cả tệp ghi âm; có mạng lại thì gửi bản đã giữ và hiện câu nghe được', () async {
    final recorded = File('${dir.path}/rec.m4a')..writeAsBytesSync([9, 9]);
    repo.down = true;
    final c = controller();

    await c.sendVoice(recorded.path);

    expect(c.state.messages.whereType<ErrorNote>(), isEmpty);
    final item = (await store.all()).single;
    expect(item.kind, PendingKind.voice);
    repo.down = false;

    await c.retryPending();

    expect(repo.voiced, [item.content]);
    expect(c.state.messages.whereType<UserText>().single.text, 'ăn phở 45k');
    expect(await store.all(), isEmpty);
    expect(File(item.content).existsSync(), isFalse);
  });

  test('mở lại app (cuộc trò chuyện mới): câu giữ từ lần trước vẫn được phân tích và hiện kèm câu gốc của người dùng', () async {
    await store.addText('old-1', 'ăn phở 45k', DraftSource.chat); // do lần chạy trước để lại
    final c = controller();

    await c.retryPending();

    expect(c.state.messages.map((m) => m.runtimeType), [UserText, SavedCard]);
    expect((c.state.messages.first as UserText).text, 'ăn phở 45k');
    expect(repo.requestIds, ['old-1']);
    expect(await store.all(), isEmpty);
  });

  test('câu vừa nhắn trong phiên này không bị hiện hai lần khi được phân tích lại', () async {
    repo.down = true;
    final c = controller();
    await c.send('ăn phở 45k');
    repo.down = false;

    await c.retryPending();

    expect(c.state.messages.whereType<UserText>(), hasLength(1));
  });

  test('lỗi không phải mất mạng (server từ chối) vẫn hiện thẻ lỗi như cũ, không vào hàng chờ', () async {
    final c = AssistantController(repository: _ThrowingRepo(), pending: store, retryEvery: null);

    await c.send('ăn phở 45k');

    expect(c.state.messages.whereType<ErrorNote>(), hasLength(1));
    expect(await store.all(), isEmpty);
  });

  test('gọi retryPending chồng nhau thì chỉ chạy một lần', () async {
    repo.down = true;
    final c = controller();
    await c.send('ăn phở 45k');
    repo.down = false;

    final first = c.retryPending();
    await c.retryPending();
    await first;

    expect(repo.chatted, ['ăn phở 45k']);
  });
}
