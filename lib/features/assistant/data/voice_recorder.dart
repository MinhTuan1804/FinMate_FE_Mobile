import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum VoiceStart { started, denied, failed }

/// Ghi âm giọng nói thành tệp m4a gửi lên backend (STT chạy trên server); bọc plugin để test thay được bằng bản giả
abstract class VoiceRecorder {
  /// Xin quyền micro rồi bắt đầu ghi
  Future<VoiceStart> start();

  /// Mức âm lượng (dB, gần 0 là to) mỗi [interval] trong lúc ghi, để biết khi nào người dùng nói xong
  Stream<double> levels(Duration interval);

  /// Dừng và trả đường dẫn tệp; null nếu chưa ghi gì
  Future<String?> stop();

  /// Dừng và xóa tệp (thoát màn hình khi đang ghi)
  Future<void> cancel();
}

class RecordVoiceRecorder implements VoiceRecorder {
  // lazy: tạo kênh native khi thật sự ghi, không ngay khi màn chat mở
  late final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<VoiceStart> start() async {
    try {
      if (!await _recorder.hasPermission()) return VoiceStart.denied;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // 16 kHz mono: đúng tần số model STT dùng, tệp nhỏ (~16 KB/giây)
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 32000), path: path);
      return VoiceStart.started;
    } catch (_) {
      return VoiceStart.failed;
    }
  }

  @override
  Stream<double> levels(Duration interval) => _recorder.onAmplitudeChanged(interval).map((a) => a.current);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() async {
    final path = await _recorder.stop();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) => RecordVoiceRecorder());
