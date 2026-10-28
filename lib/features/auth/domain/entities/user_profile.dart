/// Entity User Profile phản ánh thông tin người dùng từ FinMate.API
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final int? monthlyIncomeCents; // VND BIGINT (không dùng float)
  final bool isEmailVerified;
  final NotificationPrefs notificationPrefs;
  final DateTime createdAt;

  /// Đã đồng ý Điều khoản + Chính sách quyền riêng tư ở phiên bản hiện hành (server tính); false thì phải qua màn /terms
  final bool termsAccepted;

  /// Đã đồng ý gửi tên món và cụm sản phẩm (hóa đơn, chat, giọng nói) cho AI ở phiên bản hiện hành; mặc định chưa
  final bool aiConsentGranted;

  /// Đã đồng ý đóng góp chữ hóa đơn đã lọc + nhãn cuối để cải thiện phân loại (tách biệt với đồng ý AI); mặc định chưa
  final bool trainingConsentGranted;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.monthlyIncomeCents,
    required this.isEmailVerified,
    required this.notificationPrefs,
    required this.createdAt,
    this.termsAccepted = false,
    this.aiConsentGranted = false,
    this.trainingConsentGranted = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      monthlyIncomeCents: (json['monthlyIncomeCents'] as num?)?.toInt(),
      // Backend không trả emailVerifiedAt; đăng nhập đã chặn user chưa xác thực nên có hồ sơ nghĩa là đã xác thực
      isEmailVerified: true,
      // Cờ thông báo nằm phẳng trong hồ sơ (không lồng notificationPrefs)
      notificationPrefs: NotificationPrefs.fromJson(json),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      aiConsentGranted: json['aiConsentGranted'] as bool? ?? false,
      trainingConsentGranted: json['trainingConsentGranted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'monthlyIncomeCents': monthlyIncomeCents,
      'notificationPrefs': notificationPrefs.toJson(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    int? monthlyIncomeCents,
    NotificationPrefs? notificationPrefs,
    bool? termsAccepted,
    bool? aiConsentGranted,
    bool? trainingConsentGranted,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      monthlyIncomeCents: monthlyIncomeCents ?? this.monthlyIncomeCents,
      isEmailVerified: isEmailVerified,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      createdAt: createdAt,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      aiConsentGranted: aiConsentGranted ?? this.aiConsentGranted,
      trainingConsentGranted: trainingConsentGranted ?? this.trainingConsentGranted,
    );
  }
}

class NotificationPrefs {
  final bool pushEnabled;
  final bool budgetAlertsEnabled;
  final bool missionRemindersEnabled;

  NotificationPrefs({
    required this.pushEnabled,
    required this.budgetAlertsEnabled,
    required this.missionRemindersEnabled,
  });

  factory NotificationPrefs.defaultPrefs() {
    return NotificationPrefs(
      pushEnabled: true,
      budgetAlertsEnabled: true,
      missionRemindersEnabled: true,
    );
  }

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      budgetAlertsEnabled: json['budgetAlertsEnabled'] as bool? ?? true,
      missionRemindersEnabled: json['missionRemindersEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'budgetAlertsEnabled': budgetAlertsEnabled,
      'missionRemindersEnabled': missionRemindersEnabled,
    };
  }
}
