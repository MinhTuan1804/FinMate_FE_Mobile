package com.example.finmate.notifications

sealed interface AnalyzeOutcome {
    object Success : AnalyzeOutcome
    object Unauthorized : AnalyzeOutcome
    object Retryable : AnalyzeOutcome     // 5xx, 429
    object Rejected : AnalyzeOutcome      // 4xx khác
    object NetworkError : AnalyzeOutcome
}

fun interface AnalyzeHttp {
    fun post(baseUrl: String, accessToken: String, item: QueuedNotification): AnalyzeOutcome
}

/** Xả hàng đợi lên backend, cũ nhất trước. Không log nội dung thông báo hay token. */
class NotificationSender(
    private val queue: NotificationQueue,
    private val store: SessionStore,
    private val refresher: TokenRefresher,
    private val http: AnalyzeHttp,
    private val maxAttempts: Int = 5,
) {
    private fun stillQueued(id: String) = queue.all().any { it.id == id }

    @Synchronized
    fun drain() {
        for (item in queue.all()) {
            // Đọc lại mỗi vòng: token có thể vừa được xoay hoặc phiên vừa bị xóa.
            val baseUrl = store.baseUrl ?: return
            val token = store.accessToken ?: return
            // Kiểm tra SAU khi đọc token: đăng xuất xóa hàng đợi trước khi tài khoản mới có token, nên mục đã bị xóa
            // (đăng xuất/đổi tài khoản giữa lúc đang xả) không bao giờ được gửi bằng token của phiên khác.
            if (!stillQueued(item.id)) continue

            var outcome = http.post(baseUrl, token, item)
            if (outcome == AnalyzeOutcome.Unauthorized) {
                when (val r = refresher.refresh(token)) {
                    is RefreshResult.Ok -> {
                        // refresh có thể trả token của phiên mới (token đã đổi); mục đã bị xóa thì không gửi lại.
                        if (!stillQueued(item.id)) continue
                        outcome = http.post(baseUrl, r.accessToken, item)
                        // Vẫn 401 sau khi làm mới: tính như lỗi tạm thời để không lặp vô hạn.
                        if (outcome == AnalyzeOutcome.Unauthorized) outcome = AnalyzeOutcome.Retryable
                    }
                    // Phiên hết hạn: xóa hết để thông báo của tài khoản này không bị gửi sang tài khoản đăng nhập sau.
                    RefreshResult.Expired -> { queue.clear(); return }
                    RefreshResult.Network -> return
                }
            }

            when (outcome) {
                AnalyzeOutcome.Success, AnalyzeOutcome.Rejected -> queue.remove(item.id)
                AnalyzeOutcome.Retryable ->
                    if (queue.incrementAttempts(item.id) >= maxAttempts) queue.remove(item.id)
                AnalyzeOutcome.NetworkError -> return
                AnalyzeOutcome.Unauthorized -> Unit // không xảy ra: đã xử lý ở trên
            }
        }
    }
}
