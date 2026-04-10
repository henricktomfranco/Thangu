import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class AiService {
  // Configuration
  static const String defaultOllamaUrl = 'http://127.0.0.1:11434';

  // Model configuration
  String _baseUrl = defaultOllamaUrl;
  String _modelName = 'llama2';
  String _apiKey = '';
  bool _isOllama = true; // true for Ollama, false for OpenAI compatible

  // Categories that the AI can recognize
  static const List<String> _knownCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Groceries',
    'Healthcare',
    'Income',
    'Transfer',
    'Education',
    'Travel',
    'Personal Care',
    'Gifts & Donations',
    'Fees & Charges',
    'Investment',
    'Other'
  ];

  // Initialize service with saved settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('ai_base_url') ?? defaultOllamaUrl;
    _modelName = prefs.getString('ai_model') ?? 'llama2';
    _apiKey = prefs.getString('ai_api_key') ?? '';
    _isOllama = prefs.getBool('ai_is_ollama') ?? true;
  }

  // Update configuration
  void updateConfiguration({
    String? baseUrl,
    String? modelName,
    String? apiKey,
    bool? isOllama,
  }) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (modelName != null) _modelName = modelName;
    if (apiKey != null) _apiKey = apiKey;
    if (isOllama != null) _isOllama = isOllama!;
  }

  // Save configuration to persistent storage
  Future<void> saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_base_url', _baseUrl);
    await prefs.setString('ai_model', _modelName);
    await prefs.setString('ai_api_key', _apiKey);
    await prefs.setBool('ai_is_ollama', _isOllama);
  }

  // Build URL for API call
  String _buildApiUrl() {
    if (_isOllama) {
      return '$_baseUrl/api/generate';
    } else {
      // For OpenAI compatible endpoints
      return '$_baseUrl/v1/chat/completions';
    }
  }

  // Build headers for API call
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) {
      if (_isOllama) {
        headers['Authorization'] = 'Bearer $_apiKey';
      } else {
        headers['Authorization'] = 'Bearer $_apiKey';
      }
    }
    return headers;
  }

  // Build request body
  Map<String, dynamic> _buildRequestBody(String prompt) {
    if (_isOllama) {
      return {
        'model': _modelName,
        'prompt': prompt,
        'stream': false,
      };
    } else {
      return {
        'model': _modelName,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      };
    }
  }

  String _buildCategorizationPrompt(Transaction transaction) {
    return '''
You are Thangu, an AI financial assistant. Categorize this transaction based on the merchant name and transaction details.

Transaction Details:
- Merchant/Description: "${transaction.description}"
- Amount: ${transaction.amount}
- Type: ${transaction.type}
- Sender: ${transaction.sender}

Available Categories:
${_knownCategories.join(', ')}

Instructions:
1. Look at the merchant name and understand what type of business it is
2. Match to the most appropriate category
3. Be decisive - choose ONE category only
4. If the merchant name is unclear, make your best guess
5. Respond with ONLY the category name, nothing else
6. If it's income (salary, bonus, refund), use "Income"
7. If it's money movement (transfer, payment), use "Transfer"

Examples:
- "MCDONALDS" → Food & Dining
- "CARREFOUR MALL" → Groceries
- "UBER" → Transportation
- "NETFLIX" → Entertainment
- "SALARY DEPOSIT" → Income

Category:''';
  }

  Future<String?> categorizeTransaction(Transaction transaction) async {
    try {
      final prompt = _buildCategorizationPrompt(transaction);

      final url = _buildApiUrl();
      final headers = _buildHeaders();
      final body = _buildRequestBody(prompt);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String aiResponse = responseData['response']?.trim() ?? '';

        // Validate the response is a known category
        if (_knownCategories.contains(aiResponse)) {
          return aiResponse;
        } else {
          // Try to find closest match or default to Other
          final String normalizedResponse =
              aiResponse.replaceAll('&', 'and').replaceAll('/', ' & ').trim();

          final String? matchedCategory = _knownCategories.firstWhere(
            (category) =>
                category
                    .toLowerCase()
                    .contains(normalizedResponse.toLowerCase()) ||
                normalizedResponse
                    .toLowerCase()
                    .contains(category.toLowerCase()),
            orElse: () => 'Other',
          );

          return matchedCategory;
        }
      } else {
        throw Exception(
            'Failed to categorize transaction: ${response.statusCode}');
      }
    } catch (e) {
      // If API is not available or any error occurs, return null
      // so the app can fall back to manual categorization
      return null;
    }
  }

  /// General purpose AI response generator
  Future<String> generateResponse(String prompt) async {
    try {
      final url = _buildApiUrl();
      final headers = _buildHeaders();
      final body = _buildRequestBody(prompt);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (_isOllama) {
          return responseData['response']?.toString().trim() ?? '';
        } else {
          // OpenAI format
          final choices = responseData['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']['content']?.toString().trim() ?? '';
          }
        }
      }
      throw Exception('Failed to get response: ${response.statusCode}');
    } catch (e) {
      print('[AiService] Error generating response: $e');
      rethrow;
    }
  }

  // Method to get financial advice from Thangu AI
  Future<String> getFinancialAdvice({
    required double monthlyIncome,
    required double monthlyExpenses,
    required List<Transaction> recentTransactions,
  }) async {
    try {
      final String prompt = '''
You are Thangu, a friendly and knowledgeable AI financial assistant. 
Provide helpful, personalized financial advice based on the user's financial situation.

User's Financial Snapshot:
- Monthly Income: \$${monthlyIncome.toStringAsFixed(2)}
- Monthly Expenses: \$${monthlyExpenses.toStringAsFixed(2)}
- Savings Rate: ${((monthlyIncome - monthlyExpenses) / monthlyIncome * 100).toStringAsFixed(1)}%

Recent Transaction Patterns:
${_summarizeRecentTransactions(recentTransactions)}

Provide advice on:
1. Budget optimization (consider 50/30/20 rule or similar)
2. Savings opportunities
3. Areas to review for potential savings
4. One actionable tip for improving financial health

Keep your response friendly, encouraging, and under 150 words.
''';

      final url = _buildApiUrl();
      final headers = _buildHeaders();
      final body = _buildRequestBody(prompt);

      final response = await http.post(
        Uri.parse(_buildApiUrl()),
        headers: _buildHeaders(),
        body: json.encode(_buildRequestBody(prompt)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['response']?.trim() ??
            "I'm having trouble connecting to my knowledge base right now. Let's focus on tracking your transactions!";
      } else {
        throw Exception(
            'Failed to get financial advice: ${response.statusCode}');
      }
    } catch (e) {
      return _getFallbackAdvice(monthlyIncome, monthlyExpenses);
    }
  }

  String _summarizeRecentTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) return "No recent transactions available.";

    // Group by category and calculate totals
    final Map<String, double> categoryTotals = {};
    for (final txn in transactions.where((t) => t.type == 'debit')) {
      categoryTotals.update(txn.category, (value) => value + txn.amount,
          ifAbsent: () => txn.amount);
    }

    final StringBuffer buffer = StringBuffer();
    categoryTotals.forEach((category, amount) {
      buffer.writeln('- $category: \$${amount.toStringAsFixed(2)}');
    });

    return buffer.toString();
  }

  String _getFallbackAdvice(double monthlyIncome, double monthlyExpenses) {
    final double savings = monthlyIncome - monthlyExpenses;
    final double savingsRate = (savings / monthlyIncome) * 100;

    if (savingsRate >= 20) {
      return "Great job! You're saving ${savingsRate.toStringAsFixed(1)}% of your income. Consider investing a portion of your savings for long-term growth.";
    } else if (savingsRate >= 10) {
      return "You're saving ${savingsRate.toStringAsFixed(1)}% of your income. Try to increase this to 20% by reviewing your discretionary spending.";
    } else if (savings > 0) {
      return "You're saving ${savingsRate.toStringAsFixed(1)}% of your income. Look for small expenses to reduce and aim for at least 10% savings.";
    } else {
      return "Your expenses exceed your income. Review your spending categories to identify areas where you can cut back. Even small changes can make a big difference.";
    }
  }
}
