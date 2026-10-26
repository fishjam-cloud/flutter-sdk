package io.fishjam.client.foregroundservice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log

/** Keeps the requested service state and starts, updates or stops [FishjamForegroundService]. */
object ForegroundServiceController {
    private const val TAG = "FishjamForegroundService"

    private var cameraRequested = false
    private var microphoneRequested = false
    private var screenSharingRequested = false

    private var channelId = "com.fishjam.foregroundservice.channel"
    private var channelName = "Fishjam Notifications"
    private var notificationTitle = "Your call is ongoing"
    private var notificationContent = "Tap to return to the call."
    private var importance = "high"
    private var onlyAlertOnce = false

    @Synchronized
    fun start(context: Context, config: Map<*, *>) {
        cameraRequested = config["enableCamera"] as? Boolean ?: false
        microphoneRequested = config["enableMicrophone"] as? Boolean ?: false
        screenSharingRequested = config["enableScreenSharing"] as? Boolean ?: false
        (config["channelId"] as? String)?.let { channelId = it }
        (config["channelName"] as? String)?.let { channelName = it }
        (config["notificationTitle"] as? String)?.let { notificationTitle = it }
        (config["notificationContent"] as? String)?.let { notificationContent = it }
        (config["importance"] as? String)?.let { importance = it }
        onlyAlertOnce = config["onlyAlertOnce"] as? Boolean ?: false
        applyState(context)
    }

    @Synchronized
    fun stop(context: Context) {
        cameraRequested = false
        microphoneRequested = false
        screenSharingRequested = false
        applyState(context)
    }

    private fun applyState(context: Context) {
        val intent = Intent(context, FishjamForegroundService::class.java)
        val types = serviceTypes(context)
        if (types.isEmpty()) {
            context.stopService(intent)
            return
        }

        intent.putExtra(FishjamForegroundService.EXTRA_CHANNEL_ID, channelId)
            .putExtra(FishjamForegroundService.EXTRA_CHANNEL_NAME, channelName)
            .putExtra(FishjamForegroundService.EXTRA_TITLE, notificationTitle)
            .putExtra(FishjamForegroundService.EXTRA_CONTENT, notificationContent)
            .putExtra(FishjamForegroundService.EXTRA_IMPORTANCE, importance)
            .putExtra(FishjamForegroundService.EXTRA_ONLY_ALERT_ONCE, onlyAlertOnce)
            .putExtra(FishjamForegroundService.EXTRA_TYPES, types.toIntArray())

        try {
            val component = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            if (component == null) {
                Log.e(
                    TAG,
                    "${FishjamForegroundService::class.java.name} is not declared in AndroidManifest.xml",
                )
            }
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to start the foreground service", e)
        }
    }

    private fun serviceTypes(context: Context): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Service types do not exist yet; any non-empty list starts the service.
            return if (cameraRequested || microphoneRequested || screenSharingRequested) listOf(0) else emptyList()
        }
        return buildList {
            if (cameraRequested && isGranted(context, Manifest.permission.CAMERA)) {
                add(ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
            }
            if (microphoneRequested && isGranted(context, Manifest.permission.RECORD_AUDIO)) {
                add(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            }
            if (screenSharingRequested) {
                add(ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            }
        }
    }

    private fun isGranted(context: Context, permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}
