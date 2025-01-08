package com.flutterbountyhunters.superkeyboard.super_keyboard

import android.app.Activity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import androidx.core.view.OnApplyWindowInsetsListener
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel


/**
 * Plugin that reports software keyboard state changes, and (maybe) keyboard height changes.
 *
 * Tracking keyboard height is more difficult. There may be some platforms that don't
 * support height tracking.
 *
 * Android Docs: https://developer.android.com/develop/ui/views/layout/sw-keyboard
 */
class SuperKeyboardPlugin: FlutterPlugin, ActivityAware, OnApplyWindowInsetsListener {
  private lateinit var channel : MethodChannel

  // The root view within the Android Activity.
  private var mainView: View? = null

  // The manager for text input for the Android Activity.
  private lateinit var ime: InputMethodManager

  // The most recent known state of the software keyboard.
  private var keyboardState: KeyboardState = KeyboardState.Closed

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "super_keyboard_android")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    startListeningForKeyboardChanges(binding.activity)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    startListeningForKeyboardChanges(binding.activity)
  }

  private fun startListeningForKeyboardChanges(activity: Activity) {
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
            channel.invokeMethod("keyboardOpened", null)
          } else if (keyboardState == KeyboardState.Closing) {
            channel.invokeMethod("keyboardClosed", null)
          }
        }
      }
    )
  }

  override fun onApplyWindowInsets(v: View, insets: WindowInsetsCompat): WindowInsetsCompat {
    val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())

    // Note: We only identify opening/closing here. The opened/closed completion
    //       is identified by the window insets animation callback.
    if (imeVisible && keyboardState != KeyboardState.Opening && keyboardState != KeyboardState.Open) {
      channel.invokeMethod("keyboardOpening", null)
      keyboardState = KeyboardState.Opening
    } else if (!imeVisible && keyboardState != KeyboardState.Closing && keyboardState != KeyboardState.Closed) {
      channel.invokeMethod("keyboardClosing", null)
      keyboardState = KeyboardState.Closing
    }

    return insets
  }

  override fun onDetachedFromActivityForConfigChanges() {
    stopListeningForKeyboardChanges()
  }

  override fun onDetachedFromActivity() {
    stopListeningForKeyboardChanges()
  }

  private fun stopListeningForKeyboardChanges() {
    if (mainView == null) {
      return;
    }

    ViewCompat.setOnApplyWindowInsetsListener(mainView!!, null)
    ViewCompat.setWindowInsetsAnimationCallback(mainView!!, null)

    mainView = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

private enum class KeyboardState {
  Closed,
  Opening,
  Open,
  Closing;
}