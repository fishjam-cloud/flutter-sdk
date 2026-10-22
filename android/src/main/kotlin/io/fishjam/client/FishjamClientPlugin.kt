package io.fishjam.client

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class FishjamClientPlugin : FlutterPlugin {
    private lateinit var audioChannel: MethodChannel
    private lateinit var audioEvents: EventChannel
    private lateinit var audioOutput: AudioOutputManager
    private var audioEventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audioChannel.setMethodCallHandler(null)
        audioEvents.setStreamHandler(null)
        audioEventSink = null
        audioOutput.stopObserving()
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
    }
}
