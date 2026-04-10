package com.example.thangu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.thangu/sms"
    private lateinit var smsChannel: MethodChannel
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeSmsListener" -> {
                    Log.d(TAG, "SMS listener initialized")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up callback for SMS messages
        SmsReceiver.setSmsCallback { messageBody, sender ->
            try {
                smsChannel.invokeMethod("onSmsReceived", mapOf(
                    "body" to messageBody,
                    "sender" to sender,
                    "timestamp" to System.currentTimeMillis()
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Error invoking SMS method: ${e.message}", e)
            }
        }
    }
}
