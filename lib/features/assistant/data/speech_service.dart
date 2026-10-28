import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechAvailability { available, denied, unsupported }

/// Một lần cập nhật chữ nhận dạng; [isFinal] là kết quả cuối của lượt nói
class SpeechUpdate {
  final String text;
  final bool isFinal;

  const SpeechUpdate(this.text, {this.isFinal = false});
}

/// Nhận dạng giọng nói trên máy; bọc plugin để test thay được bằng bản giả
abstract class SpeechService {
  Future<SpeechAvailability> initialize();

  /// Bắt đầu nghe và phát chữ nhận dạng dần; stream kết thúc khi lượt nói xong, báo lỗi nếu nhận dạng lỗi
  Stream<SpeechUpdate> listen({String localeId = 'vi_VN'});

  Future<void> stop();
}

class SpeechToTextService implements SpeechService {
  final SpeechToText _speech = SpeechToText();
  StreamController<SpeechUpdate>? _controller;

  @override
  Future<SpeechAvailability> initialize() async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _close();
      },
      onError: (error) {
        _controller?.addError(error.errorMsg);
        _close();
      },
    );
    if (ok) return SpeechAvailability.available;
    return await _speech.hasPermission ? SpeechAvailability.unsupported : SpeechAvailability.denied;
  }

  @override
  Stream<SpeechUpdate> listen({String localeId = 'vi_VN'}) {
    _close();
    final controller = StreamController<SpeechUpdate>();
    _controller = controller;
    _speech.listen(
      onResult: (result) {
        if (controller.isClosed) return;
        controller.add(SpeechUpdate(result.recognizedWords, isFinal: result.finalResult));
        if (result.finalResult) _close();
      },
      listenOptions: SpeechListenOptions(localeId: localeId, partialResults: true, cancelOnError: true),
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _close();
  }

  void _close() {
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) controller.close();
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechToTextService());
