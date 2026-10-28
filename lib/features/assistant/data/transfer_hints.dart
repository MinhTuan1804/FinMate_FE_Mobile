import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/assistant/data/local_chat_decider.dart' show memoryKey;

/// Ví nguồn và ví đích mà CÂU NÓI của người dùng đã chỉ ra ("chuyển sang tiết kiệm", "rút từ tiết kiệm về ví"); null là chưa rõ.
class TransferHints {
  final String? fromId;
  final String? toId;
  const TransferHints({this.fromId, this.toId});
}

const _none = TransferHints();

// Đã bỏ dấu (xem memoryKey). "cho" cố ý không có: "chuyển cho mẹ" là người, không phải ví.
const _destinationMarkers = {'sang', 'qua', 'vao', 've', 'den', 'toi'};
const _sourceMarker = 'tu';
const _generic = {'tai', 'khoan', 'tk', 'quy', 'the'}; // "tài khoản tiết kiệm", "quỹ tiết kiệm": phần đệm, không phải tên
const _walletWord = 'vi';

/// Đọc hướng chuyển từ mô tả của thẻ chuyển tiền. Chỉ nhận khi KHỚP RÕ RÀNG đúng một tài khoản: tên lạ, hai tài khoản khớp ngang nhau, hoặc nguồn trùng đích
/// thì bỏ qua (màn hình lại chọn như cũ). Không bao giờ đoán.
TransferHints transferAccountHints(String? text, List<FinancialAccount> accounts) {
  if (accounts.isEmpty) return _none;
  final words = memoryKey(text).split(' ').where((w) => w.isNotEmpty).toList();

  // Mỗi từ chỉ hướng mở một cụm; cụm kết thúc ở từ chỉ hướng kế tiếp. Chỉ lấy cụm đầu tiên của mỗi vai.
  List<String>? source;
  List<String>? destination;
  List<String>? current;
  for (final word in words) {
    if (word == _sourceMarker) {
      current = source == null ? (source = []) : null;
    } else if (_destinationMarkers.contains(word)) {
      current = destination == null ? (destination = []) : null;
    } else {
      current?.add(word);
    }
  }

  final from = source == null ? null : _match(source, accounts);
  final to = destination == null ? null : _match(destination, accounts);
  if (from != null && from == to) return _none;
  return TransferHints(fromId: from, toId: to);
}

/// Bỏ từ đệm; cụm có từ khác ngoài "ví" thì bỏ luôn "ví" ("ví momo" là MoMo, không phải ví tiền mặt tên "Ví")
Set<String> _core(Iterable<String> tokens) {
  final kept = tokens.where((w) => w.isNotEmpty && !_generic.contains(w)).toList();
  return (kept.length > 1 ? kept.where((w) => w != _walletWord) : kept).toSet();
}

String? _match(List<String> phraseWords, List<FinancialAccount> accounts) {
  final phrase = _core(phraseWords);
  if (phrase.isEmpty) return null;

  var best = 0;
  String? bestId;
  var tied = false;
  for (final account in accounts) {
    var score = 0;
    for (final name in [account.name, account.providerName]) {
      if (name == null) continue;
      final tokens = _core(memoryKey(name).split(' '));
      // Câu nói là một phần của tên (hoặc bằng tên); tên ngắn hơn câu nói thì không nhận ("ngân hàng xyz" không phải tài khoản "Ngân hàng")
      if (tokens.isEmpty || !tokens.containsAll(phrase)) continue;
      final exact = tokens.length == phrase.length ? 1 : 0;
      final candidate = phrase.length * 2 + exact;
      if (candidate > score) score = candidate;
    }
    if (score == 0) continue;
    if (score > best) {
      best = score;
      bestId = account.id;
      tied = false;
    } else if (score == best) {
      tied = true;
    }
  }
  return tied ? null : bestId;
}
