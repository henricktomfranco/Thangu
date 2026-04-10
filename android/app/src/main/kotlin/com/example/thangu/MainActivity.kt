package com.example.thangu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.provider.Telephony
import android.provider.BaseColumns
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.thangu/sms"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeSmsListener" -> {
                    Log.d(TAG, "SMS listener initialized")
                    result.success(true)
                }
                "loadHistoricalSms" -> {
                    try {
                        val limitDays = call.argument<Int>("limitDays") ?: 90
                        val smsList = loadHistoricalSms(limitDays)
                        result.success(smsList)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error loading historical SMS: ${e.message}", e)
                        result.error("SMS_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        try {
            // Set up callback for SMS messages
            SmsReceiver.setSmsCallback { messageBody, sender ->
                try {
                    Log.d(TAG, "SMS callback received: $sender")
                    smsChannel.invokeMethod("onSmsReceived", mapOf(
                        "body" to messageBody,
                        "sender" to sender,
                        "timestamp" to System.currentTimeMillis()
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "Error invoking SMS method: ${e.message}", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up SMS callback: ${e.message}", e)
        }
    }

    private fun loadHistoricalSms(limitDays: Int): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val contentResolver = contentResolver

        try {
            // Calculate date limit
            val calendar = Calendar.getInstance()
            calendar.add(Calendar.DAY_OF_YEAR, -limitDays)
            val timeLimitMillis = calendar.timeInMillis

            // Query SMS inbox
            val uri = Telephony.Sms.CONTENT_URI
            val projection = arrayOf(
                BaseColumns._ID,
                Telephony.Sms.BODY,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            )
            val sortOrder = "${Telephony.Sms.DATE} DESC"
            val selection = "${Telephony.Sms.DATE} > ?"
            val selectionArgs = arrayOf(timeLimitMillis.toString())

            val cursor = contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )

            cursor?.use {
                while (it.moveToNext()) {
                    try {
                        val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY))
                        val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS))
                        val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                        val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))

                        // Only include non-empty messages
                        if (body.isNotEmpty() && address.isNotEmpty()) {
                            smsList.add(mapOf(
                                "body" to body,
                                "sender" to address,
                                "timestamp" to date,
                                "type" to type
                            ))
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error parsing SMS: ${e.message}")
                        continue
                    }
                }
            }

            Log.d(TAG, "Loaded ${smsList.size} historical SMS messages")
        } catch (e: Exception) {
            Log.e(TAG, "Exception loading SMS: ${e.message}", e)
        }

        return smsList
    }
}
