package com.example.finmate.notifications

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/** Nguồn sự thật duy nhất của phiên đăng nhập; token được mã hóa bằng Android Keystore. */
class EncryptedSessionStore(context: Context) : SessionStore {
    private val prefs: SharedPreferences = open(context.applicationContext)

    override var baseUrl: String?
        get() = prefs.getString(K_BASE_URL, null)
        set(v) = put(K_BASE_URL, v)

    override var accessToken: String?
        get() = prefs.getString(K_ACCESS, null)
        set(v) = put(K_ACCESS, v)

    override var refreshToken: String?
        get() = prefs.getString(K_REFRESH, null)
        set(v) = put(K_REFRESH, v)

    override var sessionExpired: Boolean
        get() = prefs.getBoolean(K_EXPIRED, false)
        set(v) { prefs.edit().putBoolean(K_EXPIRED, v).commit() }

    override fun clearTokens() {
        prefs.edit().remove(K_ACCESS).remove(K_REFRESH).commit()
    }

    // Một lần edit() cho cả hai khóa: không bao giờ lưu được access mới mà refresh vẫn là bản đã bị xoay.
    // commit() (đồng bộ, ghi đĩa xong mới trả về) thay vì apply(): nếu tiến trình bị kill trước khi ghi đĩa thì sẽ nạp lại
    // refresh token cũ đã bị xoay, lần refresh sau BE thu hồi cả phiên. Mọi nơi gọi đều đã ở luồng nền.
    override fun saveTokens(accessToken: String, refreshToken: String) {
        prefs.edit().putString(K_ACCESS, accessToken).putString(K_REFRESH, refreshToken).commit()
    }

    private fun put(key: String, value: String?) {
        val e = prefs.edit()
        if (value == null) e.remove(key) else e.putString(key, value)
        e.commit()
    }

    private companion object {
        const val FILE = "finmate_notification_session"
        const val K_BASE_URL = "baseUrl"
        const val K_ACCESS = "accessToken"
        const val K_REFRESH = "refreshToken"
        const val K_EXPIRED = "sessionExpired"

        fun create(context: Context): SharedPreferences {
            val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
            return EncryptedSharedPreferences.create(
                context, FILE, key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }

        fun open(context: Context): SharedPreferences = try {
            create(context)
        } catch (e: Exception) {
            // Keystore bị đặt lại hoặc file khôi phục từ máy khác thì không giải mã được:
            // xóa file hỏng rồi tạo lại, người dùng sẽ phải đăng nhập lại.
            context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().clear().commit()
            create(context)
        }
    }
}
