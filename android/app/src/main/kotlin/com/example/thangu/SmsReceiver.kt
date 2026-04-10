package com.example.thangu

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

/**
 * BroadcastReceiver for handling incoming SMS messages
 * Extracts transaction data from SMS and sends to Flutter app via method channel
 */
class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        // This will be set by MainActivity
        private var smsCallback: ((String, String) -> Unit)? = null

        fun setSmsCallback(callback: (String, String) -> Unit) {
            smsCallback = callback
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null || context == null) return

        try {
            // Check if this is an SMS_RECEIVED action
            if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                val extras = intent.extras ?: return
                val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

                for (smsMessage in smsMessages) {
                    val messageBody = smsMessage.displayMessageBody
                    val sender = smsMessage.displayOriginatingAddress

                    Log.d(TAG, "SMS Received from: $sender, Body: $messageBody")

                    // Send SMS data to Flutter
                    smsCallback?.invoke(messageBody, sender)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing SMS: ${e.message}", e)
        }
    }
}
