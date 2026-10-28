package com.example.finmate.notifications

import java.io.File
import org.json.JSONArray
import org.json.JSONObject

data class QueuedNotification(
    val id: String,
    val packageName: String,
    val title: String,
    val body: String,
    val receivedAtMs: Long,
    val attempts: Int = 0,
)

/** Hàng đợi bền vững (JSON một file); mọi hàm công khai đồng bộ vì service và kênh Flutter gọi từ nhiều luồng. */
class NotificationQueue(private val file: File, private val maxItems: Int = 200) {

    @Synchronized
    fun add(item: QueuedNotification) {
        // Đầy thì bỏ mục cũ nhất để mục mới không bị mất.
        write((read() + item).takeLast(maxItems))
    }

    @Synchronized
    fun all(): List<QueuedNotification> = read()

    @Synchronized
    fun remove(id: String) {
        write(read().filterNot { it.id == id })
    }

    /** Trả số lần thử mới; 0 nếu id không còn trong hàng đợi. */
    @Synchronized
    fun incrementAttempts(id: String): Int {
        var result = 0
        write(read().map {
            if (it.id == id) it.copy(attempts = it.attempts + 1).also { n -> result = n.attempts } else it
        })
        return result
    }

    @Synchronized
    fun clear() {
        write(emptyList())
    }

    // File hỏng/cắt dở (app bị kill giữa lúc ghi) thì coi như rỗng, không để service crash.
    private fun read(): List<QueuedNotification> = try {
        val arr = JSONArray(file.readText())
        (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            QueuedNotification(
                o.getString("id"), o.getString("packageName"), o.getString("title"),
                o.getString("body"), o.getLong("receivedAtMs"), o.optInt("attempts", 0),
            )
        }
    } catch (e: Exception) {
        emptyList()
    }

    // Ghi file tạm rồi đổi tên để file chính không bao giờ ở trạng thái nửa chừng.
    private fun write(items: List<QueuedNotification>) {
        val arr = JSONArray()
        items.forEach {
            arr.put(JSONObject()
                .put("id", it.id).put("packageName", it.packageName).put("title", it.title)
                .put("body", it.body).put("receivedAtMs", it.receivedAtMs).put("attempts", it.attempts))
        }
        val tmp = File(file.path + ".tmp")
        tmp.writeText(arr.toString())
        // renameTo trên Windows/JVM không ghi đè được file có sẵn, nên xóa trước; trên Android rename là atomic.
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }
}
