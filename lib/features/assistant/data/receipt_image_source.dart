import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Cạnh dài tối đa của ảnh gửi đi. Đừng hạ xuống ~1600: ảnh chụp màn hình cao 2000px bị thu nhỏ làm OCR không đọc được số tiền
/// (thông báo FPT Telecom, đo trên máy thật 2026-10-12); ảnh nhỏ hơn mức này được giữ nguyên. Backend nhận tối đa 5MB.
const receiptMaxSide = 3000.0;
const receiptJpegQuality = 85;

/// Không lấy được ảnh (ví dụ bị từ chối quyền camera/thư viện); [message] hiển thị được cho người dùng
class ImageSourceException implements Exception {
  final String message;

  const ImageSourceException(this.message);

  @override
  String toString() => message;
}

/// Lấy ảnh hóa đơn từ camera/thư viện; trả đường dẫn tệp hoặc null nếu người dùng hủy
abstract class ReceiptImageSource {
  /// "Quét bill": bộ quét tự động (tự dò viền, cắt, nắn thẳng) trên Android, camera thường nếu máy không có
  Future<String?> scanBill();

  /// "Chụp ảnh": chỉ mở camera thường, không cắt gì
  Future<String?> pickFromCamera();
  Future<String?> pickFromGallery();
}

/// Bộ quét tài liệu ML Kit: tự dò viền giấy, chụp, cắt, nắn thẳng và làm sạch ảnh ngay trên máy; trả đường dẫn tệp hoặc null nếu người dùng thoát.
Future<String?> scanWithMlKit() async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.filter,
      pageLimit: 1,
      isGalleryImport: true, // chọn ảnh có sẵn vẫn được cắt/nắn thẳng
    ),
  );
  try {
    final images = (await scanner.scanDocument()).images;
    return (images == null || images.isEmpty) ? null : images.first;
  } finally {
    scanner.close();
  }
}

class ImagePickerSource implements ReceiptImageSource {
  /// [scanDocument] và [useScanner] chỉ để thay trong test.
  ImagePickerSource({Future<String?> Function()? scanDocument, bool? useScanner})
      : _scanDocument = scanDocument ?? scanWithMlKit,
        _useScanner = useScanner ?? Platform.isAndroid; // ponytail: ML Kit Document Scanner chỉ có trên Android, iOS dùng camera thường

  final ImagePicker _picker = ImagePicker();
  final Future<String?> Function() _scanDocument;
  final bool _useScanner;

  Future<String?> _pick(ImageSource source, String deniedMessage) async {
    try {
      // Chỉ thu nhỏ ảnh quá lớn (ảnh camera 12MP) để dưới giới hạn 5MB; ảnh chụp màn hình giữ nguyên cỡ
      final file = await _picker.pickImage(source: source, maxWidth: receiptMaxSide, maxHeight: receiptMaxSide, imageQuality: receiptJpegQuality);
      return file?.path;
    } on PlatformException {
      throw ImageSourceException(deniedMessage);
    }
  }

  @override
  Future<String?> scanBill() async {
    if (_useScanner) {
      try {
        return await _scanDocument();
      } catch (_) {
        // Máy không có Google Play Services hoặc bộ quét lỗi: quay về camera thường để vẫn quét được hóa đơn.
      }
    }
    return pickFromCamera();
  }

  @override
  Future<String?> pickFromCamera() => _pick(ImageSource.camera, 'Cần quyền camera để chụp hóa đơn. Hãy bật quyền trong Cài đặt.');

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery, 'Cần quyền truy cập ảnh để chọn hóa đơn. Hãy bật quyền trong Cài đặt.');
}

final receiptImageSourceProvider = Provider<ReceiptImageSource>((ref) => ImagePickerSource());
