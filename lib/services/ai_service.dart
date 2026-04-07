import 'dart:convert';
import 'dart:io';
import '../models/transaction.dart';

class AiService {
  final String _ollamaUrl = 'http://localhost:11434/api/generate';
  final String _modelName = 'llama2'; // or 'mistral', 'codellama', etc.

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

  // Prompt template for transaction categorization
  String _buildCategorizationPrompt(Transaction transaction) {
    return '''
You are Thangu, an AI financial assistant. Your task is to categorize financial transactions into predefined categories.

Transaction Details:
- Amount: \$${transaction.amount}
- Type: ${transaction.type}
- Description: "${transaction.description}"
- Sender: ${transaction.sender}

Available Categories:
${_knownCategories.join(', ')}

Instructions:
1. Analyze the transaction based on the description, amount, and sender
2. Choose the most appropriate category from the list above
3. If unsure, select "Other"
4. Respond with ONLY the category name, nothing else
5. If the transaction is clearly income (salary, deposit, etc.), use "Income"

Category:''';
  }

  Future<String?> categorizeTransaction(Transaction transaction) async {
    try {
      final prompt = _buildCategorizationPrompt(transaction);
      
      final response = await HttpClient()
          .postUrl(Uri.parse(_ollamaUrl))
          .then((request) async {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(json.encode({
          'model': _modelName,
          'prompt': prompt,
          'stream': false,
        })));
        return await request.close();
      });

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> responseData = json.decode(responseBody);
        final String aiResponse = responseData['response']?.trim() ?? '';
        
        // Validate the response is a known category
        if (_knownCategories.contains(aiResponse)) {
          return aiResponse;
        } else {
          // Try to find closest match or default to Other
          final String normalizedResponse = aiResponse
              .replaceAll('&', 'and')
              .replaceAll('/', ' & ')
              .trim();
          
          final String? matchedCategory = _knownCategories.firstWhere(
            (category) => category.toLowerCase().contains(normalizedResponse.toLowerCase()) ||
                         normalizedResponse.toLowerCase().contains(category.toLowerCase()),
            orElse: () => 'Other',
          );
          
          return matchedCategory;
        }
      } else {
        throw Exception('Failed to categorize transaction: ${response.statusCode}');
      }
    } catch (e) {
      // If Ollama is not available or any error occurs, return null
      // so the app can fall back to manual categorization
      return null;
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

      final response = await HttpClient()
          .postUrl(Uri.parse(_ollamaUrl))
          .then((request) async {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(json.encode({
          'model': _modelName,
          'prompt': prompt,
          'stream': false,
        })));
        return await request.close();
      });

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> responseData = json.decode(responseBody);
        return responseData['response']?.trim() ?? 
            "I'm having trouble connecting to my knowledge base right now. Let's focus on tracking your transactions!";
      } else {
        throw Exception('Failed to get financial advice: ${response.statusCode}');
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
      categoryTotals.update(
        txn.category, 
        (value) => value + txn.amount, 
        ifAbsent: () => txn.amount
      );
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
