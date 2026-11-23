import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Quyền hệ thống mà app cần người dùng cấp (không gồm quyền đọc thông báo ngân hàng: phần đó có luồng riêng ở onboarding và thẻ ở màn Giao dịch).
enum AppPermission { camera, microphone }

/// [denied]: chưa hỏi hoặc mới bị từ chối, vẫn hiện được hộp xin quyền của hệ thống.
/// [blocked]: bị chặn vĩnh viễn (chọn "không hỏi lại" hoặc bị hạn chế): chỉ còn cách mở Cài đặt ứng dụng.
enum PermissionState { granted, denied, blocked }

abstract class PermissionService {
  Future<PermissionState> status(AppPermission permission);

  /// Hiện hộp xin quyền của hệ thống (nếu còn được phép) rồi trả trạng thái sau đó.
  Future<PermissionState> request(AppPermission permission);

  /// Mở trang cài đặt của ứng dụng; trả false nếu không mở được.
  Future<bool> openSettings();
}

class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  static Permission _of(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
      };

  static PermissionState _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionState.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return PermissionState.blocked;
    return PermissionState.denied;
  }

  @override
  Future<PermissionState> status(AppPermission permission) async => _map(await _of(permission).status);

  @override
  Future<PermissionState> request(AppPermission permission) async => _map(await _of(permission).request());

  @override
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>((ref) => const PermissionHandlerService());
