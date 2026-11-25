import 'package:finmate/features/forecast/domain/forecast.dart';

/// Việc phía sau nút hành động của một cảnh báo dự báo. Tách khỏi màn hình để kiểm thử mà không cần dựng giao diện;
/// màn hình đưa vào hai hàm gọi API có sẵn (đặt hạn mức, theo dõi lại khoản định kỳ).
class AlertActionRunner {
  /// [categoryId] null = ngân sách tổng
  final Future<void> Function(String? categoryId, BigInt limitCents) raiseBudgetLimit;
  final Future<void> Function(String recurringItemId) resumeRecurring;

  const AlertActionRunner({required this.raiseBudgetLimit, required this.resumeRecurring});

  /// Chạy một hành động. `open_forecast` chỉ là điều hướng nên màn hình tự làm (trả false ở đây), cũng như loại lạ hoặc thiếu dữ liệu.
  /// Lỗi của API được ném lại để màn hình hiện lý do và cho bấm lại.
  Future<bool> run(ForecastAlertAction action) async {
    if (!action.canRun) return false;
    switch (action.kind) {
      case ForecastAlertAction.raiseBudgetLimit:
        final category = action.categoryId!;
        await raiseBudgetLimit(category.isEmpty ? null : category, action.amountCents!);
        return true;
      case ForecastAlertAction.resumeRecurring:
        await resumeRecurring(action.targetId!);
        return true;
      default:
        return false;
    }
  }

  /// Nhãn khi xong, theo loại
  static String doneLabel(String kind) => switch (kind) {
        ForecastAlertAction.raiseBudgetLimit => 'Đã nâng hạn mức',
        ForecastAlertAction.resumeRecurring => 'Đã theo dõi lại',
        _ => 'Đã xong',
      };
}
