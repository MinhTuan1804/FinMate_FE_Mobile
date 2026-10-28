/// Hai thứ người dùng phải đồng ý. Chữ trên màn hình và số phiên bản dưới đây đi cùng nhau: sửa câu chữ màn nào thì tăng
/// số của màn đó ở đây VÀ ở `ConsentVersions` của server; server từ chối (409) phiên bản không khớp, nên app cũ không thể
/// "đồng ý" thay cho câu chữ mới.
enum ConsentKind { terms, ai, training }

class ConsentVersions {
  const ConsentVersions._();

  /// Điều khoản sử dụng + Chính sách quyền riêng tư. Bản 2: nêu rõ việc gửi tên món cho dịch vụ AI, nên đồng ý điều khoản cũng bật phân loại bằng AI
  /// (không còn màn hỏi riêng; tắt được trong Hồ sơ). Đồng ý đóng góp dữ liệu huấn luyện vẫn là lựa chọn riêng.
  /// Bản 3: thêm đọc thông báo từ app ngân hàng/ví và đăng nhập Google, để MỘT lần đồng ý bao trùm toàn bộ (không tách điều khoản).
  static const terms = 3;

  /// Công tắc phân loại bằng AI trong Hồ sơ (bật lại sau khi tắt). Gửi tên món trên hóa đơn và cụm sản phẩm trong tin nhắn/giọng nói (đã bỏ số tiền) cho Google Gemini (dự phòng: OpenRouter) để phân loại.
  /// Bản 2: thêm OpenRouter. Bản 3: thêm chat và giọng nói
  static const ai = 3;

  /// Đóng góp chữ hóa đơn đã ẩn thông tin cá nhân + danh mục cuối cùng để cải thiện phân loại
  static const training = 1;

  static int of(ConsentKind kind) => switch (kind) {
        ConsentKind.terms => terms,
        ConsentKind.ai => ai,
        ConsentKind.training => training,
      };
}
