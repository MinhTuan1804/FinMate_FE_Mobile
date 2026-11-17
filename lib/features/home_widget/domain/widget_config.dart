/// Loại widget home-screen (Luồng 9) — khớp 3 kích thước Stitch (W1/W2/4×4).
enum HomeWidgetKind {
  safeSpend('w1'),
  overview('w2'),
  detail('w4x4');

  final String id;
  const HomeWidgetKind(this.id);

  static HomeWidgetKind fromId(String id) =>
      HomeWidgetKind.values.firstWhere((k) => k.id == id, orElse: () => HomeWidgetKind.overview);
}

/// Chu kỳ làm mới dữ liệu widget nền (xem WorkManager ở lớp refresh, chưa build trong đợt config
/// activity này — xem PENDING_ITEMS.md khi bắt đầu đợt đó).
enum WidgetRefreshMode {
  /// Ngay khi có giao dịch mới + định kỳ mỗi 30 phút (mặc định theo Stitch).
  immediateAndPeriodic,

  /// Tiết kiệm pin: chỉ làm mới định kỳ mỗi 2 giờ, không làm mới ngay khi có giao dịch.
  batterySaver,
}

/// Cấu hình 1 instance widget đã ghim (lưu/đọc qua home_widget, khoá theo widgetId để nhiều
/// instance cùng loại có thể có cấu hình khác nhau).
class WidgetConfig {
  final bool aiSuggestionsEnabled;

  /// null = "Tất cả tài khoản"
  final String? sourceAccountId;
  final WidgetRefreshMode refreshMode;

  const WidgetConfig({
    this.aiSuggestionsEnabled = true,
    this.sourceAccountId,
    this.refreshMode = WidgetRefreshMode.immediateAndPeriodic,
  });

  WidgetConfig copyWith({
    bool? aiSuggestionsEnabled,
    String? Function()? sourceAccountId,
    WidgetRefreshMode? refreshMode,
  }) =>
      WidgetConfig(
        aiSuggestionsEnabled: aiSuggestionsEnabled ?? this.aiSuggestionsEnabled,
        sourceAccountId: sourceAccountId != null ? sourceAccountId() : this.sourceAccountId,
        refreshMode: refreshMode ?? this.refreshMode,
      );
}
