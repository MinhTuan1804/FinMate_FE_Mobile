import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';

enum PendingKind { text, voice }

/// Một câu chờ phân tích. Với giọng nói, [content] là đường dẫn tệp ghi âm ĐÃ SAO CHÉP vào thư mục riêng.
class PendingItem {
  final String id;
  final PendingKind kind;
  final String content;
  final DraftSource source;
  final DateTime createdAt;

  const PendingItem(this.id, this.kind, this.content, this.source, this.createdAt);
}

/// Hàng chờ ở máy cho câu chat/giọng nói chưa phân tích được vì mất mạng. Sống qua khởi động lại app (nằm trong database của người dùng).
class PendingMessageStore {
  final AppDatabase db;
  final Future<Directory> Function() _voiceDir;

  PendingMessageStore(this.db, {Future<Directory> Function()? voiceDir}) : _voiceDir = voiceDir ?? _defaultVoiceDir;

  static Future<Directory> _defaultVoiceDir() async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'pending_voice'));

  Future<void> addText(String id, String text, DraftSource source) => _insert(id, PendingKind.text, text, source);

  /// Sao chép tệp ghi âm đi chỗ khác: tệp gốc nằm trong thư mục tạm mà hệ điều hành có thể dọn bất cứ lúc nào
  Future<void> addVoice(String id, String recordedPath) async {
    final dir = await _voiceDir();
    await dir.create(recursive: true);
    final copy = await File(recordedPath).copy(p.join(dir.path, '$id.m4a'));
    await _insert(id, PendingKind.voice, copy.path, DraftSource.voice);
  }

  Future<List<PendingItem>> all() async => [
        for (final r in await db.allPending())
          PendingItem(r.id, PendingKind.values.byName(r.kind), r.content, DraftSource.values.byName(r.source), r.createdAt),
      ];

  Future<void> remove(String id) async {
    final item = (await all()).where((m) => m.id == id).firstOrNull;
    await db.deletePending(id);
    if (item != null && item.kind == PendingKind.voice) {
      final file = File(item.content);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _insert(String id, PendingKind kind, String content, DraftSource source) =>
      db.insertPending(PendingMessagesCompanion.insert(id: id, kind: kind.name, content: content, source: source.name, createdAt: DateTime.now()));
}

final pendingMessageStoreProvider = Provider<PendingMessageStore>((ref) => PendingMessageStore(ref.watch(databaseProvider)));
