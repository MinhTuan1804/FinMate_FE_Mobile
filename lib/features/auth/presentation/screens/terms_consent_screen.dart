import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/widgets/consent_form.dart';

/// Bắt buộc với mọi tài khoản trước khi vào app. Ghi xong thì hồ sơ đổi và router tự đưa người dùng đi tiếp.
/// Đổi câu chữ ở đây thì tăng [ConsentVersions.terms] (và bản bên server).
class TermsConsentScreen extends ConsumerWidget {
  const TermsConsentScreen({super.key});

  Widget _bullet(BuildContext context, String label, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: '•  '),
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text),
          ]),
          style: AppTypography.body(context),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ConsentForm(
        title: 'Trước khi bắt đầu',
        content: [
          Text(
            'FinMate giúp bạn ghi chép và theo dõi chi tiêu. Để làm được việc đó, chúng tôi xử lý các dữ liệu sau:',
            style: AppTypography.body(context),
          ),
          const SizedBox(height: 12),
          _bullet(context, 'Tài khoản', 'email và thông tin đăng nhập, lưu trên máy chủ của FinMate.'),
          _bullet(
            context,
            'Dữ liệu tài chính của bạn (giao dịch, ví, ngân sách, mục tiêu tiết kiệm)',
            'lưu trên điện thoại của bạn và được đồng bộ lên máy chủ của FinMate để sao lưu, khôi phục khi bạn đổi máy.',
          ),
          _bullet(
            context,
            'Hóa đơn và giọng nói bạn gửi',
            'chỉ dùng để nhận diện nội dung rồi tạo giao dịch, ảnh và bản ghi âm không được lưu lại.',
          ),
          _bullet(
            context,
            'Phân loại chi tiêu bằng AI',
            'để xếp từng món vào đúng danh mục, FinMate gửi tên món trên hóa đơn và cụm sản phẩm trong tin nhắn, giọng nói (đã bỏ số tiền) cho dịch vụ AI '
                'của bên thứ ba: Google Gemini, hoặc OpenRouter và nhà cung cấp mô hình mà OpenRouter chọn khi Gemini quá tải. Họ xử lý theo chính sách riêng của họ. '
                'FinMate không tự bỏ được tên người hay cửa hàng nếu bạn nhắc trong câu.',
          ),
          _bullet(
            context,
            'Thông báo từ ứng dụng ngân hàng và ví điện tử',
            'khi bạn bật tự động ghi nhận, FinMate chỉ đọc thông báo biến động số dư của các ứng dụng bạn chủ động chọn để tạo giao dịch. '
                'FinMate không bao giờ hỏi mật khẩu hay mã OTP của ngân hàng.',
          ),
          _bullet(
            context,
            'Đăng nhập bằng Google',
            'nếu bạn chọn, Google cung cấp cho FinMate email và tên hiển thị của bạn theo chính sách của Google.',
          ),
          _bullet(
            context,
            'Không gửi',
            'giá tiền, tổng hóa đơn, ảnh hóa đơn, âm thanh giọng nói, thông tin tài khoản hay danh tính của bạn; khoản thu nhập, chuyển tiền và chi cho người khác '
                'cũng không được gửi. Thuốc và đồ y tế không bao giờ được gửi.',
          ),
          Text(
            'Kết quả phân loại của từng tên món được nhớ trên máy chủ FinMate, không gắn với tài khoản của bạn, để các lần sau không phải hỏi lại. '
            'Bạn có thể tắt phân loại bằng AI bất cứ lúc nào trong Cá nhân; khi tắt, FinMate vẫn dùng bình thường và chỉ phân loại bằng quy tắc có sẵn.',
            style: AppTypography.body(context),
          ),
          const SizedBox(height: 12),
          Text(
            'Chúng tôi không bán dữ liệu của bạn và không dùng nó để quảng cáo. '
            'Bạn có quyền xem, sửa và xóa dữ liệu của mình, kể cả xóa tài khoản.',
            style: AppTypography.body(context),
          ),
        ],
        checkboxLabel: 'Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư, gồm cả việc gửi tên món cho dịch vụ AI để phân loại, đọc thông báo từ ứng dụng ngân hàng/ví bạn chọn và đăng nhập bằng Google',
        acceptLabel: 'Tiếp tục',
        onAccept: () => ref.read(authControllerProvider.notifier).acceptConsent(ConsentKind.terms),
      ),
    );
  }
}
