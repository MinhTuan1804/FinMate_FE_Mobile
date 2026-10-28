enum SpeechSignal { listening, ended, noSpeech }

/// Nhận biết người dùng đã nói xong từ mức âm lượng (dB, càng gần 0 càng to) để tự dừng ghi âm, không bắt họ bấm lại nút mic.
///
/// Nền yên tĩnh được đo trong nửa giây đầu (lấy mức thấp nhất, phòng khi người dùng nói ngay); sau đó cao hơn nền [speechMarginDb]
/// là đang nói, và im lặng (dưới nền + [silenceMarginDb]) liên tục [trailingSilence] sau khi đã nói thì là nói xong. Thời gian tính theo
/// số mẫu x [interval] nên không phụ thuộc đồng hồ máy và test được.
class SpeechEndDetector {
  final Duration interval;
  final Duration calibration;
  final Duration trailingSilence;
  final Duration noSpeechTimeout;
  final double speechMarginDb;
  final double silenceMarginDb;

  SpeechEndDetector({
    this.interval = const Duration(milliseconds: 100),
    this.calibration = const Duration(milliseconds: 500),
    this.trailingSilence = const Duration(milliseconds: 1500),
    this.noSpeechTimeout = const Duration(seconds: 8),
    this.speechMarginDb = 10,
    this.silenceMarginDb = 6,
  });

  int _samples = 0;
  int _quietRun = 0;
  double? _baseline;
  bool _heard = false;

  /// Đã nghe thấy giọng nói chưa (để phân biệt "nói xong" với "chưa ai nói")
  bool get heardSpeech => _heard;

  SpeechSignal feed(double db) {
    db = db < -70 ? -70 : db; // một số máy trả -160 khi chưa có dữ liệu
    _samples++;
    final elapsed = interval * _samples;
    if (elapsed <= calibration) {
      _baseline = _baseline == null || db < _baseline! ? db : _baseline;
      return SpeechSignal.listening;
    }
    final baseline = _baseline!;
    if (db > baseline + speechMarginDb) {
      _heard = true;
      _quietRun = 0;
    } else if (db > baseline + silenceMarginDb) {
      _quietRun = 0; // vẫn đang nói nhỏ dần: chưa tính là im lặng
    } else {
      _quietRun++;
    }
    if (_heard && interval * _quietRun >= trailingSilence) return SpeechSignal.ended;
    if (!_heard && elapsed >= noSpeechTimeout) return SpeechSignal.noSpeech;
    return SpeechSignal.listening;
  }
}
