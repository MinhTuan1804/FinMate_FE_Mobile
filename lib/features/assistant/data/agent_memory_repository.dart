import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/assistant/domain/agent_memory.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final agentMemoryRepositoryProvider = Provider<AgentMemoryRepository>(
  (ref) => AgentMemoryRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Bộ nhớ dài hạn của trợ lý AI (`/api/v1/agent/memory`). Chỉ 4 khóa hợp lệ, xem [agentMemorySlots].
final agentMemoryProvider = FutureProvider.autoDispose<List<AgentMemoryEntry>>(
  (ref) => ref.watch(agentMemoryRepositoryProvider).list(),
);

class AgentMemoryRepository {
  AgentMemoryRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<AgentMemoryEntry>> list() async {
    final response = await apiClient.get(
      '/api/v1/agent/memory',
      fromJsonT: (json) => (json as List).map((e) => AgentMemoryEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// 422 nếu khóa không hợp lệ hoặc giá trị rỗng / quá [agentMemoryMaxLength] ký tự.
  Future<void> put(String key, String value) async {
    await apiClient.put('/api/v1/agent/memory/${Uri.encodeComponent(key)}', data: {'value': value}, fromJsonT: (json) => json);
  }

  Future<void> delete(String key) => apiClient.delete('/api/v1/agent/memory/${Uri.encodeComponent(key)}');

  /// Xóa toàn bộ bộ nhớ dài hạn và ngữ cảnh hội thoại.
  Future<void> deleteAll() => apiClient.delete('/api/v1/agent/memory');
}
