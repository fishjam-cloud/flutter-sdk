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
     * flutter_webrtc's AudioSwitch picks its own route whenever audio starts and
     * would undo selectAudioOutput. Reflection keeps this plugin free of a build
     * dependency on flutter_webrtc.
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
