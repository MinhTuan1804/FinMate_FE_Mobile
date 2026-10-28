package com.example.finmate.notifications

import android.content.Context

/** Danh sách package cần theo dõi do Flutter đẩy xuống; không nhạy cảm nên dùng SharedPreferences thường. */
class MonitoredPackages(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("finmate_monitored_packages", Context.MODE_PRIVATE)

    fun set(list: List<String>) {
        prefs.edit().putStringSet(KEY, list.toSet()).apply()
    }

    fun contains(pkg: String): Boolean = prefs.getStringSet(KEY, null)?.contains(pkg) == true

    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private companion object {
        const val KEY = "packages"
    }
}
