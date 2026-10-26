package io.fishjam.client.foregroundservice

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.PluginRegistry

/**
 * Asks for POST_NOTIFICATIONS (Android 13+) once per process. A refusal only hides the
 * foreground service notification, so [request] always calls back.
 */
class NotificationPermission : PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null
    private var asked = false
    private val pending = mutableListOf<() -> Unit>()

    fun request(context: Context, onDone: () -> Unit) {
        val activity = activity
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            onDone()
            return
        }
        if (asked || activity == null) {
            Log.w(TAG, "Notifications permission not granted; the call notification is hidden")
            onDone()
            return
        }
        pending += onDone
        if (pending.size == 1) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        asked = true
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Notifications permission refused; the call notification is hidden")
        }
        flush()
        return true
    }

    /** Runs waiting callbacks, e.g. when the activity goes away before the user answers. */
    fun flush() {
        val callbacks = pending.toList()
        pending.clear()
        callbacks.forEach { it() }
    }

    companion object {
        private const val TAG = "FishjamForegroundService"
        private const val REQUEST_CODE = 0x464A
    }
}
