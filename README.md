# Thangu - AI Finance Manager

A modern, Qatar-focused AI personal finance app built with Flutter. Automatically tracks spending from bank SMS, provides proactive financial insights, and helps you save smarter.

## ✨ Key Features

### 💰 Safe to Spend
The single most important number — how much you can actually spend this week after accounting for bills, subscriptions, savings goals, and emergency buffer.

### 📱 Automatic SMS Transaction Import
- Reads bank SMS from **Qatar banks** (QNB, CBQ, Dukhan, Masraf Al Rayan, Doha Bank, Ahli, Vodafone, Ooredoo)
- **Arabic digit support** (٠-٩) for mixed-language SMS
- **Balance enquiry detection** — skips SMS that only show balance
- **Hash-based deduplication** (FNV-1a) — never processes the same SMS twice
- Queries both **inbox and sent** SMS folders

### 🔄 Subscription Detection
- Automatically detects recurring charges from transaction patterns
- Shows monthly total, next predicted charge date
- Flags **unused subscriptions** (90+ days inactive)
- Smart categorization (streaming, music, cloud, fitness, telecom)

### 🌍 Remittance Tracker
- Auto-detects money transfers to **10+ currencies** (INR, PHP, NPR, BDT, PKR, EGP, LKR, KES, ETB, JOD)
- Tracks **12+ providers** (Al Dar, Al Fardan, Lulu Exchange, Western Union, QNB, CBQ, etc.)
- Monthly trend visualization (6-month bar chart)
- Total sent, monthly average, top destination & provider

### 🤖 AI-Powered Categorization
- Uses Ollama/Llama2 or OpenAI to intelligently categorize transactions
- Smart fallback detection with 12+ category keywords
- Filters out OTPs and non-financial messages

### 📊 Modern Financial Dashboard
- **Corrected Balance** — set your actual balance anytime (no date cutoff)
- Date range selector (This Month, Last 30 Days, Custom)
- Income/expense tracking with visual indicators
- Account filtering (multiple bank accounts)
- Transaction verification queue (review SMS imports before confirming)

### 🎯 Budget Tracking
- Per-category spending limits
- Progress tracking with color-coded alerts (75%, 90%, 100%)
- Push notifications for budget thresholds

### 📅 Bill Reminders
- Recurring bill reminders (weekly, monthly, quarterly, yearly)
- Scheduled notifications before due dates
- Track upcoming and overdue bills

### 💬 Thangu AI Assistant
- Conversational AI for financial advice
- Context-aware responses based on spending patterns
- Budget optimization tips (50/30/20 rule)

### 📈 Advanced Analytics
- Visual spending analysis with charts
- Category breakdown and daily trends
- Search & filter transactions
- CSV/JSON export with share functionality

### 🔐 Security & Privacy
- Biometric authentication (fingerprint/face)
- App locks on background
- All data stored locally — nothing leaves your device
- Secure SQLite database with migration support

## 🏗️ Architecture

```
lib/
├── main.dart                     # App entry point
├── app_theme.dart                # Glassmorphic dark theme
├── models/                       # Data models
│   ├── transaction.dart          # Transaction with merchant, verification
│   ├── goal.dart                 # Savings goals
│   ├── budget.dart               # Budget with auto-suggested limits
│   ├── bill_reminder.dart        # Recurring bills
│   ├── investment.dart           # Investment holdings
│   ├── debt.dart                 # Loan tracking
│   └── account_summary.dart      # Multi-account support
├── screens/                      # UI screens
│   ├── home_screen.dart          # Dashboard with Safe to Spend
│   ├── onboarding_screen.dart    # 4-step onboarding flow
│   ├── subscriptions_screen.dart # Subscription detection UI
│   ├── remittances_screen.dart   # Money sent home tracker
│   ├── transaction_verification_screen.dart  # Review SMS imports
│   ├── transactions_screen.dart  # Transaction management
│   ├── goals_screen.dart         # Savings goals
│   ├── budget_settings_screen.dart
│   ├── bill_reminders_screen.dart
│   ├── investments_screen.dart
│   ├── ai_chat_screen.dart
│   ├── settings_screen.dart
│   ├── analytics_screen.dart
│   └── debug_screen.dart
└── services/                     # Business logic
    ├── sms_parser.dart           # Unified SMS parsing engine (DRY)
    ├── bank_format_registry.dart # Qatar bank format definitions
    ├── safe_to_spend_calculator.dart  # Safe to Spend + subscription detection
    ├── remittance_tracker.dart   # Remittance detection & analytics
    ├── sms_history_service.dart  # Historical SMS scanning
    ├── enhanced_sms_service.dart # Real-time SMS listener
    ├── database_service.dart     # SQLite with 8-version migrations
    ├── ai_service.dart           # Ollama/OpenAI integration
    ├── proactive_ai_service.dart # Proactive savings nudges
    ├── notification_service.dart # Smart alerts
    ├── account_service.dart      # Multi-account detection
    ├── export_service.dart       # CSV/JSON backup & restore
    └── biometric_service.dart    # Fingerprint/face auth
```

