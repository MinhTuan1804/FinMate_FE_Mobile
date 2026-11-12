import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';

/// Màn F5: Kiểm tra mua sắm an toàn (Purchase Check / "Nên mua không?")
class PurchaseCheckScreen extends ConsumerStatefulWidget {
  const PurchaseCheckScreen({super.key});

  @override
  ConsumerState<PurchaseCheckScreen> createState() => _PurchaseCheckScreenState();
}

class _PurchaseCheckScreenState extends ConsumerState<PurchaseCheckScreen> {
  final _amountController = TextEditingController();
  final _itemController = TextEditingController();
  String? _selectedCategory;

  bool _hasChecked = false;
  bool _isSafe = true;
  int _safetyScore = 85; // 0 - 100
  String _verdictTitle = 'An toàn để mua sắm';
  String _verdictDescription =
      'Khoản chi này nằm trong hạn mức an toàn của bạn hôm nay và không ảnh hưởng đến mục tiêu tiết kiệm cuối tháng.';

  @override
  void dispose() {
    _amountController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  void _runCheck() {
    final rawText = _amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final amount = int.tryParse(rawText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ.')),
      );
      return;
    }

    setState(() {
      _hasChecked = true;
      if (amount <= 250000) {
        _isSafe = true;
        _safetyScore = 92;
        _verdictTitle = 'Hoàn toàn an toàn để mua sắm';
        _verdictDescription =
            'Số tiền này chiếm dưới 30% hạn mức chi an toàn còn lại hôm nay của bạn. Bạn có thể tự tin chi tiêu.';
      } else if (amount <= 1000000) {
        _isSafe = true;
        _safetyScore = 65;
        _verdictTitle = 'Nên cân nhắc kỹ';
        _verdictDescription =
            'Khoản chi này sẽ làm giảm tốc độ tích lũy cho mục tiêu tiết kiệm trong 3 ngày tới. Hãy cân nhắc xem món đồ này có thực sự cấp thiết không.';
      } else {
        _isSafe = false;
        _safetyScore = 28;
        _verdictTitle = 'Vượt ngân sách cho phép';
        _verdictDescription =
            'Khoản chi này sẽ khiến bạn vượt hạn mức ngân sách tháng và buộc phải bù trừ từ quỹ dự phòng khẩn cấp.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra mua sắm'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Intro
              Text(
                'Nên mua hay không?',
                style: AppTypography.h1(context).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nhập món đồ bạn đang định mua để AI FinMate giả lập tác động lên ngân sách và đưa ra lời khuyên khách quan.',
                style: AppTypography.caption(context).copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 20),

              // Input Sheet
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tên món đồ / Dịch vụ', style: AppTypography.bodyMedium(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _itemController,
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: Tai nghe chống ồn, Áo khoác dạ...',
                        prefixIcon: Icon(LucideIcons.shoppingBag, size: 18),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text('Số tiền dự tính (VNĐ)', style: AppTypography.bodyMedium(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '500.000',
                        prefixIcon: Icon(LucideIcons.coins, size: 18),
                        suffixText: '₫',
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text('Danh mục chi tiêu', style: AppTypography.bodyMedium(context)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLightSubtle.withValues(alpha: 0.6),
                        borderRadius: AppSpacing.roundedLarge,
                        border: Border.all(color: AppColors.borderLight, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          hint: const Text('Chọn danh mục phù hợp'),
                          isExpanded: true,
                          items: categories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    LiquidGlassPillButton(
                      label: 'Phân tích khả năng mua',
                      isFullWidth: true,
                      icon: LucideIcons.sparkles,
                      onPressed: _runCheck,
                    ),
                  ],
                ),
              ),

              if (_hasChecked) ...[
                const SizedBox(height: 24),
                ZenvestHeroDeck(
                  peekBadgeText: _isSafe ? 'PASS' : 'WARN',
                  child: LiquidGlassCard(
                    variant: LiquidGlassVariant.iridescentHero,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: (_isSafe ? AppColors.safe : AppColors.danger)
                                .withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              _isSafe ? LucideIcons.shieldCheck : LucideIcons.triangleAlert,
                              size: 30,
                              color: _isSafe ? AppColors.safe : AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _verdictTitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.h2(context).copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _isSafe ? AppColors.safe : AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _verdictDescription,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Chỉ số an toàn: ',
                              style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$_safetyScore/100',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _isSafe ? AppColors.safe : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
