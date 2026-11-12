import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// a7 — Bắt buộc với mọi tài khoản trước khi vào app. Ghi xong thì hồ sơ đổi và router tự đưa
/// người dùng đi tiếp (xem [authRedirect]); màn này còn tự điều hướng sang /ai-consent vì đó
/// không phải là bước router tự ép đi.
/// Đổi câu chữ ở đây thì tăng [ConsentVersions.terms] (và bản bên server).
class TermsConsentScreen extends ConsumerStatefulWidget {
  const TermsConsentScreen({super.key});

  @override
  ConsumerState<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends ConsumerState<TermsConsentScreen> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).acceptConsent(ConsentKind.terms);
      if (mounted) context.go('/ai-consent');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFullText() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => GlassCard(
          level: 3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassRadius.hero)),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Điều khoản sử dụng & Chính sách quyền riêng tư', style: GlassTypography.headlineMd()),
                const SizedBox(height: 16),
                Text(
                  'FinMate giúp bạn ghi chép và theo dõi chi tiêu. Để làm được việc đó, chúng tôi xử lý các dữ liệu sau:',
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                ),
                const SizedBox(height: 12),
                _bullet('Tài khoản', 'email và thông tin đăng nhập, lưu trên máy chủ của FinMate.'),
                _bullet(
                  'Dữ liệu tài chính của bạn (giao dịch, ví, ngân sách, mục tiêu tiết kiệm)',
                  'lưu trên điện thoại của bạn và được đồng bộ lên máy chủ của FinMate để sao lưu, khôi phục khi bạn đổi máy.',
                ),
                _bullet(
                  'Hóa đơn và giọng nói bạn gửi',
                  'ảnh hóa đơn được gửi nguyên bản (chưa che dữ liệu cá nhân) tới dịch vụ Google Cloud Vision để đọc chữ; '
                      'chỉ chữ đọc được mới dùng để tạo giao dịch, ảnh gốc và bản ghi âm không được lưu lại.',
                ),
                _bullet(
                  'Phân loại chi tiêu bằng AI',
                  'để xếp từng món vào đúng danh mục, FinMate gửi tên món trên hóa đơn và cụm sản phẩm trong tin nhắn, giọng nói (đã bỏ số tiền) cho dịch vụ AI '
                      'của bên thứ ba: Google Gemini, hoặc OpenRouter và nhà cung cấp mô hình mà OpenRouter chọn khi Gemini quá tải. Họ xử lý theo chính sách riêng của họ. '
                      'FinMate không tự bỏ được tên người hay cửa hàng nếu bạn nhắc trong câu.',
                ),
                _bullet(
                  'Thông báo từ ứng dụng ngân hàng và ví điện tử',
                  'khi bạn bật tự động ghi nhận, FinMate chỉ đọc thông báo biến động số dư của các ứng dụng bạn chủ động chọn để tạo giao dịch. '
                      'FinMate không bao giờ hỏi mật khẩu hay mã OTP của ngân hàng.',
                ),
                _bullet(
                  'Đăng nhập bằng Google',
                  'nếu bạn chọn, Google cung cấp cho FinMate email và tên hiển thị của bạn theo chính sách của Google.',
                ),
                _bullet(
                  'Tài chính nhóm',
                  'giao dịch bạn chủ động chọn chia sẻ (số tiền, nơi chi, ghi chú, tên họ của bạn) hiện được với các thành viên khác trong nhóm, '
                      'và vẫn còn đó với nhóm kể cả sau khi bạn rời đi.',
                ),
                _bullet(
                  'Yêu cầu hỗ trợ',
                  'ảnh bạn gửi kèm yêu cầu hỗ trợ được lưu có thời hạn; nhân viên hỗ trợ chỉ xem được dữ liệu của bạn khi bạn đồng ý cho từng yêu cầu cụ thể.',
                ),
                _bullet(
                  'Không gửi cho dịch vụ phân loại bằng AI',
                  'giá tiền, tổng hóa đơn, ảnh hóa đơn, âm thanh giọng nói, thông tin tài khoản hay danh tính của bạn; khoản thu nhập, chuyển tiền và chi cho người khác '
                      'cũng không được gửi. Thuốc và đồ y tế không bao giờ được gửi. (Ảnh hóa đơn có được gửi riêng cho dịch vụ đọc chữ Google Cloud Vision — xem mục "Hóa đơn và giọng nói bạn gửi" ở trên.)',
                ),
                const SizedBox(height: 8),
                Text(
                  'Kết quả phân loại của từng tên món được nhớ trên máy chủ FinMate, không gắn với tài khoản của bạn, để các lần sau không phải hỏi lại. '
                  'Bạn có thể tắt phân loại bằng AI bất cứ lúc nào trong Cá nhân; khi tắt, FinMate vẫn dùng bình thường và chỉ phân loại bằng quy tắc có sẵn.',
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chúng tôi không bán dữ liệu của bạn và không dùng nó để quảng cáo. '
                  'Bạn có quyền xem, sửa và xóa dữ liệu của mình, kể cả xóa tài khoản.',
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(String label, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text),
          ]),
          style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trước khi bắt đầu', style: GlassTypography.headlineLg()),
                const SizedBox(height: 8),
                Text('FinMate cam kết bảo vệ dữ liệu tài chính của bạn.', style: GlassTypography.bodyMd()),
                const SizedBox(height: 24),
                _principle(LucideIcons.shieldCheck, 'Bảo mật cấp ngân hàng', 'Dữ liệu được mã hóa và không bao giờ chia sẻ mật khẩu ngân hàng.'),
                const SizedBox(height: 14),
                _principle(LucideIcons.eyeOff, 'Không chia sẻ bên thứ ba', 'Chỉ gửi tên món (không giá tiền, không danh tính) cho dịch vụ phân loại AI.'),
                const SizedBox(height: 14),
                _principle(LucideIcons.settings2, 'Quyền kiểm soát thuộc về bạn', 'Xem, sửa, tắt tính năng AI hoặc xóa dữ liệu bất cứ lúc nào trong Cá nhân.'),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _showFullText,
                  child: Text(
                    'Xem toàn văn Điều khoản dịch vụ & Chính sách quyền riêng tư',
                    style: GlassTypography.bodyMd(color: GlassColors.slateAnchor)
                        .copyWith(fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
                      activeColor: GlassColors.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư, gồm cả việc gửi tên món cho dịch vụ AI để phân loại, '
                          'đọc thông báo từ ứng dụng ngân hàng/ví bạn chọn, đăng nhập bằng Google, chia sẻ giao dịch trong nhóm tài chính chung, '
                          'và gửi ảnh hóa đơn nguyên bản cho dịch vụ đọc chữ',
                          style: GlassTypography.bodySm(color: GlassColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger)),
                ],
                const SizedBox(height: 20),
                GlassPrimaryButton(
                  label: 'Đồng ý & Tiếp tục',
                  onPressed: _checked && !_busy ? _accept : null,
                  loading: _busy,
                ),
                const SizedBox(height: 12),
                GlassGhostButton(
                  label: 'Từ chối và thoát',
                  onPressed: _busy ? null : () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _principle(IconData icon, String title, String desc) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GlassColors.slateAnchor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GlassTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: GlassTypography.bodySm()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
