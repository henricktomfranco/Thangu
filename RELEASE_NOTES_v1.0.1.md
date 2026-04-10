# Thangu v1.0.1 Release Notes

**Release Date:** April 10, 2026  
**Version:** 1.0.1 (Build Code: 2)  
**APK Size:** 50.6 MB  
**Min Android:** 5.0 (API 21)  
**Target Android:** Latest  

## 🎯 Overview

**Thangu** is an AI-powered personal finance manager that automatically reads SMS messages from your bank and categorizes financial transactions. Perfect for tracking spending in multiple currencies, including QAR (Qatari Riyal).

## ✨ New in v1.0.1

### Smart Merchant Extraction
- Intelligently extracts merchant names from SMS
- Example: `"Debit Card was used for QAR 38.00 at MCDONALDS OLD AIRPOR"` → Shows as `"MCDONALDS OLD AIRPOR"`
- Works with international bank message formats

### AI-Powered Categorization (Two-Level)
1. **Level 1 (Instant):** Keyword matching with 100+ merchant patterns
   - No AI needed, works offline
   - Matches merchants instantly
   
2. **Level 2 (Advanced):** AI categorization
   - Uses Ollama or OpenAI API (optional)
   - Understands merchant context for accurate categories
   - Fallback to keywords if AI unavailable

### International Currency Support
Automatically detects and extracts amounts from:
- **QAR** - Qatari Riyal ✓ Primary focus
- **AED** - UAE Dirham
- **SAR** - Saudi Riyal
- **USD** - US Dollar
- **EUR** - Euro
- **GBP** - British Pound
- **INR** - Indian Rupee
- **Rs./₹** - Legacy formats

### Enhanced User Experience
- **Runtime Permission Requests** - Asks for SMS access when needed, not at install
- **User-Friendly Messages** - Clear explanations of what went wrong
- **Better Empty State** - Shows "Grant SMS Permission" button instead of just "No transactions"
- **Comprehensive Logging** - Detailed console output for debugging

### Qatar Bank Format Support
Optimized for messages like:
```
Debit Card **6260 
was used for QAR 38.00
at MCDONALDS OLD AIRPOR
at 00:57
10-Apr-26
Balance: QAR 17,189.73
```

## 📋 Complete Feature Set

### SMS Reading
- ✓ Real-time SMS capture via BroadcastReceiver
- ✓ Historical SMS loading (past 90 days)
- ✓ Auto-load on app startup
- ✓ Duplicate detection and prevention
- ✓ OTP/PIN/CVV redaction for security

### Transaction Management
- ✓ Amount extraction (multiple currency formats)
- ✓ Transaction type detection (debit/credit)
- ✓ Date parsing
- ✓ Merchant name extraction
- ✓ Full CRUD operations via SQLite

### Smart Categorization
**Supported Categories:**
- Food & Dining
- Transportation
- Shopping
- Entertainment
- Bills & Utilities
- Groceries
- Healthcare
- Income
- Transfer
- Education
- Travel
- Personal Care
- Gifts & Donations
- Fees & Charges
- Investment
- Other

### Analytics & Goals
- ✓ Transaction dashboard with charts
- ✓ Category-wise expense breakdown
- ✓ Goals tracking system
- ✓ Monthly insights
- ✓ Data export capability

### Technical Features
- ✓ Local SQLite database (no cloud sync)
- ✓ Android 5.0+ compatibility
- ✓ Flutter 3.41.6 with Dart 3.11.4
- ✓ Method channels for native SMS access
- ✓ Kotlin BroadcastReceiver implementation
- ✓ Java 17 compilation support

## 🚀 Getting Started

### Installation
1. Download APK: `build/app/outputs/flutter-apk/app-release.apk`
2. Install on Android 5.0+ device
3. Open Thangu app

### First Run
1. Open **Transactions** screen
2. Tap **"Grant SMS Permission"** button
3. Accept Android permission prompt
4. Transactions will auto-load from past 90 days

### Optional: AI Categorization
1. Set up **Ollama** locally OR use **OpenAI API key**
2. Go to app **Settings**
3. Configure AI endpoint
4. App will auto-categorize transactions

## 📊 What Gets Captured

For each SMS message:
| Field | Example | Status |
|-------|---------|--------|
| Amount | 38.00 | ✓ Extracted |
| Currency | QAR | ✓ Detected |
| Type | Debit/Credit | ✓ Detected |
| Merchant | MCDONALDS OLD AIRPOR | ✓ Extracted |
| Date | 10-Apr-26, 00:57 | ✓ Parsed |
| Category | Food & Dining | ✓ AI-assigned |

## 🔧 Technical Stack

**Frontend:**
- Flutter 3.41.6
- Dart 3.11.4 SDK
- Material Design 3

**Backend:**
- SQLite 3 (local persistence)
- Native Android SMS access (Telephony provider)
- Method channels for Flutter ↔ Android communication

**Dependencies:**
- `sqflite: ^2.3.0` - Database
- `http: ^1.1.0` - API calls (for AI)
- `shared_preferences: ^2.2.0` - User settings
- `path_provider: ^2.1.0` - File paths
- `fl_chart: ^0.66.0` - Analytics charts
- `intl: ^0.17.0` - Internationalization

**Android:**
- Kotlin for BroadcastReceiver
- Java 17 compilation
- API 21+ (Android 5.0+)
- Gradle 8.14

## 📱 Permissions Required

- `READ_SMS` - Read SMS messages
- `RECEIVE_SMS` - Capture incoming messages
- `INTERNET` - Connect to AI services (optional)
- `QUERY_ALL_PACKAGES` - Query SMS provider

## 🐛 Known Limitations

1. **AI Categorization Requires Setup**
   - App works without AI (uses keywords)
   - AI requires Ollama local server or OpenAI key
   - Keyword matching is sufficient for most use cases

2. **SMS Pattern Matching**
   - Works best with standard bank SMS formats
   - Custom/non-standard formats may not be recognized
   - Use AI categorization for edge cases

3. **Historical SMS**
   - Limited to 90 days by default (configurable)
   - Older messages requires manual entry

4. **Timezone**
   - Uses device timezone for SMS timestamps
   - No explicit timezone override

## 📖 Documentation

- [QATAR_SETUP_GUIDE.md](QATAR_SETUP_GUIDE.md) - Qatar-specific setup
- [TRANSACTIONS_TROUBLESHOOTING.md](TRANSACTIONS_TROUBLESHOOTING.md) - Debugging guide
- [SMS_IMPLEMENTATION_GUIDE.md](SMS_IMPLEMENTATION_GUIDE.md) - Technical details

## 🔄 What Changed Since v1.0.0

### New Features
- Smart merchant name extraction
- Two-level AI categorization system
- Runtime permission requests
- International currency support (QAR, AED, SAR, etc.)
- 100+ merchant keyword patterns

### Improvements
- Better transaction descriptions (clean merchant names)
- Enhanced error messages and logging
- Improved empty state UI
- More robust SMS parsing
- Better AI prompt engineering

### Fixes
- Fixed random text appearing as transaction names
- Fixed permission handling on Android 6.0+
- Better fallback when AI unavailable

## 🙏 Support & Feedback

For issues or feature requests, visit the GitHub repository:
https://github.com/henricktomfranco/Thangu

## 📄 License

[Add your license here]

---

**Happy tracking! 💰**
