# Thangu - Qatar Bank Message Support

Your app has been updated to detect **Qatari bank messages** with QAR (Qatari Riyal) format!

## Your Message Format

The app now detects messages like:

```
Debit Card **6260 
was used for QAR 38.00
at MCDONALDS OLD AIRPOR
at 00:57
10-Apr-26
Balance: QAR 17,189.73
Enquiry 44490000
```

**Breaking it down:**
- ✓ **Amount detected:** QAR 38.00
- ✓ **Type detected:** Debit (from "Debit Card" and "was used for")
- ✓ **Description:** MCDONALDS OLD AIRPOR
- ✓ **Date:** 10-Apr-26

## How It Works

### Two-Level Detection

1. **Keyword Matching** (First, Fast):
   - Looks for "Debit Card", "was used for", "Balance", "QAR", etc.
   - Works immediately without needing AI

2. **AI Detection** (Second, if keywords don't match):
   - If a message doesn't have financial keywords, the app asks the AI
   - Asks: "Is this a financial transaction?"
   - Works with Ollama or OpenAI

### Supported Currencies

The app detects transactions in:
- **QAR** - Qatari Riyal ✓ (Your messages)
- **AED** - UAE Dirham
- **SAR** - Saudi Riyal
- **USD** - US Dollar
- **EUR** - Euro
- **GBP** - British Pound
- **INR** - Indian Rupee
- **Rs./₹** - Old format

## How to Use

1. **Install the new APK:**
   ```
   c:\Go\Thangu\build\app\outputs\flutter-apk\app-release.apk
   ```

2. **Grant SMS Permission**
   - When you open the Transactions screen, tap **"Grant SMS Permission"**
   - Accept the Android prompt

3. **Messages will be auto-detected**
   - The app will read your SMS from the last **90 days**
   - Your Qatari bank messages will show up automatically

4. **Verify Detection**

   Look in the console logs for:
   ```
   [SmsHistory] Received X SMS messages from platform
   [SmsHistory] ✓ Saved transaction #1: MCDONALDS OLD AIRPOR - QAR 38.00
   [SmsHistory] Successfully saved X transactions to database
   ```

## What Gets Captured

From your Qatari bank SMS:

| Field | Example | Detected As |
|-------|---------|------------|
| Currency | QAR 38.00 | Amount: 38.00 |
| Type | "Debit Card was used for" | Type: Debit |
| Merchant | MCDONALDS OLD AIRPOR | Description |
| Date | 10-Apr-26 | Date |
| Balance | QAR 17,189.73 | Shown in SMS text |

## No Need for LLM (Unless You Want)

The app **doesn't require AI/LLM to work** for your messages because:
- Your bank format has clear keywords ("Debit Card", "was used for", "QAR")
- The app detects these instantly without AI
- AI is only needed if messages **don't** have these keywords

**Optional:** If you want AI to categorize expenses (e.g., "MCDONALDS" → "Food & Dining"), you can:
1. Set up **Ollama locally** or use **OpenAI API**
2. Go to Settings and configure the AI endpoint
3. The app will auto-categorize transactions

## Testing Your Setup

1. **Check if app reads SMS:**
   - Install APK
   - Open Transactions screen
   - Grant SMS permission
   - Refresh

2. **If still no messages:**
   - Tap **"Refresh Transactions"** button
   - Check console logs for errors
   - Make sure you have actual SMS on device

3. **Send yourself a test SMS:**
   ```
   Debit Card **1234 was used for QAR 50.00 at TEST STORE
   ```
   - App should detect it immediately

## Currency Auto-Detection

The app can now automatically detect and extract amounts from:

```
QAR 38.00          ← Detected ✓
38.00 QAR          ← Detected ✓
Balance: QAR 17189 ← Detected ✓
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No messages showing | Grant SMS permission + tap refresh |
| Messages not detected | Ensure SMS has "Debit Card" or "was used for" |
| Wrong amounts | Check SMS has "QAR" before amount |
| Wrong transaction type | Add keywords like "credit", "debit", "received" |

## Next Steps

1. Install the latest APK
2. Grant SMS permission
3. Watch your Qatari transactions auto-populate
4. (Optional) Set up Ollama/OpenAI for AI categorization

Enjoy using Thangu in Qatar! 🇶🇦
