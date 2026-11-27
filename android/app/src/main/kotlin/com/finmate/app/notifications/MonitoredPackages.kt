package com.finmate.app.notifications

import android.content.Context

/** Danh sách package cần theo dõi do Flutter đẩy xuống; không nhạy cảm nên dùng SharedPreferences thường. */
class MonitoredPackages(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("finmate_monitored_packages", Context.MODE_PRIVATE)

    fun set(list: List<String>) {
        prefs.edit().putStringSet(KEY, list.toSet()).apply()
    }

    fun contains(pkg: String): Boolean = prefs.getStringSet(KEY, null)?.contains(pkg) == true

    /** Các gói người dùng đã chọn theo dõi (để báo trạng thái listener; chỉ các gói này, không bao giờ app khác). */
    fun all(): List<String> = prefs.getStringSet(KEY, null)?.sorted().orEmpty()

    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private companion object {
        const val KEY = "packages"
    }
}
