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

### 📈 Advanced Analytics & Reporting
- Visual spending analysis with charts
- Category breakdown of expenses
- Daily spending trends
- Export data for backup or further analysis

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
   git clone https://github.com/your-username/Thangu.git
   cd Thangu
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Ollama (for AI categorization):
   ```bash
   # Install Ollama from https://ollama.ai
   ollama pull llama2  # Download the Llama 2 model
   # Ollama runs automatically on localhost:11434
   ```

4. Run the app:
   ```bash
   # For mobile
   flutter run
   
   # For web
   flutter run -d web
   ```

## Architecture

```
lib/
├── main.dart              # App entry point
├── app_theme.dart         # Centralized theme and styling
├── models/                # Data models
│   ├── transaction.dart   # Transaction data class
│   └── goal.dart          # Savings goal data class
├── screens/               # UI screens
│   ├── home_screen.dart   # Main dashboard
│   ├── transactions_screen.dart # Transaction management
│   ├── goals_screen.dart  # Goal tracking
│   ├── ai_chat_screen.dart # AI chat interface
│   ├── settings_screen.dart # App settings
│   ├── analytics_screen.dart # Financial analytics and reporting
│   └── category_management_screen.dart # Category management
│   └── category_selector.dart # Category selection UI
├── services/              # Business logic
│   ├── sms_service.dart   # SMS parsing simulation
│   ├── real_sms_service.dart # Real SMS processing (to be implemented)
│   ├── ai_service.dart    # Ollama AI integration
│   ├── database_service.dart # Local SQLite storage
│   └── export_service.dart # Data export/import functionality
├── widgets/               # Reusable UI components
│   ├── transaction_card.dart
│   ├── goal_card.dart
│   └── ...                # Other UI components
└── utils/                 # Utility functions
```

## AI Configuration

The app supports both Ollama (local AI) and OpenAI compatible APIs:

1. **Ollama Setup**:
   - Install Ollama from https://ollama.ai
   - Pull a model: `ollama pull llama2` (or mistral, etc.)
   - Default endpoint: http://127.0.0.1:11434

2. **OpenAI Compatible APIs**:
   - Set your API endpoint in Settings
   - Add your API key for authentication
   - Choose from supported models

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

### Category Management
- Create and manage custom categories
- Assign colors and icons to categories
- Export/import category configurations
- Backup all financial data

### Analytics & Reporting
- Visual spending analysis with charts
- Category breakdown of expenses
- Daily spending trends
- Export data for backup or further analysis

## Data Storage

All financial data is stored locally using SQLite:
- Transactions table: Stores all parsed transactions
- Goals table: Tracks savings goals and progress
- Categories table: Custom category definitions
- No data is sent to external servers (except optional AI queries to your local Ollama instance)

## Customization

### Adding Custom Categories
1. Go to Settings > Manage Categories
2. Tap "Add New Category"
3. Enter your custom category name
4. Optionally specify an icon and color
5. Tap "Add Category" to save

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
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web
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
- [charts_flutter](https://pub.dev/packages/charts_flutter) - Charting library

---