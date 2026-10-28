import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/speech_service.dart';
import '../../fixtures/fakes.dart';

void main() {
  test('speechServiceProvider có thể thay bằng bản giả và dùng được qua interface', () async {
    final fake = FakeSpeechService(updates: [const SpeechUpdate('xin'), const SpeechUpdate('xin chào', isFinal: true)]);
    final container = ProviderContainer(overrides: [speechServiceProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);
    final service = container.read(speechServiceProvider);

    expect(await service.initialize(), SpeechAvailability.available);
    final updates = await service.listen().toList();
    await service.stop();

    expect(updates.map((u) => u.text), ['xin', 'xin chào']);
    expect(updates.last.isFinal, isTrue);
    expect(updates.first.isFinal, isFalse);
    expect(fake.lastLocale, 'vi_VN');
    expect(fake.stopCalls, 1);
  });

  test('SpeechAvailability phân biệt bị từ chối quyền và thiết bị không hỗ trợ', () {
    expect(SpeechAvailability.values, containsAll([SpeechAvailability.available, SpeechAvailability.denied, SpeechAvailability.unsupported]));
  });

  test('receiptImageSourceProvider có thể thay bằng bản giả: đường dẫn, hủy chọn và lỗi quyền', () async {
    final fake = FakeImageSource(cameraPath: '/tmp/a.jpg');
    final container = ProviderContainer(overrides: [receiptImageSourceProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);
    final source = container.read(receiptImageSourceProvider);

    expect(await source.pickFromCamera(), '/tmp/a.jpg');
    expect(await source.pickFromGallery(), isNull); // người dùng hủy chọn

    fake.error = const ImageSourceException('Cần quyền camera');
    await expectLater(source.pickFromCamera(), throwsA(isA<ImageSourceException>().having((e) => e.message, 'message', 'Cần quyền camera')));
  });

  test('ImagePickerSource.scanBill trên Android dùng bộ quét tự động: trả ảnh đã cắt, hoặc null khi người dùng thoát', () async {
    expect(await ImagePickerSource(useScanner: true, scanDocument: () async => '/tmp/cropped.jpg').scanBill(), '/tmp/cropped.jpg');
    expect(await ImagePickerSource(useScanner: true, scanDocument: () async => null).scanBill(), isNull); // thoát thì không mở camera thường
  });

  test('ImagePickerSource.pickFromCamera (nút "Chụp ảnh") không bao giờ mở bộ quét tự động', () async {
    var scannerOpened = 0;
    final source = ImagePickerSource(useScanner: true, scanDocument: () async {
      scannerOpened++;
      return '/tmp/cropped.jpg';
    });

    try {
      await source.pickFromCamera(); // trong test không có camera thật nên có thể ném; chỉ cần biết bộ quét không được gọi
    } catch (_) {}

    expect(scannerOpened, 0);
  });

  test('ảnh chọn từ thư viện/camera không bị thu nhỏ xuống dưới cỡ ảnh chụp màn hình điện thoại', () {
    // Thu nhỏ ảnh 2000px cao xuống 1600px làm OCR không đọc được số tiền của thông báo FPT (đo trên máy thật 2026-10-12).
    expect(receiptMaxSide, greaterThanOrEqualTo(2600), reason: 'màn hình iPhone cao 2532px, Android ~2400px');
    expect(receiptJpegQuality, greaterThanOrEqualTo(85));
  });
}
