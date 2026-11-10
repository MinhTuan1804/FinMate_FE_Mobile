import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Ảnh đã chọn: đường dẫn tệp thật trên máy + tên tệp gốc (gửi kèm multipart).
class PickedImage {
  final String path;
  final String name;

  const PickedImage({required this.path, required this.name});
}

/// Tách riêng để màn hình test gửi được bằng Fake — theo đúng pattern `ReceiptImageSource`
/// (assistant/data/receipt_image_source.dart): gọi trực tiếp `ImagePicker()` trong widget sẽ
/// không override được trong widget test.
abstract class SupportImageSource {
  Future<PickedImage?> pickFromGallery();
}

class ImagePickerSupportSource implements SupportImageSource {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PickedImage?> pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return null;
    return PickedImage(path: file.path, name: file.name);
  }
}

final supportImageSourceProvider = Provider<SupportImageSource>((ref) => ImagePickerSupportSource());
