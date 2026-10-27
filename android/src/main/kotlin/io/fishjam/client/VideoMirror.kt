package io.fishjam.client

import android.util.LongSparseArray

/**
 * Mirror and pause for flutter_webrtc's texture renderer, looked up by
 * reflection so this plugin does not depend on flutter_webrtc.
 * `com.cloudwebrtc.webrtc.**` is kept by that package, so these names
 * survive shrinking.
 *
 * [setPaused] `true` calls `pauseVideo` (the last frame stays). `false`
 * calls `disableFpsReduction`. The mirror is set while drawing is paused.
 */
internal object VideoMirror {
    fun setMirror(textureId: Long, mirror: Boolean) {
        invoke(textureId, "setMirror", mirror)
    }

    fun setPaused(textureId: Long, paused: Boolean) {
        invoke(textureId, if (paused) "pauseVideo" else "disableFpsReduction")
    }

    private fun invoke(textureId: Long, methodName: String, argument: Boolean? = null) {
        val renderer = renderer(textureId)
        val method = renderer.javaClass.methods.firstOrNull { method ->
            method.name == methodName &&
                method.parameterTypes.size == if (argument == null) 0 else 1
        } ?: error("video renderer has no $methodName")
        if (argument == null) method.invoke(renderer) else method.invoke(renderer, argument)
    }

    private fun renderer(textureId: Long): Any {
        val pluginClass = Class.forName("com.cloudwebrtc.webrtc.FlutterWebRTCPlugin")
        val plugin = pluginClass.getField("sharedSingleton").get(null)
            ?: error("FlutterWebRTCPlugin.sharedSingleton is null")
        val handler = readField(plugin, "methodCallHandler")
            ?: error("flutter_webrtc has no method handler")
        val renders = readField(handler, "renders") as LongSparseArray<*>
        val render = renders.get(textureId)
            ?: error("no video renderer for texture $textureId")
        return readField(render, "surfaceTextureRenderer")
            ?: error("video renderer has no surface")
    }

    private fun readField(target: Any, name: String): Any? {
        val field = target.javaClass.getDeclaredField(name)
        field.isAccessible = true
        return field.get(target)
    }
}
