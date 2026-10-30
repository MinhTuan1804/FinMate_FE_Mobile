import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/qr_transfer/data/qr_transfer_repository.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';

/// Danh sách ngân hàng từ backend (mã app, BIN, có đọc được thông báo không). Không giữ bản cứng ở app: thêm ngân hàng là thêm dòng ở server.
final qrBanksProvider = FutureProvider<List<QrBank>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <QrBank>[];
  return ref.watch(qrTransferRepositoryProvider).getBanks();
});

final qrTransfersProvider = FutureProvider.autoDispose<List<QrTransfer>>((ref) {
  return ref.watch(qrTransferRepositoryProvider).getTransfers();
});

final qrOverridesProvider = FutureProvider.autoDispose<List<CounterpartyOverride>>((ref) {
  return ref.watch(qrTransferRepositoryProvider).getOverrides();
});

/// Ngân hàng GỬI người dùng chọn lần trước, để lần quét sau đặt sẵn (chỉ trong phiên chạy, không lưu ra đĩa).
final lastSenderBankBinProvider = StateProvider<String?>((ref) => null);
