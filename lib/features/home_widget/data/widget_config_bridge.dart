import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:finmate/features/home_widget/domain/widget_config.dart';

/// Cầu nối giữa K1WidgetConfigScreen (Flutter) và WidgetConfigActivity (native):
/// - Đọc widgetId/loại widget mà Android vừa mở màn cấu hình cho (qua MethodChannel riêng).
/// - Ghi cấu hình xuống SharedPreferences dùng chung với Glance qua package `home_widget`.
/// - Báo native đóng Activity đúng quy ước AppWidget configuration activity (OK/CANCELED).
class WidgetConfigBridge {
  WidgetConfigBridge({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.finmate.app/widget_config';
  final MethodChannel _channel;

  Future<int?> getWidgetId() async {
    try {
      return await _channel.invokeMethod<int>('getWidgetId');
    } on MissingPluginException {
      return null;
    }
  }

  Future<HomeWidgetKind> getWidgetKind() async {
    try {
      final id = await _channel.invokeMethod<String>('getWidgetKind');
      return HomeWidgetKind.fromId(id ?? HomeWidgetKind.overview.id);
    } on MissingPluginException {
      return HomeWidgetKind.overview;
    }
  }

  /// Lưu cấu hình cho từng widgetId trong [widgetIds] (nhiều instance cùng loại có thể khác cấu
  /// hình) rồi yêu cầu Glance vẽ lại ngay — không chờ chu kỳ WorkManager kế tiếp. Lối vào native
  /// (WidgetConfigActivity) truyền đúng 1 id; lối vào từ Cài đặt (sửa lại, không có appWidgetId cụ
  /// thể) truyền tất cả id đang ghim của [kind], xem [getPinnedWidgetIds].
  Future<void> saveConfig(List<int> widgetIds, HomeWidgetKind kind, WidgetConfig config) async {
    for (final widgetId in widgetIds) {
      await HomeWidget.saveWidgetData<bool>('aiSuggestionsEnabled_$widgetId', config.aiSuggestionsEnabled);
      await HomeWidget.saveWidgetData<String>('sourceAccountId_$widgetId', config.sourceAccountId ?? '');
      await HomeWidget.saveWidgetData<String>('refreshMode_$widgetId', config.refreshMode.name);
    }
    if (widgetIds.isNotEmpty) {
      await HomeWidget.updateWidget(qualifiedAndroidName: _receiverClassName(kind));
    }
  }

  /// Đọc lại cấu hình đã lưu của [widgetId] — dùng khi mở lại màn cấu hình từ Cài đặt
  /// (editAllPinned) để công tắc khởi tạo đúng trạng thái đã lưu, không phải luôn mặc định.
  Future<WidgetConfig> loadConfig(int widgetId) async {
    final aiSuggestionsEnabled = await HomeWidget.getWidgetData<bool>('aiSuggestionsEnabled_$widgetId') ?? true;
    final sourceAccountId = await HomeWidget.getWidgetData<String>('sourceAccountId_$widgetId');
    final refreshModeName = await HomeWidget.getWidgetData<String>('refreshMode_$widgetId');
    return WidgetConfig(
      aiSuggestionsEnabled: aiSuggestionsEnabled,
      sourceAccountId: (sourceAccountId == null || sourceAccountId.isEmpty) ? null : sourceAccountId,
      refreshMode: WidgetRefreshMode.values.firstWhere(
        (m) => m.name == refreshModeName,
        orElse: () => WidgetRefreshMode.immediateAndPeriodic,
      ),
    );
  }

  /// Mọi appWidgetId đang ghim của [kind] — chỉ dùng khi mở màn cấu hình từ trong app (Cài đặt),
  /// nơi không có sẵn 1 appWidgetId cụ thể như lối vào native WidgetConfigActivity.
  Future<List<int>> getPinnedWidgetIds(HomeWidgetKind kind) async {
    try {
      final ids = await _channel.invokeMethod<List<dynamic>>('getPinnedWidgetIds', {'kind': kind.id});
      return ids?.cast<int>() ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// accepted = false khi người dùng bấm nút đóng (X) — Android sẽ không ghim widget dở dang.
  Future<void> finishConfig({required bool accepted}) async {
    try {
      await _channel.invokeMethod('finishConfig', {'accepted': accepted});
    } on MissingPluginException {
      // Không chạy trên Android (vd. preview trong app sau này từ Cài đặt) — bỏ qua an toàn.
    }
  }

  String _receiverClassName(HomeWidgetKind kind) => switch (kind) {
        HomeWidgetKind.safeSpend => 'com.finmate.app.widgets.SafeSpendWidgetReceiver',
        HomeWidgetKind.overview => 'com.finmate.app.widgets.OverviewWidgetReceiver',
        HomeWidgetKind.detail => 'com.finmate.app.widgets.DetailWidgetReceiver',
      };
}
