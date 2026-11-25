/// Mã tham gia nhóm nằm trong link `https://finmate.app/join/<mã>` (QR hoặc link chia sẻ của nhóm).
/// Trả mã nếu [raw] đúng là link đó, không thì null. Chỉ nhận miền finmate.app để QR khác (vd VietQR chuyển khoản) không bị nhầm.
String? parseGroupJoinLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
  if (uri.host != 'finmate.app' && uri.host != 'www.finmate.app') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2 || segments.first != 'join') return null;
  return segments.last;
}
