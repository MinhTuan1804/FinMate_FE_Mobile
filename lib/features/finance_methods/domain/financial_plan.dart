/// Một dòng hạn mức trong bản nháp kế hoạch tháng (GET /me/financial-plan/draft). Số tiền là đồng (int).
class FinancialPlanLineEntity {
  final String categoryId;
  final String slug;
  final String name;
  final String? groupKey;
  final int fixedVnd;
  final int declaredVnd;
  final int limitVnd;
  final int reducedByVnd;

  const FinancialPlanLineEntity({
    required this.categoryId,
    required this.slug,
    required this.name,
    required this.groupKey,
    required this.fixedVnd,
    required this.declaredVnd,
    required this.limitVnd,
    required this.reducedByVnd,
  });

  factory FinancialPlanLineEntity.fromJson(Map<String, dynamic> json) => FinancialPlanLineEntity(
        categoryId: json['categoryId'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        groupKey: json['groupKey'] as String?,
        fixedVnd: (json['fixedVnd'] as num).toInt(),
        declaredVnd: (json['declaredVnd'] as num).toInt(),
        limitVnd: (json['limitVnd'] as num).toInt(),
        reducedByVnd: (json['reducedByVnd'] as num).toInt(),
      );
}

class FinancialPlanGroupEntity {
  final String? key;
  final String label;
  final String kind;

  const FinancialPlanGroupEntity({required this.key, required this.label, required this.kind});

  factory FinancialPlanGroupEntity.fromJson(Map<String, dynamic> json) => FinancialPlanGroupEntity(
        key: json['key'] as String?,
        label: json['label'] as String,
        kind: json['kind'] as String,
      );
}

/// Bản nháp kế hoạch tháng: backend tính từ khảo sát + cách quản lý chính, không lưu gì. Áp dụng = lưu hạn mức qua `POST /forecast/categories/apply`.
class FinancialPlanEntity {
  final String methodCode;
  final int incomeVnd;
  final int fixedVnd;
  final int fixedOtherVnd;
  final int surplusVnd;
  final int saveTargetVnd;
  final List<FinancialPlanLineEntity> categories;
  final List<FinancialPlanGroupEntity> groups;
  final List<String> warnings;

  /// Chữ cảnh báo theo mã, admin sửa trong cấu hình hệ thống; có cả mã app tự tính lại khi sửa hạn mức.
  final Map<String, String> warningTexts;

  const FinancialPlanEntity({
    required this.methodCode,
    required this.incomeVnd,
    required this.fixedVnd,
    required this.fixedOtherVnd,
    required this.surplusVnd,
    required this.saveTargetVnd,
    required this.categories,
    required this.groups,
    required this.warnings,
    this.warningTexts = const {},
  });

  factory FinancialPlanEntity.fromJson(Map<String, dynamic> json) => FinancialPlanEntity(
        methodCode: json['methodCode'] as String,
        incomeVnd: (json['incomeVnd'] as num).toInt(),
        fixedVnd: (json['fixedVnd'] as num).toInt(),
        fixedOtherVnd: (json['fixedOtherVnd'] as num).toInt(),
        surplusVnd: (json['surplusVnd'] as num).toInt(),
        saveTargetVnd: (json['saveTargetVnd'] as num).toInt(),
        categories: (json['categories'] as List).map((e) => FinancialPlanLineEntity.fromJson(e as Map<String, dynamic>)).toList(),
        groups: (json['groups'] as List).map((e) => FinancialPlanGroupEntity.fromJson(e as Map<String, dynamic>)).toList(),
        warnings: (json['warnings'] as List).cast<String>(),
        warningTexts: (json['warningTexts'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as String)),
      );
}

/// Số dư cuối tháng sau khi người dùng sửa hạn mức: thu nhập − tổng hạn mức − khoản cố định ngoài danh mục (trả nợ).
/// [limits] là hạn mức đang sửa theo slug; danh mục chưa sửa dùng hạn mức backend đề xuất.
int planSurplus(FinancialPlanEntity plan, Map<String, int> limits) =>
    plan.incomeVnd -
    plan.fixedOtherVnd -
    plan.categories.fold<int>(0, (sum, line) => sum + (limits[line.slug] ?? line.limitVnd));

/// Chữ hiển thị của một mã cảnh báo: ưu tiên chữ backend gửi (cấu hình hệ thống, admin sửa được);
/// bảng dưới chỉ là dự phòng khi backend cũ chưa gửi `warningTexts`.
String financialPlanWarningText(String code, FinancialPlanEntity plan) =>
    plan.warningTexts[code] ?? _fallbackWarningText(code, plan.groups);

String _fallbackWarningText(String code, List<FinancialPlanGroupEntity> groups) {
  const fixedPrefix = 'fixed_exceeds_group:';
  if (code.startsWith(fixedPrefix)) {
    final key = code.substring(fixedPrefix.length);
    final label = groups.where((g) => g.key == key).map((g) => g.label).firstOrNull ?? key;
    return 'Khoản cố định đã vượt phần dành cho nhóm "$label", nên các khoản linh hoạt trong nhóm này tạm để 0.';
  }

  return switch (code) {
    'deficit' => 'Chi dự kiến đang vượt thu nhập. Trước hết hãy giảm bớt chi hoặc tìm thêm thu nhập để không bị hụt cuối tháng, rồi mới tính đến để dành.',
    'below_save_target' => 'Phần dư chưa đạt mức để dành mà cách quản lý này đề xuất. Bạn có thể giảm bớt vài hạn mức để dư nhiều hơn.',
    _ => code,
  };
}
