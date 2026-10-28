import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/assistant/data/pending_message_store.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';

/// Câu hoặc giọng nói chưa phân tích được vì mất mạng: giữ ở máy (qua khởi động lại) để phân tích khi có mạng.
void main() {
  late AppDatabase db;
  late Directory dir;
  late PendingMessageStore store;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('pending_voice_test');
    store = PendingMessageStore(db, voiceDir: () async => dir);
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('giữ câu chữ và trả lại theo thứ tự đã nhắn, kèm mã chống trùng và nguồn', () async {
    await store.addText('r1', 'ăn phở 45k', DraftSource.chat);
    await store.addText('r2', 'đổ xăng 70k', DraftSource.chat);

    final all = await store.all();

    expect(all.map((m) => (m.id, m.kind, m.content, m.source)), [('r1', PendingKind.text, 'ăn phở 45k', DraftSource.chat), ('r2', PendingKind.text, 'đổ xăng 70k', DraftSource.chat)]);
  });

  test('giọng nói: sao chép tệp ghi âm vào thư mục riêng (tệp tạm có thể bị hệ điều hành xóa), xóa bản sao khi xong', () async {
    final temp = File('${dir.path}/recorded.m4a')..writeAsBytesSync([1, 2, 3]);

    await store.addVoice('v1', temp.path);

    final item = (await store.all()).single;
    expect(item.kind, PendingKind.voice);
    expect(item.content, isNot(temp.path)); // đã sao chép sang chỗ khác
    expect(File(item.content).readAsBytesSync(), [1, 2, 3]);
    expect(item.source, DraftSource.voice);

    await store.remove('v1');

    expect(await store.all(), isEmpty);
    expect(File(item.content).existsSync(), isFalse);
  });

  test('thêm lại cùng một mã không tạo bản thứ hai', () async {
    await store.addText('r1', 'ăn phở 45k', DraftSource.chat);
    await store.addText('r1', 'ăn phở 45k', DraftSource.chat);

    expect(await store.all(), hasLength(1));
  });
}
