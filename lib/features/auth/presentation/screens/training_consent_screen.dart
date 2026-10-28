import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/widgets/consent_form.dart';

/// Gọi khi người dùng bật "Đóng góp dữ liệu để cải thiện phân loại". Đã đồng ý rồi thì trả true ngay; chưa thì hiện màn đồng ý và trả true chỉ khi họ
/// đồng ý xong ("Để sau" hoặc quay lại trả false, không ghi gì).
Future<bool> ensureTrainingConsent(BuildContext context, WidgetRef ref) async {
  if (ref.read(authControllerProvider).valueOrNull?.trainingConsentGranted ?? false) return true;
  final agreed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const TrainingConsentScreen()),
  );
  return agreed ?? false;
}

/// Đổi câu chữ ở đây thì tăng [ConsentVersions.training] (và bản bên server). Mọi câu ở đây phải đúng với hệ thống: lưu gì, không lưu gì, bao lâu, xóa thế nào.
class TrainingConsentScreen extends ConsumerWidget {
  const TrainingConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ConsentForm(
        title: 'Đóng góp dữ liệu để cải thiện phân loại',
        content: [
          Text(
            'Nếu bạn đồng ý, FinMate lưu lại chữ trên hóa đơn bạn quét (đã ẩn thông tin cá nhân) cùng danh mục cuối cùng bạn chọn, '
            'để cải thiện việc phân loại hóa đơn.',
            style: AppTypography.body(context),
          ),
          const SizedBox(height: 14),
          ConsentForm.point(
            context,
            'Dữ liệu được lưu',
            'chữ trên hóa đơn đã ẩn số điện thoại, số tài khoản, email và địa chỉ; tên cửa hàng; tổng tiền; danh mục bạn chọn cuối cùng. '
            'Tên người chỉ được ẩn khi đứng cạnh nhãn như "Khách hàng" hay "Nhân viên", nên có thể còn sót trên hóa đơn.',
          ),
          ConsentForm.point(
            context,
            'Không lưu',
            'ảnh hóa đơn, âm thanh hay thông tin đăng nhập của bạn. Dữ liệu gắn với mã của lần quét và một mã băm của tài khoản; FinMate vẫn nối được về tài khoản của bạn, và đó là cách để xóa khi bạn rút lại.',
          ),
          ConsentForm.point(
            context,
            'Chưa thu',
            'hóa đơn được tách thành nhiều nhóm và ảnh chụp danh sách đơn hàng.',
          ),
          ConsentForm.point(context, 'Lưu ở đâu', 'trên máy chủ của FinMate, không chia sẻ cho bên thứ ba.'),
          ConsentForm.point(
            context,
            'Thời gian lưu',
            'hóa đơn bạn quét nhưng không lưu thành giao dịch bị xóa sau 7 ngày; hóa đơn đã lưu được giữ để học cho tới khi bạn rút lại đồng ý hoặc xóa tài khoản.',
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn có thể rút lại bất cứ lúc nào trong Cá nhân → Quyền riêng tư; khi đó dữ liệu bạn đã đóng góp sẽ bị xóa. '
            'Không đồng ý thì mọi tính năng vẫn dùng như bình thường.',
            style: AppTypography.body(context),
          ),
        ],
        checkboxLabel: 'Tôi đồng ý đóng góp chữ hóa đơn đã ẩn thông tin cá nhân và danh mục tôi chọn để cải thiện FinMate',
        acceptLabel: 'Đồng ý và tiếp tục',
        onAccept: () async {
          await ref.read(authControllerProvider.notifier).acceptConsent(ConsentKind.training);
          if (context.mounted) Navigator.of(context).pop(true);
        },
        secondaryLabel: 'Để sau',
        onSecondary: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
