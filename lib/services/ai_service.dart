import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/investment.dart';
import '../models/budget.dart';

class AiService {
  // Singleton — ensures settings propagate to all consumers (Issue 19)
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

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
    if (isOllama != null) _isOllama = isOllama;
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
      return '$_baseUrl/v1/chat/completions';
    }
  }

  // Build headers for API call
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
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

  /// Fetch available models from configured server
  Future<List<String>> fetchAvailableModels(String serverUrl,
      {bool isOllama = true, String? apiKey}) async {
    try {
      final String modelsUrl =
          isOllama ? '$serverUrl/api/tags' : '$serverUrl/v1/models';

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http
          .get(Uri.parse(modelsUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<String> models = [];

        if (isOllama) {
          final modelsList = responseData['models'] as List?;
          if (modelsList != null) {
            for (final model in modelsList) {
              final modelName = model['name'] as String?;
              if (modelName != null) models.add(modelName);
            }
          }
        } else {
          final dataList = responseData['data'] as List?;
          if (dataList != null) {
            for (final model in dataList) {
              final modelId = model['id'] as String?;
              if (modelId != null) models.add(modelId);
            }
          }
        }
        return models;
      }
      return [];
    } catch (e) {
      print('[AiService] Error fetching models: $e');
      return [];
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
    // Issue 18: skip if already reliably categorized
    if (transaction.isCategorizedByAI && transaction.aiConfidence >= 0.8) {
      return transaction.category;
    }

    try {
      final prompt = _buildCategorizationPrompt(transaction);

      final response = await http
          .post(
            Uri.parse(_buildApiUrl()),
            headers: _buildHeaders(),
            body: json.encode(_buildRequestBody(prompt)),
          )
          .timeout(const Duration(seconds: 15)); // Issue 17: added timeout

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String aiResponse;
        if (_isOllama) {
          aiResponse = responseData['response']?.toString().trim() ?? '';
        } else {
          final choices = responseData['choices'] as List?;
          aiResponse = choices != null && choices.isNotEmpty
              ? choices[0]['message']['content']?.toString().trim() ?? ''
              : '';
        }

        if (_knownCategories.contains(aiResponse)) return aiResponse;

        final String normalizedResponse =
            aiResponse.replaceAll('&', 'and').replaceAll('/', ' & ').trim();
        return _knownCategories.firstWhere(
          (category) =>
              category
                  .toLowerCase()
                  .contains(normalizedResponse.toLowerCase()) ||
              normalizedResponse
                  .toLowerCase()
                  .contains(category.toLowerCase()),
          orElse: () => 'Other',
        );
      } else {
        throw Exception(
            'Failed to categorize transaction: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }

  /// General purpose AI response generator
  Future<String> generateResponse(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(_buildApiUrl()),
            headers: _buildHeaders(),
            body: json.encode(_buildRequestBody(prompt)),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (_isOllama) {
          return responseData['response']?.toString().trim() ?? '';
        } else {
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
- Monthly Income: QAR${monthlyIncome.toStringAsFixed(2)}
- Monthly Expenses: QAR${monthlyExpenses.toStringAsFixed(2)}
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

      // Issue 16: removed duplicate variable declarations — uses helpers directly
      final response = await http
          .post(
            Uri.parse(_buildApiUrl()),
            headers: _buildHeaders(),
            body: json.encode(_buildRequestBody(prompt)),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (_isOllama) {
          return responseData['response']?.trim() ??
              "I'm having trouble connecting to my knowledge base right now. Let's focus on tracking your transactions!";
        } else {
          final choices = responseData['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']['content']?.toString().trim() ??
                _getFallbackAdvice(monthlyIncome, monthlyExpenses);
          }
        }
      }
      throw Exception('Failed to get financial advice: ${response.statusCode}');
    } catch (e) {
      return _getFallbackAdvice(monthlyIncome, monthlyExpenses);
    }
  }

  String _summarizeRecentTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) return "No recent transactions available.";

    final Map<String, double> categoryTotals = {};
    for (final txn in transactions.where((t) => t.type == 'debit')) {
      categoryTotals.update(txn.category, (value) => value + txn.amount,
          ifAbsent: () => txn.amount);
    }

    final StringBuffer buffer = StringBuffer();
    categoryTotals.forEach((category, amount) {
      buffer.writeln('- $category: QAR${amount.toStringAsFixed(2)}');
    });

    return buffer.toString();
  }

  String _getFallbackAdvice(double monthlyIncome, double monthlyExpenses) {
    final double savings = monthlyIncome - monthlyExpenses;
    final double savingsRate =
        monthlyIncome > 0 ? (savings / monthlyIncome) * 100 : 0;

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

  /// Generate personalized savings plan suggestions
  Future<String> getSavingsPlan({
    required double monthlyIncome,
    required double monthlyExpenses,
    required List<Transaction> recentTransactions,
    required List<String> userGoals,
  }) async {
    try {
      final double savings = monthlyIncome - monthlyExpenses;
      final double savingsRate =
          monthlyIncome > 0 ? (savings / monthlyIncome * 100) : 0;

      final categoryBreakdown =
          _summarizeRecentTransactions(recentTransactions);

      final String prompt = '''
You are Thangu, an expert financial planner AI. Create a personalized savings plan for the user.

USER'S FINANCIAL DATA:
- Monthly Income: QAR${monthlyIncome.toStringAsFixed(2)}
- Monthly Expenses: QAR${monthlyExpenses.toStringAsFixed(2)}
- Current Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- User's Goals: ${userGoals.isEmpty ? "None specified" : userGoals.join(", ")}

SPENDING BREAKDOWN:
$categoryBreakdown

TASKS:
1. Recommend a realistic savings plan using the 50/30/20 rule as a guideline
2. Suggest specific amount to save monthly (QAR)
3. Identify top 2-3 spending categories to reduce
4. Provide actionable steps to achieve their goals
5. If they have goals, calculate monthly savings needed

FORMAT:
- Use bullet points for clarity
- Keep it encouraging but realistic
- Include specific numbers and percentages
- Maximum 200 words

User's message: "${userGoals.isEmpty ? "I want to save more money" : userGoals.first}"
''';

      return await generateResponse(prompt);
    } catch (e) {
      return _getFallbackAdvice(monthlyIncome, monthlyExpenses);
    }
  }

  /// Analyze spending patterns and provide insights
  Future<String> analyzeSpendingPatterns({
    required List<Transaction> transactions,
  }) async {
    try {
      if (transactions.isEmpty) {
        return "Start tracking your transactions to get personalized spending insights!";
      }

      final categoryTotals = <String, double>{};
      for (final txn in transactions.where((t) => t.type == 'debit')) {
        categoryTotals.update(txn.category, (value) => value + txn.amount,
            ifAbsent: () => txn.amount);
      }

      if (categoryTotals.isEmpty) {
        return "No expense transactions found yet. Add your first transaction!";
      }

      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final totalExpenses =
          categoryTotals.values.fold<double>(0, (a, b) => a + b);

      final StringBuffer analysis = StringBuffer();
      analysis.writeln("📊 Spending Analysis:\n");
      analysis
          .writeln("*Total Expenses:* QAR ${totalExpenses.toStringAsFixed(2)}\n");
      analysis.writeln("*Top Categories:*");

      for (var i = 0; i < sortedCategories.length && i < 5; i++) {
        final category = sortedCategories[i];
        final percentage = (category.value / totalExpenses * 100);
        analysis.writeln(
            "- ${category.key}: QAR ${category.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)");
      }

      if (sortedCategories.isNotEmpty) {
        final topCategory = sortedCategories.first;
        final topPercentage = (topCategory.value / totalExpenses * 100);
        if (topPercentage > 30) {
          analysis.writeln(
              "\n💡 *Insight:* ${topCategory.key} takes up ${topPercentage.toStringAsFixed(1)}% of spending. Consider reviewing this category for potential savings.");
        }
      }

      return analysis.toString();
    } catch (e) {
      return "Unable to analyze spending patterns right now.";
    }
  }

  /// Calculate optimal monthly savings for a goal
  Future<Map<String, dynamic>> calculateGoalSavings({
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
    required double monthlyIncome,
  }) async {
    final now = DateTime.now();
    final monthsRemaining = targetDate.difference(now).inDays / 30;

    if (monthsRemaining <= 0) {
      return {
        'monthlyNeeded': targetAmount - currentAmount,
        'isFeasible': true,
        'message': 'Goal deadline has passed. Consider extending the date.',
      };
    }

    final remaining = targetAmount - currentAmount;
    final monthlyNeeded = remaining / monthsRemaining;
    final affordable = monthlyIncome * 0.2;

    final isFeasible = monthlyNeeded <= affordable;

    final String message = isFeasible
        ? "Save QAR ${monthlyNeeded.toStringAsFixed(0)}/month to reach your goal."
        : "QAR ${monthlyNeeded.toStringAsFixed(0)}/month exceeds 20% of income (QAR ${affordable.toStringAsFixed(0)}). Consider extending your target date.";

    return {
      'monthlyNeeded': monthlyNeeded,
      'isFeasible': isFeasible,
      'monthsRemaining': monthsRemaining.round(),
      'message': message,
      'recommendedTargetDate': now.add(
          Duration(days: (remaining / (affordable * 0.8) * 30).ceil().round())),
    };
  }

  /// Get AI-powered budget recommendations based on spending history
  Future<List<Map<String, dynamic>>> getBudgetRecommendations({
    required double monthlyIncome,
    required List<Transaction> transactions,
    required List<Budget> existingBudgets,
  }) async {
    final now = DateTime.now();
    // Issue 7: fixed — was `now.month` (wrong), now correctly uses `now.day`
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    final recentTxns = transactions
        .where((t) => !t.date.isBefore(threeMonthsAgo) && t.type == 'debit')
        .toList();

    final Map<String, List<double>> categoryHistory = {};
    for (final txn in recentTxns) {
      categoryHistory.putIfAbsent(txn.category, () => []).add(txn.amount);
    }

    final categoryPercentages = {
      'Bills & Utilities': 0.15,
      'Groceries': 0.12,
      'Food & Dining': 0.10,
      'Transportation': 0.08,
      'Shopping': 0.08,
      'Entertainment': 0.05,
      'Healthcare': 0.05,
      'Personal Care': 0.03,
      'Education': 0.05,
    };

    final recommendations = <Map<String, dynamic>>[];

    for (final entry in categoryHistory.entries) {
      final avgSpending =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
      final category = entry.key;
      final suggestedLimit =
          monthlyIncome * (categoryPercentages[category] ?? 0.05);
      final existingBudget =
          existingBudgets.where((b) => b.category == category).firstOrNull;

      recommendations.add({
        'category': category,
        'currentAvg': avgSpending,
        'suggestedLimit': suggestedLimit,
        'existingLimit': existingBudget?.limit ?? 0,
        'change': existingBudget != null
            ? suggestedLimit - existingBudget.limit
            : null,
      });
    }

    recommendations.sort((a, b) =>
        (b['currentAvg'] as double).compareTo(a['currentAvg'] as double));

    return recommendations;
  }

  /// Analyze investment portfolio and provide insights
  Future<String> analyzeInvestments(List<Investment> investments) async {
    if (investments.isEmpty) {
      return "No investments tracked yet. Add your first investment to get AI insights.";
    }

    final Map<InvestmentType, double> allocation = {};
    double totalValue = 0;

    for (final inv in investments) {
      final value = inv.totalValue;
      allocation.update(inv.type, (v) => v + value, ifAbsent: () => value);
      totalValue += value;
    }

    if (totalValue == 0) return "No investment value data available.";

    final StringBuffer analysis = StringBuffer();
    analysis.writeln("📊 **Portfolio Analysis**\n");
    analysis.writeln("*Total Value: QAR ${totalValue.toStringAsFixed(2)}*\n");
    analysis.writeln("*Allocation:*");

    for (final entry in allocation.entries) {
      final pct = (entry.value / totalValue * 100).toStringAsFixed(1);
      final typeName =
          InvestmentType.values[entry.key.index].toString().split('.').last;
      analysis
          .writeln("• $typeName: QAR ${entry.value.toStringAsFixed(2)} ($pct%)");
    }

    final sorted = allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isNotEmpty && (sorted.first.value / totalValue) > 0.5) {
      analysis.writeln(
          "\n⚠️ *Warning:* ${sorted.first.key.toString().split('.').last} makes up >50% of your portfolio. Consider diversifying.");
    }

    final stockPct = ((allocation[InvestmentType.stock] ?? 0) +
            (allocation[InvestmentType.etf] ?? 0)) /
        totalValue *
        100;
    if (stockPct < 40) {
      analysis.writeln(
          "\n💡 *Suggestion:* Your portfolio is conservative. Consider increasing stocks for long-term growth.");
    } else if (stockPct > 80) {
      analysis.writeln(
          "\n💡 *Suggestion:* Your portfolio is aggressive. Consider adding bonds or other stable assets for balance.");
    }

    final totalCost =
        investments.fold<double>(0, (sum, inv) => sum + inv.totalCost);
    final totalPL = totalValue - totalCost;
    final plPct = totalCost > 0 ? (totalPL / totalCost * 100) : 0.0;

    analysis.writeln("\n📈 *Performance:*");
    analysis.writeln("• Cost Basis: QAR ${totalCost.toStringAsFixed(2)}");
    analysis.writeln(
        "• P/L: QAR ${totalPL.toStringAsFixed(2)} (${plPct >= 0 ? '+' : ''}${plPct.toStringAsFixed(1)}%)");

    return analysis.toString();
  }
}
