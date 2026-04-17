# Thangu - AI Finance Manager

An intelligent personal finance manager app built with Flutter and Dart that reads SMS, automatically categorizes transactions using AI, and helps you achieve your savings goals.

## Features

### 🤖 AI-Powered Transaction Categorization
- Automatically reads and parses transaction SMS messages
- Uses Ollama/Llama2 AI to categorize transactions intelligently
- Filters out OTPs and non-financial messages
- First run scans full history, subsequent runs only scan new messages

### 📊 Modern Financial Dashboard
- Beautiful, intuitive UI with real-time balance overview
- Account filtering (multiple bank accounts support)
- Date range selector (This Month, Last 30 Days, Custom)
- Income/expense tracking with visual indicators

### 🎯 Budget Tracking
- Set spending limits per category
- Progress tracking with color-coded alerts (75%, 90%, 100%)
- Push notifications for budget thresholds
- Per-category budget management

### 📅 Bill Reminders
- Create recurring bill reminders
- Schedule notifications before due dates
- Support for weekly, monthly, quarterly, yearly recurrence
- Track upcoming and overdue bills

### 💰 Investment Tracking
- Track stocks, ETFs, crypto, bonds, mutual funds
- Portfolio summary with total value
- Profit/loss calculation per investment
- Manual entry for holdings

### 💵 Debt/Loan Tracking
- Track loans and credit
- Monthly payment tracking
- Progress towards payoff
- Interest calculation

### 🎯 Savings Goal Tracking
- Set and track multiple financial goals
- Visual progress bars and percentage completion
- Target date management with countdowns

### 💬 Thangu AI Assistant
- Conversational AI named "Thangu" for financial advice
- Context-aware responses based on your spending patterns
- Budget optimization tips using proven methods (50/30/20 rule)

### 📈 Advanced Analytics & Reporting
- Visual spending analysis with charts
- Category breakdown of expenses
- Daily spending trends
- Search & filter by category
- Export data with share functionality

### 🔒 Privacy-Focused
- All data stored locally on your device
- No personal financial data leaves your phone
- Secure SQLite database

### 🔐 Biometric Security
- Fingerprint/Face recognition authentication
- App locks on background to protect sensitive data
- Optional biometric protection toggle in settings
- Works with all modern Android devices

### 💾 Data Backup & Import
- Export all financial data to JSON format
- Share backups securely
- Import previous backups with file picker
- Complete data portability

### 🎯 Smart Savings Automation
- Automatic end-of-month surplus distribution
- Divides remaining balance across active savings goals
- Monthly rollover tracking to prevent duplicate processing

## Screenshots

 ![Dashboard](./assets/screenshots/dashboard.png)

## Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0+)
- [Ollama](https://ollama.ai/download) (for AI features)

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/henricktomfranco/Thangu.git
   cd Thangu
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Ollama (for AI categorization):
   ```bash
   # Install Ollama from https://ollama.ai
   ollama pull llama2
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Architecture

```
lib/
├── main.dart              # App entry point
├── app_theme.dart         # Centralized theme and styling
├── models/               # Data models
│   ├── transaction.dart  # Transaction data class
│   ├── goal.dart        # Savings goal data class
│   ├── budget.dart     # Budget tracking
│   ├── bill_reminder.dart # Bill reminders
│   ├── investment.dart  # Investment tracking
│   └── debt.dart        # Debt tracking
├── screens/              # UI screens
│   ├── home_screen.dart    # Main dashboard
│   ├── transactions_screen.dart # Transaction management
│   ├── goals_screen.dart  # Goal tracking
│   ├── budget_settings_screen.dart # Budget management
│   ├── bill_reminders_screen.dart # Bill reminders
│   ├── investments_screen.dart # Investment tracking
│   ├── ai_chat_screen.dart # AI chat interface
│   ├── settings_screen.dart # App settings
│   └── analytics_screen.dart # Financial analytics
└── services/              # Business logic
    ├── sms_service.dart    # SMS processing
    ├── ai_service.dart    # Ollama AI integration
    ├── database_service.dart # Local SQLite storage
    ├── notification_service.dart # Push notifications
    ├── export_service.dart  # Data export/import
    └── biometric_service.dart # Biometric authentication
```

## Database Tables

- **transactions**: All financial transactions
- **goals**: Savings goals tracking
- **budgets**: Category-based budgets
- **bill_reminders**: Recurring bill reminders
- **investments**: Investment holdings
- **debts**: Loans and credit tracking

## Features in Detail

### SMS Transaction Processing
- Reads SMS from banks and financial institutions
- Extracts transaction amount, type, description
- Filters out OTPs and authentication codes
- First run: scans 90 days of history
- Subsequent runs: scans only new messages

### Budget Alerts
- 75% threshold: Warning notification
- 90% threshold: Critical notification  
- 100%+ threshold: Exceeded notification

### Bill Reminders
- Schedule notifications X days before due
- Recurrence: weekly, monthly, quarterly, yearly
- Push notifications via flutter_local_notifications

### Data Export
- Export to CSV format
- Share via system share sheet
- Include all transactions and settings

## Development

### Building for Release
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## Version History

- v1.0.4: Biometric security, data import/export, smart savings automation
- v1.0.2: Investment & Debt tracking, category filter, export with share
- v1.0.1: Budget system, bill reminders, notifications
- v1.0.0: Initial release with AI categorization

## License

MIT License

## Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Ollama](https://ollama.ai/) - Local LLM deployment
- [SQLite](https://www.sqlite.org/) - Local database