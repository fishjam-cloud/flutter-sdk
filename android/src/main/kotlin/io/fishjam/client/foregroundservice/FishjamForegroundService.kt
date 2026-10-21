package io.fishjam.client.foregroundservice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Foreground service that keeps the app process, and so the call, running while the app is in the
 * background. The app declares it in its AndroidManifest.xml.
 */
class FishjamForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            startInForeground(intent)
        }
        return START_NOT_STICKY
    }

    private fun startInForeground(intent: Intent) {
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: return
        val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: return
        val importance = intent.getStringExtra(EXTRA_IMPORTANCE) ?: "high"
        val types = intent.getIntArrayExtra(EXTRA_TYPES)?.fold(0) { acc, type -> acc or type } ?: 0

        createChannel(channelId, channelName, importance)
        val notification = buildNotification(
            channelId,
            intent.getStringExtra(EXTRA_TITLE),
            intent.getStringExtra(EXTRA_CONTENT),
            importance,
            intent.getBooleanExtra(EXTRA_ONLY_ALERT_ONCE, false),
        )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification)
            return
        }
        try {
            startForeground(NOTIFICATION_ID, notification, types)
        } catch (e: SecurityException) {
            // Android 14+ refuses mediaProjection before the user consents to screen capture.
            // A service that never reaches the foreground crashes the app, so retry without it.
            val withoutProjection = types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION.inv()
            Log.w(TAG, "Could not start with types $types, retrying with $withoutProjection", e)
            startForeground(NOTIFICATION_ID, notification, withoutProjection)
        }
    }

    private fun buildNotification(
        channelId: String,
        title: String?,
        content: String?,
        importance: String,
        onlyAlertOnce: Boolean,
    ): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(
                if (importance == "low") Notification.PRIORITY_LOW else Notification.PRIORITY_HIGH,
            )
        }
        return builder
            .setContentTitle(title)
            .setContentText(content)
            .setContentIntent(contentIntent)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOnlyAlertOnce(onlyAlertOnce)
            .setOngoing(true)
            .build()
    }

    private fun createChannel(channelId: String, channelName: String, importance: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val level = if (importance == "low") {
            NotificationManager.IMPORTANCE_LOW
        } else {
            NotificationManager.IMPORTANCE_HIGH
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(NotificationChannel(channelId, channelName, level))
    }

    companion object {
        private const val TAG = "FishjamForegroundService"
        private const val NOTIFICATION_ID = 0x46_4A_46_53

        const val EXTRA_CHANNEL_ID = "channelId"
        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_TITLE = "notificationTitle"
        const val EXTRA_CONTENT = "notificationContent"
        const val EXTRA_IMPORTANCE = "importance"
        const val EXTRA_ONLY_ALERT_ONCE = "onlyAlertOnce"
        const val EXTRA_TYPES = "foregroundServiceTypes"
    }
}
