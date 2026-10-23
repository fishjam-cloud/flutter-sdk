package io.fishjam.client.pip

import android.app.Activity
import android.app.PictureInPictureParams
import android.graphics.Color
import android.os.Build
import android.util.Log
import android.util.Rational
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.annotation.RequiresApi
import androidx.core.app.OnPictureInPictureModeChangedProvider
import androidx.core.app.PictureInPictureModeChangedInfo
import androidx.core.util.Consumer
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.utils.EglUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import org.webrtc.RendererCommon
import org.webrtc.SurfaceViewRenderer
import org.webrtc.VideoTrack

/**
 * Handles `io.fishjam.client/pip`. Port of the React Native SDK's
 * `PIPManager` (`react-native-webrtc/android/.../PIPManager.java`): each
 * `PictureInPictureView` on the Dart side registers its own settings here,
 * keyed by view id, just like each `WebRTCView` there owns one `PIPManager`.
 *
 * Android's picture-in-picture window is a property of the `Activity`
 * (`enterPictureInPictureMode`), not of a view, so only one view's settings
 * can back the window at a time -- the one most recently updated, or the one
 * [start] was called on. The React Native SDK has the same constraint for
 * the same reason, despite also keeping one manager per view.
 *
 * While in picture-in-picture the Flutter view is hidden and a
 * [SurfaceViewRenderer] fed by the same track fills the window, so the window
 * shows only the video whatever the Flutter UI looks like.
 */
class PictureInPictureManager(private val onActiveChanged: (viewId: Int, active: Boolean) -> Unit) {
    private var activity: Activity? = null
    private var listening = false

    private class ViewState {
        var trackId: String? = null
        var mirror = false
        var objectFitContain = false
        var startAutomatically = true
        var preferredWidth = 0.0
        var preferredHeight = 0.0
        var viewWidth = 0.0
        var viewHeight = 0.0
        var label = "No video"
        var backgroundColor = DEFAULT_PLACEHOLDER_BACKGROUND
        var textColor = Color.WHITE
    }

    private val views = mutableMapOf<Int, ViewState>()

    /** Whichever view's settings currently back the window. */
    private var currentViewId: Int? = null
    private var active = false

    private val hiddenChildren = mutableListOf<Pair<View, Int>>()
    private var container: FrameLayout? = null
    private var renderer: SurfaceViewRenderer? = null
    private var rendererTrack: VideoTrack? = null

