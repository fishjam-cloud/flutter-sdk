package io.fishjam.client

import android.annotation.TargetApi
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Lists, reads and switches the Android audio output. Port of the React Native
 * SDK's AudioOutputManager without its Telecom branch. Every method must be
 * called on the main thread; results and events are delivered there too.
 */
class AudioOutputManager(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var communicationDeviceChangedListener: Any? = null
    private var scoReceiver: BroadcastReceiver? = null
    private var isObserving = false
    private var ownsCommunicationMode = false

    // AudioFocusRequest exists from API 26. A field of that type is resolved
    // when this class loads, and minSdk is 23.
    private var focusRequest: Any? = null
    private val focusChangeListener = AudioManager.OnAudioFocusChangeListener { }

    // Single in-flight selection: a new request supersedes any prior one.
    private var pending: PendingSelect? = null

    private class PendingSelect(
        val result: Result,
        val targetDeviceId: Int,
        val targetType: Int,
        val timeoutTask: Runnable,
    )

    fun getAvailableAudioOutputs(result: Result) {
        result.success(availableDevices().map(::serialize))
    }

    fun getCurrentAudioOutput(result: Result) {
        result.success(currentDevice()?.let(::serialize))
    }

    fun selectAudioOutput(deviceIdStr: String?, result: Result) {
        val deviceId = deviceIdStr?.toIntOrNull()
        if (deviceId == null) {
            result.error(E_SELECT, "Invalid device ID: $deviceIdStr", null)
            return
        }
        val target = availableDevices().firstOrNull { it.id == deviceId }
        if (target == null) {
            result.error(E_SELECT, "Audio output not available for device ID: $deviceId", null)
            return
        }
        if (isCurrentlyRouted(deviceId, target.type)) {
            result.success(null)
            return
        }

        pending?.let {
            mainHandler.removeCallbacks(it.timeoutTask)
            pending = null
            it.result.error(E_SUPERSEDED, "Superseded by newer selectAudioOutput call", null)
        }
        val timeoutTask = Runnable { settlePending(E_TIMEOUT, "Route change not confirmed within ${ROUTE_CHANGE_TIMEOUT_MS}ms") }
        pending = PendingSelect(result, deviceId, target.type, timeoutTask)
        mainHandler.postDelayed(timeoutTask, ROUTE_CHANGE_TIMEOUT_MS)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                dispatchSelectApi31(target)
            } else {
                dispatchSelectLegacy(target)
                // Legacy non-SCO routes don't reliably trigger AudioDeviceCallback for
                // state-only toggles (speakerphone, earpiece, wired). Emit and check right
                // away; SCO targets complete through the broadcast receiver.
                emitOutputChanged()
                maybeResolvePending()
            }
        } catch (e: Exception) {
            settlePending(E_SELECT, e.message)
        }
    }

    fun startObserving() {
        if (isObserving) return
        isObserving = true

        audioDeviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                onDevicesAddedDuringCall(addedDevices)
                emitOutputChanged()
                maybeResolvePending()
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                emitOutputChanged()
                maybeResolvePending()
            }
        }.also { audioManager.registerAudioDeviceCallback(it, mainHandler) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val listener = AudioManager.OnCommunicationDeviceChangedListener {
                emitOutputChanged()
                maybeResolvePending()
            }
            audioManager.addOnCommunicationDeviceChangedListener(context.mainExecutor, listener)
            communicationDeviceChangedListener = listener
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1)
                if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED ||
                    state == AudioManager.SCO_AUDIO_STATE_DISCONNECTED
                ) {
                    emitOutputChanged()
                    maybeResolvePending()
                }
            }
        }
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        scoReceiver = receiver
    }

    fun stopObserving() {
        if (!isObserving) return
        isObserving = false

        exitCommunicationMode()

        audioDeviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        audioDeviceCallback = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (communicationDeviceChangedListener as? AudioManager.OnCommunicationDeviceChangedListener)
                ?.let { audioManager.removeOnCommunicationDeviceChangedListener(it) }
        }
        communicationDeviceChangedListener = null
        scoReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        scoReceiver = null

        settlePending(E_CANCELLED, "Audio output observer stopped")
    }

    fun enterCommunicationMode() {
        ownsCommunicationMode = true
        // Mode alone leaves other apps playing. GAIN_TRANSIENT pauses them for
        // the call and lets them resume when the focus is abandoned (SPEC §20b).
        requestCommunicationFocus()
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        routeToBluetoothHeadset()
    }

    fun exitCommunicationMode() {
        if (!ownsCommunicationMode) return
        ownsCommunicationMode = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            } else {
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = false
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
            }
            audioManager.mode = AudioManager.MODE_NORMAL
        } finally {
            abandonCommunicationFocus()
        }
    }

    private fun requestCommunicationFocus() {
        abandonCommunicationFocus()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            requestCommunicationFocusApi26()
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                focusChangeListener,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.w(TAG, "Audio focus not granted ($result)")
            }
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun requestCommunicationFocusApi26() {
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setOnAudioFocusChangeListener(focusChangeListener, mainHandler)
            .build()
        focusRequest = request
        val result = audioManager.requestAudioFocus(request)
        if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.w(TAG, "Audio focus not granted ($result)")
        }
    }

    private fun abandonCommunicationFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            abandonCommunicationFocusApi26()
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusChangeListener)
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun abandonCommunicationFocusApi26() {
        (focusRequest as? AudioFocusRequest)?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    private fun availableDevices(): List<AudioDeviceInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter { it.type in LEGACY_OUTPUT_TYPES }
        }

    private fun currentDevice(): AudioDeviceInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.communicationDevice
        } else {
            findCurrentOutputLegacy()
        }

    @Suppress("DEPRECATION")
    private fun findCurrentOutputLegacy(): AudioDeviceInfo? {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        if (audioManager.isBluetoothScoOn) {
            devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }?.let { return it }
        }
        if (audioManager.isSpeakerphoneOn) {
            devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }?.let { return it }
        }
        // A wired headset is only listed while plugged in, and the OS routes to it.
        devices.firstOrNull {
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
        }?.let { return it }
        return devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE }
    }

    private fun isCurrentlyRouted(targetId: Int, targetType: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // clearCommunicationDevice() leaves no current device: that is the earpiece state.
            val current = audioManager.communicationDevice
                ?: return targetType == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            return current.id == targetId
        }
        return findCurrentOutputLegacy()?.id == targetId
    }

    @TargetApi(Build.VERSION_CODES.S)
    private fun dispatchSelectApi31(target: AudioDeviceInfo) {
        if (target.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) {
            audioManager.clearCommunicationDevice()
            return
        }
        if (!audioManager.setCommunicationDevice(target)) {
            throw IllegalStateException("setCommunicationDevice failed for device ID ${target.id}")
        }
    }

    @Suppress("DEPRECATION")
    private fun dispatchSelectLegacy(target: AudioDeviceInfo) {
        audioManager.isSpeakerphoneOn = false
        audioManager.isBluetoothScoOn = false
        try {
            audioManager.stopBluetoothSco()
        } catch (_: Exception) {
        }

        when (target.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> audioManager.isSpeakerphoneOn = true
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> Unit
            else -> throw IllegalStateException(
                "Cannot select audio output type on this API level: ${nativeType(target.type)}",
            )
        }
    }

    private fun maybeResolvePending() {
        val p = pending ?: return
        if (!isCurrentlyRouted(p.targetDeviceId, p.targetType)) return
        mainHandler.removeCallbacks(p.timeoutTask)
        pending = null
        p.result.success(null)
    }

    private fun settlePending(code: String, message: String?) {
        val p = pending ?: return
        mainHandler.removeCallbacks(p.timeoutTask)
        pending = null
        p.result.error(code, message, null)
    }

    private fun onDevicesAddedDuringCall(addedDevices: Array<out AudioDeviceInfo>) {
        if (!ownsCommunicationMode) return
        if (addedDevices.any { it.isSink && isBluetoothHeadset(it) }) routeToBluetoothHeadset()
    }

    private fun routeToBluetoothHeadset() {
        val headset = availableDevices().firstOrNull(::isBluetoothHeadset) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.setCommunicationDevice(headset)
        } else {
            dispatchSelectLegacy(headset)
        }
    }

    private fun emitOutputChanged() {
        emit(
            mapOf(
                "currentAudioOutput" to currentDevice()?.let(::serialize),
                "availableAudioOutputs" to availableDevices().map(::serialize),
            ),
        )
    }

    companion object {
        private const val TAG = "AudioOutputManager"
        private const val ROUTE_CHANGE_TIMEOUT_MS = 3000L

        const val E_SELECT = "E_AUDIO_OUTPUT_SELECT"
        const val E_SUPERSEDED = "E_AUDIO_OUTPUT_SUPERSEDED"
        const val E_TIMEOUT = "E_AUDIO_OUTPUT_TIMEOUT"
        const val E_CANCELLED = "E_AUDIO_OUTPUT_CANCELLED"

        private val LEGACY_OUTPUT_TYPES = setOf(
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY,
            AudioDeviceInfo.TYPE_HEARING_AID,
        )

        private fun isBluetoothHeadset(device: AudioDeviceInfo): Boolean =
            device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && device.type == AudioDeviceInfo.TYPE_BLE_HEADSET)

        private fun serialize(device: AudioDeviceInfo): Map<String, Any?> = mapOf(
            "type" to normalizedType(device.type),
            "nativeType" to nativeType(device.type),
            "name" to device.productName.toString(),
            "id" to device.id.toString(),
        )

        private fun nativeType(type: Int): String = when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "builtInEarpiece"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtInSpeaker"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadset"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wiredHeadphones"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetoothSCO"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetoothA2DP"
            AudioDeviceInfo.TYPE_HDMI -> "HDMI"
            AudioDeviceInfo.TYPE_USB_DEVICE -> "usbDevice"
            AudioDeviceInfo.TYPE_USB_HEADSET -> "usbHeadset"
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usbAccessory"
            AudioDeviceInfo.TYPE_HEARING_AID -> "hearingAid"
            AudioDeviceInfo.TYPE_BLE_HEADSET -> "bleHeadset"
            AudioDeviceInfo.TYPE_BLE_SPEAKER -> "bleSpeaker"
            AudioDeviceInfo.TYPE_BLE_BROADCAST -> "bleBroadcast"
            else -> "unknown"
        }

        private fun normalizedType(type: Int): String = when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
            AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wiredHeadset"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_BLE_BROADCAST -> "bluetooth"
            AudioDeviceInfo.TYPE_HDMI -> "hdmi"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
            AudioDeviceInfo.TYPE_HEARING_AID -> "hearingAid"
            else -> "unknown"
        }
    }
}
