package com.finmate.app.notifications

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

/** Quyền Notification Access của FinMate có đang bật không (dùng chung cho channel Flutter và báo trạng thái listener). */
fun isNotificationAccessEnabled(context: Context): Boolean {
    val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: return false
    val self = ComponentName(context, NotificationCaptureService::class.java)
    return flat.split(':').any { ComponentName.unflattenFromString(it) == self }
}
