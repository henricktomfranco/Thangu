# Thangu - AI Finance Manager

An intelligent personal finance manager app built with Flutter and Dart that reads SMS, automatically categorizes transactions using AI, and helps you achieve your savings goals.

## Features

### 🤖 AI-Powered Transaction Categorization
- Automatically reads and parses transaction SMS messages
- Uses Ollama/Llama2 AI to categorize transactions intelligently
- Learns from your corrections to improve accuracy over time
- Fallback to manual categorization when AI is uncertain

### 📊 Modern Financial Dashboard
- Beautiful, intuitive UI with real-time balance overview
- Income/expense tracking with visual indicators
- Quick access to key features (transactions, goals, AI chat, analytics)

### 🎯 Savings Goal Tracking
- Set and track multiple financial goals
- Visual progress bars and percentage completion
- Target date management with countdowns
- Categorized goals (Emergency Fund, Vacation, Purchase, etc.)

### 💬 Thangu AI Assistant
- Conversational AI named "Thangu" for financial advice
- Context-aware responses based on your spending patterns
- Budget optimization tips using proven methods (50/30/20 rule)
- Personalized savings recommendations

### 🔒 Privacy-Focused
- All data stored locally on your device
- No personal financial data leaves your phone
- Secure SQLite database with encryption-ready architecture
- Works completely offline (except for optional AI queries)

## Screenshots

![Dashboard](/assets/screenshots/dashboard.png)
![Transactions](/assets/screenshots/transactions.png)
![Goals](/assets/screenshots/goals.png)
![AI Chat](/assets/screenshots/ai_chat.png)

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
   # Install Ollama from https://ollama.ai/download
   ollama pull llama2  # Download the Llama 2 model
   # Ollama runs automatically on localhost:11434
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Architecture

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── transaction.dart   # Transaction data class
│   └── goal.dart          # Savings goal data class
├── screens/               # UI screens
│   ├── home_screen.dart   # Main dashboard
│   ├── transactions_screen.dart # Transaction management
│   ├── goals_screen.dart  # Goal tracking
│   └── ai_chat_screen.dart # AI chat interface
├── services/              # Business logic
│   ├── sms_service.dart   # SMS parsing simulation
│   ├── ai_service.dart    # Ollama AI integration
│   └── database_service.dart # Local SQLite storage
├── widgets/               # Reusable UI components
│   ├── transaction_card.dart
│   ├── goal_card.dart
│   ├── category_selector.dart
│   └── ...                # Other UI components
└── utils/                 # Utility functions
```

## Features in Detail

### SMS Transaction Processing
The app simulates reading SMS messages from banks and financial institutions to extract:
- Transaction amount
- Type (credit/debit)
- Description
- Sender information

### AI Categorization
Using Ollama with Llama 2 model:
- Analyzes transaction description, amount, and sender
- Matches transactions to predefined categories
- Provides confidence scores for categorization
- Allows manual override when needed

### Savings Goals
- Create custom goals with target amounts and dates
- Track progress with visual indicators
- Automatic calculation of completion percentage
- Goal categorization for better organization

### AI Financial Assistant
- Provides personalized financial advice
- Analyzes your spending patterns
- Offers budget optimization suggestions
- Answers specific financial questions

## Data Storage

All financial data is stored locally using SQLite:
- Transactions table: Stores all parsed transactions
- Goals table: Tracks savings goals and progress
- No data is sent to external servers (except optional AI queries to your local Ollama instance)

## Customization

### Adding Custom Categories
1. Go to any transaction
2. Tap to edit category
3. Select "Add New Category"
4. Enter your custom category name

### Adjusting AI Sensitivity
The AI service in `lib/services/ai_service.dart` can be adjusted:
- Change the `_modelName` to use different Ollama models
- Modify categorization prompts for better accuracy
- Adjust confidence thresholds

## Development

### Running Tests
```bash
flutter test
```

### Building for Release
```bash
flutter build apk --release
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Ollama](https://ollama.ai/) - Local LLM deployment
- [Llama 2](https://ai.meta.com/llama/) - AI model
- [SQLite](https://www.sqlite.org/) - Local database
- [sqflite](https://pub.dev/packages/sqflite) - Flutter SQLite plugin

---

Built with ❤️ for better financial management.