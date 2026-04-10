# Troubleshooting: No Transactions Showing

## Quick Checklist

- [ ] **Have you granted SMS permission?** The app WON'T see any messages without this
- [ ] **Does your device have SMS messages?** The app can only read SMS that exist on your phone
- [ ] **Are you using Android 6.0+?** On modern Android, the app must REQUEST permissions at runtime
- [ ] **Check app logs** - Look at the detailed startup messages

## Step-by-Step Debug Process

### Step 1: Check Console Logs
When you run the app, open the Flutter debug console and look for messages like:

```
[Startup] Loading historical SMS messages...
[SmsHistory] Requesting SMS from last 90 days
[SmsHistory] Received X SMS messages from platform
[SmsHistory] Successfully saved X transactions to database
```

**If you see 0 messages:** The app likely doesn't have SMS permission or no SMS exists.

### Step 2: Grant SMS Permission (Most Common Fix)

1. **On the Transactions screen**, tap the **"Grant SMS Permission"** button
2. **Accept the permission prompt** from Android
3. **Tap "Refresh Transactions"** 
4. Transactions should now appear

### Step 3: Check Manual Permission Settings

If the button doesn't work:
1. Go to **Settings** → **Apps** → **Thangu**
2. Tap **Permissions**
3. Find **SMS** and tap it
4. Select **Allow**
5. Return to app and refresh

### Step 4: Verify Your Device Has SMS Messages

- The app reads SMS from your **SMS Inbox only**
- If you have 0 text messages on your device, the app will show 0 transactions
- **Send yourself a test SMS** with content like: "Credited Rs. 1000" or "Debit Rs. 500"

### Step 5: Check Android Version & API Level

- The app requires **Android 5.0 (API 21)** or higher
- On **Android 15**, make sure you've disabled Google Play Protect (if it blocked installation)

## What the App is Looking For

The app searches SMS messages for patterns like:

```
Rs. 1000        ← Detects amount
₹ 500          ← Also supports rupee symbol
INR 2000       ← And INR prefix

credit         ← Categorizes as income
received
deposited

debit          ← Categorizes as expense
(anything else defaults to debit)
```

## Expected Behavior

1. **On App Startup:**
   - App loads SMS from last **90 days**
   - Shows progress in console: `[Startup] ✓ Loaded X historical transactions`

2. **New Messages:**
   - When you **receive SMS**, app automatically captures it
   - Appears in Transactions page within seconds

3. **Database Persistence:**
   - All transactions saved locally
   - Survives app restart
   - Can be manually categorized

## Logs Location

**Before Transactions Load:**
1. Open Android Studio
2. Run: `adb logcat | grep "SmsHistory\|Startup"`
3. Look for detailed error messages

## Common Issues & Solutions

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| "No transactions found" on first launch | Permission not granted | Grant SMS permission in the pop-up |
| Permission button doesn't work | Android permission denied in settings | Manually grant in Settings > Apps > Thangu |
| App shows 0 after granting permission | No SMS on device | Send test SMS to device |
| App crashes on transactions page | Database error | Reinstall app and clear app data |
| Historical SMS not loading | Old messages on device don't match pattern | App only recognizes Rs./₹/INR amounts |

## Test with Sample SMS

Send yourself a text message like:
```
Your bank account has been credited with Rs. 500 
on 2024-01-15 at 10:30 AM. Balance: Rs. 15,000
```

The app should:
1. Extract: **Rs. 500**
2. Extract type: **credit** (contains "credited")
3. Save as transaction

## Still Not Working?

1. **Clear app data:**
   ```
   adb shell pm clear com.example.thangu
   ```

2. **Rebuild and reinstall:**
   ```
   flutter clean
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Check MainActivity.kt logs:**
   ```
   adb logcat | grep "MainActivity"
   ```

4. **Verify database exists:**
   Check if `thangu.db` is created in device's app directory

## Next Steps

Once transactions appear:
1. They'll be categorized by AI (if Ollama/OpenAI is configured)
2. You can manually recategorize them
3. Analytics will auto-populate
4. Goals can be set up
