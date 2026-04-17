package com.example.thangu

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.provider.Telephony
import android.provider.BaseColumns
import android.content.pm.PackageManager
import android.Manifest
import androidx.core.app.ActivityCompat
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.thangu/sms"
    private val PERMISSIONS_CHANNEL = "com.example.thangu/permissions"
    private val TAG = "MainActivity"
    private val SMS_PERMISSION_REQUEST_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val permissionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL)
        
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeSmsListener" -> {
                    Log.d(TAG, "SMS listener initialized")
                    result.success(true)
                }
                "checkPermissions" -> {
                    try {
                        val hasSmsPermission = checkSelfPermission("android.permission.READ_SMS") == PackageManager.PERMISSION_GRANTED
                        Log.d(TAG, "Permission check result: $hasSmsPermission")
                        result.success(hasSmsPermission)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking permissions: ${e.message}")
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                "loadHistoricalSms" -> {
                    try {
                        val limitDays = call.argument<Int>("limitDays") ?: 90
                        Log.d(TAG, "Loading historical SMS for last $limitDays days")
                        val smsList = loadHistoricalSms(limitDays)
                        Log.d(TAG, "Successfully loaded ${smsList.size} SMS messages")
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

        permissionsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermissions" -> {
                    try {
                        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                            Log.d(TAG, "Requesting SMS permissions...")
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_SMS),
                                SMS_PERMISSION_REQUEST_CODE
                            )
                            // Will use callback result
                            result.success(null)
                        } else {
                            Log.d(TAG, "SMS permissions already granted")
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting permissions: ${e.message}")
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
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
