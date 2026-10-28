import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/speech_end_detector.dart';

/// Mỗi mẫu cách nhau 100 ms (khoảng đo của máy ghi âm). dB càng gần 0 càng to; nền yên tĩnh khoảng -50.
SpeechSignal run(SpeechEndDetector d, List<double> levels) {
  var last = SpeechSignal.listening;
  for (final db in levels) {
    last = d.feed(db);
    if (last != SpeechSignal.listening) return last;
  }
  return last;
}

List<double> quiet(int samples, [double db = -50]) => List.filled(samples, db);
List<double> loud(int samples, [double db = -20]) => List.filled(samples, db);

void main() {
  test('nói xong rồi im lặng 1,5 giây thì báo đã nói xong', () {
    final d = SpeechEndDetector();

    expect(run(d, [...quiet(5), ...loud(15), ...quiet(14)]), SpeechSignal.listening);
    expect(d.feed(-50), SpeechSignal.ended); // mẫu thứ 15 im lặng liên tiếp = 1,5 giây
  });

  test('ngắt hơi ngắn giữa chừng không bị coi là nói xong', () {
    final d = SpeechEndDetector();

    expect(run(d, [...quiet(5), ...loud(10), ...quiet(8), ...loud(10), ...quiet(5)]), SpeechSignal.listening);
    expect(d.heardSpeech, isTrue);
  });

  test('chưa ai nói gì sau 8 giây thì báo không nghe thấy', () {
    final d = SpeechEndDetector();

    expect(run(d, quiet(79)), SpeechSignal.listening);
    expect(d.feed(-50), SpeechSignal.noSpeech);
    expect(d.heardSpeech, isFalse);
  });

  test('môi trường ồn đều (nền cao) vẫn nhận ra giọng và kết thúc khi giọng tắt', () {
    final d = SpeechEndDetector();

    expect(run(d, [...quiet(5, -35), ...loud(12, -20), ...quiet(20, -35)]), SpeechSignal.ended);
  });

  test('tiếng ồn đều không bao giờ coi là giọng nói', () {
    final d = SpeechEndDetector();

    expect(run(d, quiet(80, -30)), SpeechSignal.noSpeech);
  });
}
