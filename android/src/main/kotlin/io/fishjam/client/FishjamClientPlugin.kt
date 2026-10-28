package io.fishjam.client

import android.content.Context
import android.util.Log
import io.fishjam.client.foregroundservice.ForegroundServiceController
import io.fishjam.client.foregroundservice.NotificationPermission
import io.fishjam.client.pip.PictureInPictureManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class FishjamClientPlugin : FlutterPlugin, ActivityAware {
    private lateinit var context: Context
    private lateinit var audioChannel: MethodChannel
    private lateinit var audioEvents: EventChannel
    private lateinit var audioOutput: AudioOutputManager
    private var audioEventSink: EventChannel.EventSink? = null
    private lateinit var backgroundChannel: MethodChannel
    private lateinit var videoChannel: MethodChannel
    private val notificationPermission = NotificationPermission()
    private var activityBinding: ActivityPluginBinding? = null
    private lateinit var pipChannel: MethodChannel
    private lateinit var pipEvents: EventChannel
    private var pipEventSink: EventChannel.EventSink? = null
    private val pictureInPicture = PictureInPictureManager { viewId, active ->
        pipEventSink?.success(mapOf("viewId" to viewId, "isActive" to active))
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        disableFlutterWebrtcAudioRouting()
        audioOutput = AudioOutputManager(binding.applicationContext) { event ->
            audioEventSink?.success(event)
        }
        audioOutput.startObserving()
        audioChannel = MethodChannel(binding.binaryMessenger, AUDIO_CHANNEL)
        audioChannel.setMethodCallHandler(::onAudioMethodCall)
        audioEvents = EventChannel(binding.binaryMessenger, AUDIO_EVENTS_CHANNEL)
        audioEvents.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                audioEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                audioEventSink = null
            }
        })
        backgroundChannel = MethodChannel(binding.binaryMessenger, BACKGROUND_CHANNEL)
        backgroundChannel.setMethodCallHandler(::onBackgroundMethodCall)
        pipChannel = MethodChannel(binding.binaryMessenger, PIP_CHANNEL)
        pipChannel.setMethodCallHandler(pictureInPicture::handle)
        pipEvents = EventChannel(binding.binaryMessenger, PIP_EVENTS_CHANNEL)
        pipEvents.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                pipEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                pipEventSink = null
            }
        })
        videoChannel = MethodChannel(binding.binaryMessenger, VIDEO_CHANNEL)
        videoChannel.setMethodCallHandler(::onVideoMethodCall)
    }

    private fun onAudioMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getAvailableAudioOutputs" -> audioOutput.getAvailableAudioOutputs(result)
            "getCurrentAudioOutput" -> audioOutput.getCurrentAudioOutput(result)
            "selectAudioOutput" -> audioOutput.selectAudioOutput(call.arguments as? String, result)
            "enterCommunicationMode" -> {
                audioOutput.enterCommunicationMode()
                result.success(null)
            }
            "exitCommunicationMode" -> {
                audioOutput.exitCommunicationMode()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun onBackgroundMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startForegroundService" -> {
                val config = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                notificationPermission.request(context) {
                    ForegroundServiceController.start(context, config)
                    result.success(null)
                }
            }
            "stopForegroundService" -> {
                ForegroundServiceController.stop(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun onVideoMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setMirror" -> {
                val args = call.arguments as? Map<*, *>
                val textureId = (args?.get("textureId") as? Number)?.toLong()
                val mirror = args?.get("mirror") as? Boolean
                if (textureId == null || mirror == null) {
                    result.error("invalid", "textureId and mirror are required", null)
                    return
                }
                try {
                    VideoMirror.setMirror(textureId, mirror)
                    result.success(null)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not set video mirror", e)
                    result.error("mirror", e.message, null)
                }
            }
            "setPaused" -> {
                val args = call.arguments as? Map<*, *>
                val textureId = (args?.get("textureId") as? Number)?.toLong()
                val paused = args?.get("paused") as? Boolean
                if (textureId == null || paused == null) {
                    result.error("invalid", "textureId and paused are required", null)
                    return
                }
                try {
                    VideoMirror.setPaused(textureId, paused)
                    result.success(null)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not pause video", e)
                    result.error("paused", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audioChannel.setMethodCallHandler(null)
        audioEvents.setStreamHandler(null)
        audioEventSink = null
        audioOutput.stopObserving()
        backgroundChannel.setMethodCallHandler(null)
        pipChannel.setMethodCallHandler(null)
        pipEvents.setStreamHandler(null)
        pipEventSink = null
        videoChannel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        notificationPermission.activity = binding.activity
        binding.addRequestPermissionsResultListener(notificationPermission)
        pictureInPicture.attachActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(notificationPermission)
        activityBinding = null
        notificationPermission.activity = null
        notificationPermission.flush()
        pictureInPicture.detachActivity()
    }

    /**
     * AudioSwitch's route is one class: speaker, earpiece, the first Bluetooth
     * headset, or the first wired headset. It applies that route whenever
     * capture or playback starts, which replaces the device id chosen by
     * [AudioOutputManager.selectAudioOutput]. It also drops audio focus when
     * the last peer connection is disposed, including during reconnection.
     *
     * [AudioOutputManager.enterCommunicationMode] requests
     * `AUDIOFOCUS_GAIN_TRANSIENT` (voice communication) for the room session,
     * so a paused app can resume when the focus is abandoned. iOS session
     * setup stays in flutter_webrtc
     * (`playAndRecord`, other apps do not mix in). Reflection keeps this plugin
     * free of a build dependency on flutter_webrtc.
     */
    private fun disableFlutterWebrtcAudioRouting() {
        try {
            Class.forName("com.cloudwebrtc.webrtc.audio.AudioSwitchManager")
                .getMethod("setAudioSessionManagementEnabled", Boolean::class.javaPrimitiveType)
                .invoke(null, false)
        } catch (e: ReflectiveOperationException) {
            Log.w(TAG, "Could not disable flutter_webrtc audio routing", e)
        }
    }

    companion object {
        private const val TAG = "FishjamClientPlugin"
        private const val AUDIO_CHANNEL = "io.fishjam.client/audio_output"
        private const val AUDIO_EVENTS_CHANNEL = "io.fishjam.client/audio_output_events"
        private const val BACKGROUND_CHANNEL = "io.fishjam.client/background"
        private const val PIP_CHANNEL = "io.fishjam.client/pip"
        private const val PIP_EVENTS_CHANNEL = "io.fishjam.client/pip_events"
        private const val VIDEO_CHANNEL = "io.fishjam.client/video_mirror"
    }
}
