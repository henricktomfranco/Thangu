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

    // Held across the async permission dialog until onRequestPermissionsResult fires
    private var pendingPermissionResult: MethodChannel.Result? = null

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
                        val lastSmsId = call.argument<Long>("lastSmsId")
                        Log.d(TAG, "Loading SMS: limitDays=$limitDays, lastSmsId=$lastSmsId")
                        val smsList = loadHistoricalSms(limitDays, lastSmsId)
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
                            // Store result — we'll complete it in onRequestPermissionsResult
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_SMS),
                                SMS_PERMISSION_REQUEST_CODE
                            )
                            // Do NOT call result.success() here — wait for the callback.
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "SMS permission result: granted=$granted")
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun loadHistoricalSms(limitDays: Int, lastSmsId: Long?): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val contentResolver = contentResolver

        try {
            // Check permission before querying SMS (prevents SecurityException on Android 13+)
            if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "SMS permission not granted — skipping query")
                return smsList
            }

            val uri = Telephony.Sms.CONTENT_URI
            val projection = arrayOf(
                BaseColumns._ID,
                Telephony.Sms.BODY,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            )

            // Query BOTH inbox and sent folders — some banks send confirmation SMS
            // to the sent folder which would be missed otherwise
            val smsTypes = listOf(
                Telephony.Sms.MESSAGE_TYPE_INBOX,
                Telephony.Sms.MESSAGE_TYPE_SENT
            )

            var selection: String
            var selectionArgs: Array<String>
            val sortOrder = "${BaseColumns._ID} ASC"

            if (lastSmsId != null) {
                // ID-based filtering: get SMS with _id > lastSmsId from inbox AND sent
                val typePlaceholders = smsTypes.joinToString(",") { "?" }
                selection = "${BaseColumns._ID} > ? AND ${Telephony.Sms.TYPE} IN ($typePlaceholders)"
                selectionArgs = arrayOf(lastSmsId.toString(), *smsTypes.map { it.toString() }.toTypedArray())
                Log.d(TAG, "Using ID-based filtering: $lastSmsId (inbox + sent)")
            } else {
                // Date-based filtering: get SMS from last N days from inbox AND sent
                val calendar = Calendar.getInstance()
                calendar.add(Calendar.DAY_OF_YEAR, -limitDays)
                val timeLimitMillis = calendar.timeInMillis
                val typePlaceholders = smsTypes.joinToString(",") { "?" }
                selection = "${Telephony.Sms.DATE} > ? AND ${Telephony.Sms.TYPE} IN ($typePlaceholders)"
                selectionArgs = arrayOf(timeLimitMillis.toString(), *smsTypes.map { it.toString() }.toTypedArray())
                Log.d(TAG, "Using date-based filtering: $limitDays days (inbox + sent)")
            }

            val cursor = contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )

            if (cursor == null) {
                Log.w(TAG, "SMS query returned null cursor")
                return smsList
            }

            Log.d(TAG, "SMS query cursor count: ${cursor.count}")

            cursor.use {
                while (it.moveToNext()) {
                    try {
                        val smsId = it.getLong(it.getColumnIndexOrThrow(BaseColumns._ID))
                        val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY))
                        val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS))
                        val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                        val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))

                        // Only include non-empty messages
                        if (body.isNotEmpty() && address.isNotEmpty()) {
                            if (smsList.size < 3) {
                                Log.d(TAG, "SMS sample [${smsList.size + 1}] from=$address body=${body.take(100)}")
                            }
                            smsList.add(mapOf(
                                "sms_id" to smsId,
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

            Log.d(TAG, "Loaded ${smsList.size} SMS messages")
        } catch (e: Exception) {
            Log.e(TAG, "Exception loading SMS: ${e.message}", e)
        }

        return smsList
    }
}
