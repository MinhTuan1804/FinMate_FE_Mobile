import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

enum LegalDocType { terms, privacy }

/// Màn H9 & H10: Điều khoản sử dụng & Chính sách bảo mật (Dùng chung 1 template đọc văn bản)
class LegalDocumentScreen extends ConsumerStatefulWidget {
  final LegalDocType type;

  const LegalDocumentScreen({super.key, required this.type});

  @override
  ConsumerState<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  int _activeSection = 0;

  @override
  Widget build(BuildContext context) {
    final isTerms = widget.type == LegalDocType.terms;
    final title = isTerms ? 'Điều khoản sử dụng' : 'Chính sách bảo mật';

    final sections = isTerms
        ? [
            ('1. Giới thiệu', 'FinMate là ứng dụng đồng hành quản lý tài chính cá nhân thông minh. Khi đăng ký và sử dụng dịch vụ, bạn đồng ý tuân thủ các điều khoản được nêu tại đây.'),
            ('2. Quyền & Nghĩa vụ', 'Người dùng có nghĩa vụ bảo vệ tài khoản của mình. FinMate cam kết cung cấp dịch vụ quản lý thu chi, ngân sách và phân tích chi tiêu chính xác theo dữ liệu bạn nhập.'),
            ('3. Dịch vụ AI & Phân tích', 'Các khuyến nghị tài chính từ AI mang tính chất tham khảo, hỗ trợ ra quyết định cá nhân. FinMate không chịu trách nhiệm pháp lý đối với các quyết định đầu tư sinh lời của người dùng.'),
            ('4. Chấm dứt dịch vụ', 'Bạn có quyền xuất toàn bộ dữ liệu và yêu cầu xóa vĩnh viễn tài khoản bất kỳ lúc nào thông qua phần Cài đặt của ứng dụng.'),
          ]
        : [
            ('1. Cam kết Zero-Credential', 'FinMate tuân thủ nguyên tắc Zero-Credential. Chúng tôi KHÔNG BAO GIỜ yêu cầu hay lưu trữ mật khẩu đăng nhập tài khoản ngân hàng hoặc mã OTP ngân hàng của bạn.'),
            ('2. Dữ liệu thu thập', 'Chúng tôi chỉ lưu trữ các thông tin giao dịch, hạn mức ngân sách và mục tiêu mà bạn chủ động ghi chép hoặc đồng ý quét qua hóa đơn/biến động số dư.'),
            ('3. Mã hóa & Bảo mật', 'Mọi dữ liệu trao đổi giữa thiết bị và máy chủ đều được mã hóa bằng giao thức HTTPS/TLS 1.3 và lưu trữ trong cơ sở dữ liệu an toàn tuân thủ tiêu chuẩn quốc tế.'),
            ('4. Quyền của chủ thể dữ liệu', 'Bạn có toàn quyền truy xuất, chỉnh sửa, thu hồi quyền đào tạo AI hoặc yêu cầu xóa sạch toàn bộ lịch sử giao dịch của mình.'),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              // Header Doc Card
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      isTerms ? LucideIcons.fileText : LucideIcons.shieldCheck,
                      size: 28,
                      color: AppColors.primaryAction(context),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.h2(context).copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phiên bản 2.1 • Cập nhật lần cuối: 15/10/2026',
                            style: AppTypography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Table of Contents Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(sections[i].$1.split('.')[0] + '.' + sections[i].$1.split('.')[1]),
                          selected: _activeSection == i,
                          onSelected: (_) => setState(() => _activeSection = i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content Sections in Glass Cards
              for (var i = 0; i < sections.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ZenvestSurfaceSheet(
                    showDragHandle: false,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sections[i].$1,
                          style: AppTypography.h2(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAction(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          sections[i].$2,
                          style: AppTypography.body(context).copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary(context),
                          ),
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