## 📋 Database Schema

| Table | Purpose |
|---|---|
| `transactions` | All financial transactions (with merchant, sms_id, is_verified) |
| `processed_sms` | SMS tracking for deduplication (with fingerprint) |
| `goals` | Savings goals with progress tracking |
| `budgets` | Category-based budgets with periods |
| `bill_reminders` | Recurring bill reminders |
| `investments` | Investment holdings (stocks, crypto, etc.) |
| `debts` | Loan and credit tracking |

## 🚀 Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0+)
- [Ollama](https://ollama.ai/download) (for local AI features)

### Setup
```bash
git clone https://github.com/henricktomfranco/Thangu.git
cd Thangu
flutter pub get
flutter run
```

### AI Setup (Optional)
```bash
# Install Ollama from https://ollama.ai
ollama pull llama2
```

### Build for Release
```bash
flutter build apk --release
```

## 🏦 Supported Qatar Banks

| Bank | SMS Senders |
|---|---|
| Qatar National Bank (QNB) | QNB, QNBALERT |
| Commercial Bank (CBQ) | CBQ, CBQALERT, COMMERCIAL |
| Dukhan Bank | DUKHAN, DUKHANBANK |
| Masraf Al Rayan | MASRAF, ALRAYAN, RAYAN |
| Doha Bank | DOHA, DOHABANK |
| Ahli Bank | ABQ, AHLI |
| Vodafone Qatar | VODAFONE, VF |
| Ooredoo Qatar | OOREDOO, OO |

Adding a new bank: update `BankFormatRegistry` — 5 lines of code.

## 📱 Onboarding Flow

1. **Welcome** — Value proposition
2. **Goal Selection** — Save more, Track spending, Send money home, Pay off debt
3. **Permission Explanation** — Shows exactly what IS and ISN'T accessed
4. **Optional Balance Setup** — Set corrected balance or skip

## 🔧 SMS Parsing Engine

The unified `SmsParser` replaces duplicated code across services:

| Capability | Details |
|---|---|
| Financial detection | OTP exclusion, balance enquiry skip, keyword matching |
| Amount extraction | Multi-currency (QAR, INR, USD, EUR, GBP), Arabic digits, balance context |
| Merchant extraction | Regex patterns ("at MERCHANT", "POS purchase at MERCHANT") |
| Type detection | Credit vs debit based on keywords |
| Fingerprinting | FNV-1a hash (sender + timestamp + body preview) |
| AI categorization | Ollama/OpenAI with smart fallback |

## 📊 Safe to Spend Calculation

```
Safe to Spend = Current Balance
              - Upcoming Bills (next 7 days)
              - Active Subscriptions (prorated weekly)
              - Savings Goal Contributions (prorated weekly)
              - Emergency Buffer (10%)
```

Health levels: 🟢 Healthy (>30%) · 🟡 Tight (10-30%) · 🔴 Critical (<10%)

## 🌍 Remittance Detection

Auto-detects transfers using 30+ keywords covering:
- **Providers**: Al Dar, Al Fardan, Lulu Exchange, Western Union, MoneyGram, bank exchanges
- **Currencies**: INR, PHP, NPR, BDT, PKR, EGP, LKR, KES, ETB, JOD
- **Countries**: India, Philippines, Nepal, Bangladesh, Pakistan, Egypt, Sri Lanka, Kenya, Ethiopia

## 🔄 Subscription Detection

Analyzes transaction patterns to find recurring charges:
- Groups transactions by merchant
- Checks for regular intervals (weekly, monthly, yearly)
- Validates amount consistency (within 15% variance)
- Flags unused subscriptions (90+ days since last charge)

## 📈 Version History

- **v1.0.4**: Safe to Spend, subscription detection, remittance tracker, redesigned onboarding, unified SMS parser, bank format registry, transaction verification UI, corrected balance (no date cutoff), database migration v8
- **v1.0.3**: Corrected balance, hash-based SMS deduplication, Arabic digit support, merchant extraction
- **v1.0.2**: Investment & Debt tracking, category filter, export with share
- **v1.0.1**: Budget system, bill reminders, notifications
- **v1.0.0**: Initial release with AI categorization

## 📄 License

MIT License

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Ollama](https://ollama.ai/) - Local LLM deployment
- [SQLite](https://www.sqlite.org/) - Local database
- [sqflite](https://pub.dev/packages/sqflite) - Flutter SQLite plugin
