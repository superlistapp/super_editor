package com.flutterbountyhunters.superkeyboard.super_keyboard

import android.app.Activity
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import androidx.core.view.OnApplyWindowInsetsListener
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.MethodChannel


/**
 * Plugin that reports software keyboard state changes, and (maybe) keyboard height changes.
 *
 * Tracking keyboard height is more difficult. There may be some platforms that don't
 * support height tracking.
 *
 * Android Docs: https://developer.android.com/develop/ui/views/layout/sw-keyboard
 */
class SuperKeyboardPlugin: FlutterPlugin, ActivityAware, DefaultLifecycleObserver, OnApplyWindowInsetsListener {
  private lateinit var channel : MethodChannel

  private var binding: ActivityPluginBinding? = null

  // The Activity's lifecycle, which reports things like when the Android
  // app comes into the foreground from the background.
  private var lifecycle: Lifecycle? = null

  // The root view within the Android Activity.
  private var mainView: View? = null

  // The manager for text input for the Android Activity.
  private lateinit var ime: InputMethodManager

  // The most recent known state of the software keyboard.
  private var keyboardState: KeyboardState = KeyboardState.Closed

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.d("super_keyboard", "Attached to Flutter engine")
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "super_keyboard_android")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.d("super_keyboard", "Attached to Flutter Activity")
    this.binding = binding
    startListeningToActivityLifecycle()
  }

  override fun onResume(owner: LifecycleOwner) {
    Log.d("super_keyboard", "Activity Resumed - keyboard state: $keyboardState")
    startListeningForKeyboardChanges(binding!!)
    sendLatestKeyboardStateToApp()
  }

  private fun sendLatestKeyboardStateToApp() {
    val insets = ViewCompat.getRootWindowInsets(mainView!!) ?: return

    if (insets.getInsets(WindowInsetsCompat.Type.ime()).bottom == 0 && keyboardState != KeyboardState.Closed) {
      keyboardState = KeyboardState.Closed
      channel.invokeMethod("keyboardClosed", null)
    }
  }

  override fun onPause(owner: LifecycleOwner) {
    Log.d("super_keyboard", "Activity Paused - keyboard state: $keyboardState")
    stopListeningForKeyboardChanges()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    stopListeningToActivityLifecycle()
    this.binding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    startListeningToActivityLifecycle()
    this.binding = binding
  }

  override fun onDetachedFromActivity() {
    Log.d("super_keyboard", "Detached from Flutter activity")
    stopListeningToActivityLifecycle()
    this.binding = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d("super_keyboard", "Detached from Flutter engine")
    this.binding = null
  }

  private fun startListeningToActivityLifecycle() {
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding!!)
    lifecycle!!.addObserver(this)
  }

  private fun stopListeningToActivityLifecycle() {
    lifecycle!!.removeObserver(this);
  }

  private fun startListeningForKeyboardChanges(binding: ActivityPluginBinding) {
    val activity = binding.activity

    mainView = activity.findViewById<ViewGroup>(android.R.id.content)
    ime = activity.getSystemService(Activity.INPUT_METHOD_SERVICE) as InputMethodManager
    if (mainView == null) {
      // This should never happen. If it does, we just fizzle.
      return;
    }

    // Track keyboard opening and closing.
    ViewCompat.setOnApplyWindowInsetsListener(mainView!!, this)

    // Track keyboard fully open, fully closed, and height.
    ViewCompat.setWindowInsetsAnimationCallback(
      mainView!!,
      object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {
        override fun onPrepare(
          animation: WindowInsetsAnimationCompat
        ) {
          // no-op
        }

        override fun onStart(
          animation: WindowInsetsAnimationCompat,
          bounds: WindowInsetsAnimationCompat.BoundsCompat
        ): WindowInsetsAnimationCompat.BoundsCompat {
          // no-op
          return bounds
        }

        override fun onProgress(
          insets: WindowInsetsCompat,
          runningAnimations: MutableList<WindowInsetsAnimationCompat>
        ): WindowInsetsCompat {
          val imeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom

          channel.invokeMethod("onProgress", mapOf(
            "keyboardHeight" to imeHeight,
          ))

          return insets
        }

        override fun onEnd(
          animation: WindowInsetsAnimationCompat
        ) {
          // Report whether the keyboard has fully opened or fully closed.
          if (keyboardState == KeyboardState.Opening) {
            keyboardState = KeyboardState.Open
            channel.invokeMethod("keyboardOpened", null)
          } else if (keyboardState == KeyboardState.Closing) {
            keyboardState = KeyboardState.Closed
            channel.invokeMethod("keyboardClosed", null)
          }
        }
      }
    )
  }

  override fun onApplyWindowInsets(v: View, insets: WindowInsetsCompat): WindowInsetsCompat {
    Log.d("super_keyboard", "onApplyWindowInsets()")
    if (lifecycle!!.currentState == Lifecycle.State.CREATED) {
      // For at least Android API 34, we receive conflicting reports about IME visibility
      // when the app is being backgrounded. First we're told the IME isn't visible, then
      // we're told that it is. In theory, the IME should never be visible when in the CREATED
      // state, so we explicitly tell the app that the keyboard is closed here.
      if (keyboardState != KeyboardState.Closed) {
        Log.d("super_keyboard", "Activity is in CREATED state - telling app that keyboard is closed")
        keyboardState = KeyboardState.Closed
        channel.invokeMethod("keyboardClosed", null)
      }

      return insets
    }

    val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())
    Log.d("super_keyboard", "Is IME visible? $imeVisible")
    Log.d("super_keyboard", "Lifecycle state: ${lifecycle!!.currentState}")

    Log.d("super_keyboard", "Insets: ${insets.getInsets(WindowInsetsCompat.Type.ime()).bottom}")

    // Note: We primarily only identify opening/closing here. The opened/closed completion
    //       is identified by the window insets animation callback.
    //
    //       The exception is that when the Activity resumes, the keyboard might jump immediately
    //       to "closed". We catch that situation by looking for a `0` bottom inset.
    if (imeVisible && keyboardState != KeyboardState.Opening && keyboardState != KeyboardState.Open) {
      Log.d("super_keyboard", "Setting keyboard state to Opening")
      channel.invokeMethod("keyboardOpening", null)
      keyboardState = KeyboardState.Opening
    } else if (!imeVisible && keyboardState != KeyboardState.Closing && keyboardState != KeyboardState.Closed) {
      if (insets.getInsets(WindowInsetsCompat.Type.ime()).bottom == 0) {
        Log.d("super_keyboard", "Setting keyboard state to Closed")
        channel.invokeMethod("keyboardClosed", null)
        keyboardState = KeyboardState.Closed
      } else {
        Log.d("super_keyboard", "Setting keyboard state to Closing")
        channel.invokeMethod("keyboardClosing", null)
        keyboardState = KeyboardState.Closing
      }
    }

    return insets
  }

  private fun stopListeningForKeyboardChanges() {
    if (mainView == null) {
      return;
    }

    ViewCompat.setOnApplyWindowInsetsListener(mainView!!, null)
    ViewCompat.setWindowInsetsAnimationCallback(mainView!!, null)

    mainView = null
  }
}

private enum class KeyboardState {
  Closed,
  Opening,
  Open,
  Closing;
}