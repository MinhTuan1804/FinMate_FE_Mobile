import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';

enum LegalDocType { terms, privacy }

typedef _Section = ({String title, String body});

const _termsSections = <_Section>[
  (title: 'Giới thiệu', body: 'FinMate là ứng dụng đồng hành quản lý tài chính cá nhân thông minh. Khi đăng ký và sử dụng dịch vụ, bạn đồng ý tuân thủ các điều khoản được nêu tại đây.'),
  (title: 'Quyền & Nghĩa vụ', body: 'Người dùng có nghĩa vụ bảo vệ tài khoản của mình. FinMate cam kết cung cấp dịch vụ quản lý thu chi, ngân sách và phân tích chi tiêu chính xác theo dữ liệu bạn nhập.'),
  (title: 'Dịch vụ AI & Phân tích', body: 'Các khuyến nghị tài chính từ AI mang tính chất tham khảo, hỗ trợ ra quyết định cá nhân. FinMate không chịu trách nhiệm pháp lý đối với các quyết định đầu tư sinh lời của người dùng.'),
  (title: 'Chấm dứt dịch vụ', body: 'Bạn có quyền xuất toàn bộ dữ liệu và yêu cầu xóa vĩnh viễn tài khoản bất kỳ lúc nào thông qua phần Cài đặt của ứng dụng.'),
];

const _privacySections = <_Section>[
  (title: 'Cam kết Zero-Credential', body: 'FinMate tuân thủ nguyên tắc Zero-Credential. Chúng tôi KHÔNG BAO GIỜ yêu cầu hay lưu trữ mật khẩu đăng nhập tài khoản ngân hàng hoặc mã OTP ngân hàng của bạn.'),
  (title: 'Dữ liệu thu thập', body: 'Chúng tôi chỉ lưu trữ các thông tin giao dịch, hạn mức ngân sách và mục tiêu mà bạn chủ động ghi chép hoặc đồng ý quét qua hóa đơn/biến động số dư.'),
  (title: 'Mã hóa & Bảo mật', body: 'Mọi dữ liệu trao đổi giữa thiết bị và máy chủ đều được mã hóa bằng giao thức HTTPS/TLS 1.3 và lưu trữ trong cơ sở dữ liệu an toàn tuân thủ tiêu chuẩn quốc tế.'),
  (title: 'Quyền của chủ thể dữ liệu', body: 'Bạn có toàn quyền truy xuất, chỉnh sửa, thu hồi quyền đào tạo AI hoặc yêu cầu xóa sạch toàn bộ lịch sử giao dịch của mình.'),
];

/// Màn H9 & H10: Điều khoản dịch vụ / Chính sách bảo mật (theo Figma, dùng chung một mẫu đọc văn bản).
/// Số phiên bản lấy từ [ConsentVersions.terms] (điều khoản và chính sách dùng chung một số). BE chưa có API trả nội dung pháp lý
/// nên nội dung vẫn là văn bản tĩnh trong app; ngày cập nhật, tải PDF và email pháp lý trong Figma không có dữ liệu nên không hiển thị.
class LegalDocumentScreen extends ConsumerStatefulWidget {
  final LegalDocType type;

  const LegalDocumentScreen({super.key, required this.type});

  @override
  ConsumerState<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  String _query = '';
  late final List<GlobalKey> _keys = List.generate(_sections.length, (_) => GlobalKey());

  bool get _isTerms => widget.type == LegalDocType.terms;
  List<_Section> get _sections => _isTerms ? _termsSections : _privacySections;

  bool _matches(_Section s) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || s.title.toLowerCase().contains(q) || s.body.toLowerCase().contains(q);
  }

  void _jumpTo(int index) {
    final ctx = _keys[index].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isTerms ? 'Điều khoản dịch vụ' : 'Chính sách bảo mật';
    final sections = _sections;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            Text('Phiên bản ${ConsentVersions.terms}', style: AppTypography.caption(context).copyWith(fontSize: 11)),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
      ),
      body: AmbientGlassBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              key: const ValueKey('legal-search'),
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _isTerms ? 'Tìm kiếm trong điều khoản...' : 'Tìm kiếm trong chính sách...',
                prefixIcon: const Icon(LucideIcons.search, size: 16),
                filled: true,
                fillColor: AppColors.inset(context, 0.55),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
                enabledBorder: OutlineInputBorder(borderRadius: AppSpacing.roundedPill, borderSide: BorderSide(color: AppColors.insetBorder(context))),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: ValueKey('legal-chip-$i'),
                        label: Text('${i + 1}. ${sections[i].title}'),
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.chipFill(context),
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context)),
                        onPressed: () => _jumpTo(i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LiquidGlassCard(
              variant: LiquidGlassVariant.subtle,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.slateOn(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cam kết rõ ràng & minh bạch', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          'FinMate không lưu mật khẩu ngân hàng hay mã OTP của bạn, và chỉ gửi dữ liệu cho AI khi bạn đồng ý.',
                          style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!sections.any(_matches))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Không tìm thấy mục phù hợp.', textAlign: TextAlign.center, style: AppTypography.body(context)),
              ),
            for (var i = 0; i < sections.length; i++)
              if (_matches(sections[i]))
                Padding(
                  key: _keys[i],
                  padding: const EdgeInsets.only(bottom: 14),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
                          child: Text(
                            'MỤC ${(i + 1).toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.slateOn(context), letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('${i + 1}. ${sections[i].title}', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          sections[i].body,
                          style: AppTypography.body(context).copyWith(fontSize: 14, height: 1.5, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
