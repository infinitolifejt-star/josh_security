package com.josh.security.josh_security

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class JoshPhoneBridge(private val context: Context) {
    companion object {
        private const val CHANNEL = "com.josh.security/phone"
        private var methodChannel: MethodChannel? = null

        fun setupChannel(flutterEngine: FlutterEngine) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        }

        fun sendIncomingNumberToFlutter(phoneNumber: String) {
            methodChannel?.invokeMethod("onIncomingCall", phoneNumber)
        }
    }
}
