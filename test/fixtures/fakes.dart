import 'dart:async';
import 'package:finmate/features/assistant/data/receipt_image_source.dart';
import 'package:finmate/features/assistant/data/speech_service.dart';
import 'package:finmate/features/assistant/data/voice_recorder.dart';

/// Nhận dạng giọng nói giả: phát lần lượt [updates] khi `listen` được gọi.
class FakeSpeechService implements SpeechService {
  SpeechAvailability availability;
  List<SpeechUpdate> updates;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  String? lastLocale;

  FakeSpeechService({this.availability = SpeechAvailability.available, this.updates = const []});

  @override
  Future<SpeechAvailability> initialize() async {
    initializeCalls++;
    return availability;
  }

  @override
  Stream<SpeechUpdate> listen({String localeId = 'vi_VN'}) {
    listenCalls++;
    lastLocale = localeId;
    return Stream.fromIterable(updates);
  }

  @override
  Future<void> stop() async => stopCalls++;
}

/// Máy ghi âm giả: `start` trả [startResult], `stop` trả [path] (null = chưa ghi gì).
class FakeVoiceRecorder implements VoiceRecorder {
  VoiceStart startResult;
  String? path;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  /// Đẩy mức âm lượng (dB) vào đây để mô phỏng người dùng đang nói
  final StreamController<double> levelController = StreamController<double>.broadcast();

  FakeVoiceRecorder({this.startResult = VoiceStart.started, this.path = 'test/fixtures/receipt_sample.png'});

  @override
  Future<VoiceStart> start() async {
    startCalls++;
    return startResult;
  }

  @override
  Stream<double> levels(Duration interval) => levelController.stream;

  @override
  Future<String?> stop() async {
    stopCalls++;
    return path;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}

/// Nguồn ảnh hóa đơn giả: trả đường dẫn cố định, `null` (người dùng hủy) hoặc ném [error].
class FakeImageSource implements ReceiptImageSource {
  String? cameraPath;
  String? galleryPath;
  String? scanPath;
  Object? error;
  int cameraCalls = 0;
  int galleryCalls = 0;
  int scanCalls = 0;

  FakeImageSource({this.cameraPath, this.galleryPath, this.scanPath, this.error});

  @override
  Future<String?> scanBill() async {
    scanCalls++;
    if (error != null) throw error!;
    return scanPath;
  }

  @override
  Future<String?> pickFromCamera() async {
    cameraCalls++;
    if (error != null) throw error!;
    return cameraPath;
  }

  @override
  Future<String?> pickFromGallery() async {
    galleryCalls++;
    if (error != null) throw error!;
    return galleryPath;
  }
}
