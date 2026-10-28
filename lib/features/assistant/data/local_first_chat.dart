import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/features/assistant/data/draft_saver.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart';

/// Bật chat theo hướng local-first: server chỉ hiểu câu, app tự quyết định, ghi ở máy rồi đồng bộ. Mặc định TẮT cho đến khi
/// đã thử trên máy thật; tắt thì chat đi đường cũ (`POST /transactions/chat`) như trước.
final localFirstChatProvider = StateProvider<bool>((ref) => false);

/// Những gì chat cần để tự quyết định và ghi ở máy
class LocalFirstChat {
  final LocalChatDecider decider;
  final DraftSaver saver;

  /// Người dùng xác nhận [description] (tại [merchant]) thuộc danh mục [slug]
  final Future<void> Function(String? merchant, String? description, String slug) remember;

  const LocalFirstChat({required this.decider, required this.saver, required this.remember});

  factory LocalFirstChat.fromRef(Ref ref) {
    final db = ref.read(databaseProvider);
    return LocalFirstChat(
      decider: LocalChatDecider(db: db),
      saver: DraftSaver.fromRef(ref),
      remember: (merchant, description, slug) => db.rememberCategory(merchantKey: memoryKey(merchant), itemKey: memoryKey(description), categorySlug: slug),
    );
  }
}
