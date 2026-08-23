package com.josh.security.josh_security

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

object JoshPhoneBridge {

    private const val TAG = "JoshPhoneBridge"

    private const val CHANNEL =
        "josh_security/background_phone"

    private const val DART_ENTRYPOINT =
        "backgroundPhoneMain"

    @Volatile
    private var flutterEngine: FlutterEngine? = null

    @Volatile
    private var methodChannel: MethodChannel? = null

    @Synchronized
    fun initialize(context: Context): MethodChannel {

        methodChannel?.let {
            return it
        }

        Log.d(TAG, "Inicializando FlutterEngine de llamadas...")

        val engine = FlutterEngine(context.applicationContext)

        val dartEntrypoint = DartExecutor.DartEntrypoint(
            context.applicationContext.applicationInfo.sourceDir,
            DART_ENTRYPOINT
        )

        engine.dartExecutor.executeDartEntrypoint(
            dartEntrypoint
        )

        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        flutterEngine = engine
        methodChannel = channel

        Log.d(TAG, "FlutterEngine de llamadas inicializado.")

        return channel
    }

    fun handleIncomingCall(
        context: Context,
        callDetails: Call.Details
    ) {

        val number = extractPhoneNumber(callDetails)

        Log.d(TAG, "==========================================")
        Log.d(TAG, "JOSH PHONE BRIDGE")
        Log.d(TAG, "Número recibido: $number")
        Log.d(TAG, "==========================================")

        val channel = initialize(context)

        Handler(Looper.getMainLooper()).post {

            try {

                channel.invokeMethod(
                    "incomingCall",
                    mapOf(
                        "phoneNumber" to number,
                        "timestamp" to System.currentTimeMillis()
                    )
                )

                Log.d(
                    TAG,
                    "Evento enviado al background Flutter."
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error enviando llamada a Flutter.",
                    e
                )
            }
        }
    }

    fun handleCallEnded(
        context: Context
    ) {

        val channel = methodChannel ?: return

        Handler(Looper.getMainLooper()).post {

            try {

                channel.invokeMethod(
                    "callEnded",
                    null
                )

                Log.d(
                    TAG,
                    "Evento callEnded enviado."
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error enviando callEnded.",
                    e
                )
            }
        }
    }

    private fun extractPhoneNumber(
        callDetails: Call.Details
    ): String {

        val handle = callDetails.handle

        if (handle == null) {
            return "Número Oculto"
        }

        val number = handle.schemeSpecificPart

        if (number.isNullOrBlank()) {
            return "Número Oculto"
        }

        return number
    }

    fun dispose() {

        try {

            flutterEngine?.destroy()

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Error destruyendo FlutterEngine.",
                e
            )
        }

        flutterEngine = null
        methodChannel = null
    }
}
