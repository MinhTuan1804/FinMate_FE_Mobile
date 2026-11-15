/// Một sở thích dài hạn người dùng đặt cho trợ lý AI (GET /api/v1/agent/memory).
class AgentMemoryEntry {
  const AgentMemoryEntry({required this.key, required this.value, required this.updatedAt});

  final String key;
  final String value;
  final DateTime updatedAt;

  factory AgentMemoryEntry.fromJson(Map<String, dynamic> json) => AgentMemoryEntry(
        key: json['key'] as String,
        value: json['value'] as String? ?? '',
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}

/// Độ dài tối đa của giá trị, theo BE (`AgentLimits.MaxMemoryValueLength`).
const int agentMemoryMaxLength = 200;

/// Bốn khóa BE chấp nhận (khóa khác trả 422 invalid_memory_key) kèm tên thân thiện và gợi ý nhập.
const agentMemorySlots = <AgentMemorySlot>[
  AgentMemorySlot('preferred_method', 'Phương pháp quản lý tiền ưa thích', 'Ví dụ: 6 chiếc lọ'),
  AgentMemorySlot('eating_out_weekends', 'Thói quen ăn ngoài cuối tuần', 'Ví dụ: Thường ăn ngoài thứ 7, chủ nhật'),
  AgentMemorySlot('notification_quiet_hours', 'Giờ yên lặng của thông báo', 'Ví dụ: 22:00 - 07:00'),
  AgentMemorySlot('communication_tone', 'Giọng điệu trợ lý', 'Ví dụ: Ngắn gọn, thân thiện'),
];

class AgentMemorySlot {
  const AgentMemorySlot(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;
}