    private val modeListener = Consumer<PictureInPictureModeChangedInfo> { info ->
        if (info.isInPictureInPictureMode) {
            onEnter()
        } else {
            onExit()
            if (currentViewId == null) stopListening()
        }
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
        if (currentViewId != null) {
            startListening()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) applyParams()
        }
    }

    fun detachActivity() {
        if (active) onExit()
        stopListening()
        activity = null
    }

    fun handle(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
        val id = (args["viewId"] as? Number)?.toInt()
        when (call.method) {
            "update" -> if (id != null) update(id, args)
            "start" -> if (id != null) start(id)
            "stop" -> Unit
            "unregister" -> if (id != null) unregister(id)
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    private fun update(id: Int, args: Map<*, *>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val state = views.getOrPut(id) { ViewState() }
        state.trackId = args["trackId"] as? String
        state.mirror = args["mirror"] as? Boolean ?: false
        state.objectFitContain = args["objectFit"] == "contain"
        state.startAutomatically = args["startAutomatically"] as? Boolean ?: true
        val preferred = args["preferredSize"] as? Map<*, *>
        // React Native defaults to 1920×1080. A side of 0 falls back to the
        // view size in [buildParams].
        state.preferredWidth = preferredSide(preferred?.get("width"), DEFAULT_PREFERRED_WIDTH)
        state.preferredHeight = preferredSide(preferred?.get("height"), DEFAULT_PREFERRED_HEIGHT)
        val rect = args["rect"] as? Map<*, *>
        state.viewWidth = (rect?.get("width") as? Number)?.toDouble() ?: 0.0
        state.viewHeight = (rect?.get("height") as? Number)?.toDouble() ?: 0.0
        state.label = args["fallbackLabel"] as? String ?: "No video"
        state.backgroundColor = (args["fallbackBackgroundColor"] as? Number)?.toInt()
            ?: DEFAULT_PLACEHOLDER_BACKGROUND
        state.textColor = (args["fallbackTextColor"] as? Number)?.toInt() ?: Color.WHITE

        val takesOver = currentViewId != id
        currentViewId = id
        if (takesOver && active) onActiveChanged(id, true)

        if (active) {
            if (state.trackId == null) {
                showNoVideo(state)
            } else {
                renderer?.let {
                    it.setMirror(state.mirror)
                    it.setScalingType(scalingType(state))
                }
                attachRendererTrack(state)
            }
        }

        startListening()
        applyParams()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun start(id: Int) {
        val activity = activity ?: return
        val state = views[id] ?: return
        currentViewId = id
        try {
            activity.enterPictureInPictureMode(buildParams(state))
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Failed to enter picture-in-picture", e)
        }
    }

    private fun unregister(id: Int) {
        val state = views.remove(id)
        if (currentViewId != id) return
        currentViewId = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && state != null) {
            state.startAutomatically = false
            val activity = activity
            if (activity != null) {
                try {
                    activity.setPictureInPictureParams(buildParams(state))
                } catch (e: IllegalStateException) {
                    Log.e(TAG, "Failed to update picture-in-picture params", e)
                }
            }
        }
        if (active) {
            // The window stays open: restoring the Flutter view now would show
            // the app's UI in it, and Android ignores a close request. Show
            // "No video" until another view takes over or the user closes it.
            showNoVideo(state)
            return
        }
        stopListening()
    }

    private fun startListening() {
        if (listening) return
        val provider = activity as? OnPictureInPictureModeChangedProvider
        if (provider == null) {
            if (activity != null) {
                Log.w(
                    TAG,
                    "Picture-in-picture needs MainActivity to extend FlutterFragmentActivity",
                )
            }
            return
        }
        provider.addOnPictureInPictureModeChangedListener(modeListener)
        listening = true
    }

    private fun stopListening() {
        if (!listening) return
        (activity as? OnPictureInPictureModeChangedProvider)
            ?.removeOnPictureInPictureModeChangedListener(modeListener)
        listening = false
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildParams(state: ViewState): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        val width = if (state.preferredWidth > 0) state.preferredWidth else state.viewWidth
        val height = if (state.preferredHeight > 0) state.preferredHeight else state.viewHeight
        if (width > 0 && height > 0) {
            // Android rejects ratios outside 1:2.39 .. 2.39:1.
            val ratio = (width / height).coerceIn(1 / MAX_RATIO, MAX_RATIO)
            builder.setAspectRatio(Rational((ratio * 10_000).toInt(), 10_000))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(state.startAutomatically && listening)
        }
        return builder.build()
    }

    private fun applyParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val activity = activity ?: return
        val state = currentViewId?.let { views[it] } ?: return
        try {
            activity.setPictureInPictureParams(buildParams(state))
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Failed to update picture-in-picture params", e)
        }
    }

    private fun onEnter() {
        setActive(true)
        val activity = activity ?: return
        val state = currentViewId?.let { views[it] } ?: return
        val root = activity.findViewById<ViewGroup>(android.R.id.content) ?: return

        hiddenChildren.clear()
        for (i in 0 until root.childCount) {
            val child = root.getChildAt(i)
            hiddenChildren.add(child to child.visibility)
            child.visibility = View.GONE
        }

        val surface = SurfaceViewRenderer(activity).apply {
            setBackgroundColor(Color.BLACK)
            setMirror(state.mirror)
            setScalingType(scalingType(state))
        }
        val frame = FrameLayout(activity).apply {
            setBackgroundColor(Color.BLACK)
            addView(surface, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        }
        root.addView(frame, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        container = frame

        val eglContext = EglUtils.getRootEglBaseContext()
        if (eglContext == null) {
            Log.e(TAG, "Cannot create the picture-in-picture renderer: no EGL context")
            return
        }
        try {
            surface.init(eglContext, object : RendererCommon.RendererEvents {
                override fun onFirstFrameRendered() {
                    surface.post { surface.setBackgroundColor(Color.TRANSPARENT) }
                }

                override fun onFrameResolutionChanged(width: Int, height: Int, rotation: Int) {}
            })
            renderer = surface
            attachRendererTrack(state)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to initialize the picture-in-picture renderer", e)
        }
    }

    private fun attachRendererTrack(state: ViewState) {
        val surface = renderer ?: return
        rendererTrack?.let { track -> runCatching { track.removeSink(surface) } }
        rendererTrack = null
        val track = state.trackId?.let {
            FlutterWebRTCPlugin.sharedSingleton?.getTrackForId(it, null) as? VideoTrack
        }
        track ?: return
        try {
            track.addSink(surface)
            rendererTrack = track
            surface.visibility = View.VISIBLE
            container?.findViewWithTag<View>(FALLBACK_TAG)?.let { container?.removeView(it) }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Failed to add the picture-in-picture renderer to the track", e)
        }
    }

    private fun showNoVideo(state: ViewState?) {
        detachRendererTrack()
        val frame = container ?: return
        renderer?.visibility = View.GONE
        val label = state?.label ?: "No video"
        val background = state?.backgroundColor ?: DEFAULT_PLACEHOLDER_BACKGROUND
        val textColor = state?.textColor ?: Color.WHITE
        frame.setBackgroundColor(background)
        val existing = frame.findViewWithTag<TextView>(FALLBACK_TAG)
        if (existing != null) {
            existing.text = label
            existing.setTextColor(textColor)
            return
        }
        frame.addView(
            TextView(frame.context).apply {
                tag = FALLBACK_TAG
                text = label
                setTextColor(textColor)
                gravity = Gravity.CENTER
                textSize = 18f
            },
            FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT),
        )
    }

    private fun detachRendererTrack() {
        val surface = renderer ?: return
        rendererTrack?.let { track -> runCatching { track.removeSink(surface) } }
        rendererTrack = null
        surface.clearImage()
    }

    private fun onExit() {
        setActive(false)
        renderer?.let { surface ->
            rendererTrack?.let { track -> runCatching { track.removeSink(surface) } }
            surface.release()
        }
        renderer = null
        rendererTrack = null

        val root = activity?.findViewById<ViewGroup>(android.R.id.content)
        container?.let { root?.removeView(it) }
        container = null
        for ((child, visibility) in hiddenChildren) child.visibility = visibility
        hiddenChildren.clear()
    }

    private fun setActive(value: Boolean) {
        if (active == value) return
        active = value
        currentViewId?.let { onActiveChanged(it, value) }
    }

    private fun preferredSide(value: Any?, fallback: Double): Double =
        (value as? Number)?.toDouble() ?: fallback

    private fun scalingType(state: ViewState) =
        if (state.objectFitContain) {
            RendererCommon.ScalingType.SCALE_ASPECT_FIT
        } else {
            RendererCommon.ScalingType.SCALE_ASPECT_FILL
        }

    private companion object {
        const val TAG = "FishjamPictureInPicture"
        const val FALLBACK_TAG = "pip-fallback"
        const val DEFAULT_PLACEHOLDER_BACKGROUND = 0xFF1C2945.toInt()
        const val DEFAULT_PREFERRED_WIDTH = 1920.0
        const val DEFAULT_PREFERRED_HEIGHT = 1080.0
        const val MAX_RATIO = 2.39
        const val MATCH_PARENT = ViewGroup.LayoutParams.MATCH_PARENT
    }
}
