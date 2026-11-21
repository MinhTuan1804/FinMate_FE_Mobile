import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fakes.dart';

void main() {
  group('clampPicked', () {
    test('7 đường dẫn chỉ giữ 5 đầu tiên', () {
      final paths = List.generate(7, (i) => 'a$i.jpg');
      expect(clampPicked(paths), paths.take(receiptMaxPerPick).toList());
      expect(receiptMaxPerPick, 5);
    });

    test('danh sách rỗng trả về rỗng', () {
      expect(clampPicked(const []), isEmpty);
    });
  });

  group('FakeImageSource.pickMultipleFromGallery', () {
    test('trả galleryPaths và đếm số lần gọi', () async {
      final source = FakeImageSource(galleryPaths: ['a.jpg', 'b.jpg']);
      expect(await source.pickMultipleFromGallery(), ['a.jpg', 'b.jpg']);
      expect(source.multiCalls, 1);
    });

    test('ném error nếu có', () async {
      final source = FakeImageSource(error: const ImageSourceException('x'));
      expect(source.pickMultipleFromGallery(), throwsA(isA<ImageSourceException>()));
    });
  });
}
