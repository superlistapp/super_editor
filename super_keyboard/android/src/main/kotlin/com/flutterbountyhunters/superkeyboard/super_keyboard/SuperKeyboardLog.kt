package com.flutterbountyhunters.superkeyboard.super_keyboard

import android.util.Log

object SuperKeyboardLog {
    var isLoggingEnabled: Boolean = false

    fun d(tag: String, message: String) {
        if (isLoggingEnabled) Log.d(tag, message)
    }

    fun i(tag: String, message: String) {
        if (isLoggingEnabled) Log.i(tag, message)
    }

    fun w(tag: String, message: String) {
        if (isLoggingEnabled) Log.w(tag, message)
    }

    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (isLoggingEnabled) Log.e(tag, message, throwable)
    }

    fun v(tag: String, message: String) {
        if (isLoggingEnabled) Log.v(tag, message)
    }
}