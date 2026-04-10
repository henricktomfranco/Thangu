import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../models/transaction.dart';

enum SavingAggression {
  low,
  medium,
  high,
}

class ProactiveAiService {
  final AiService _aiService = AiService();
  SavingAggression _aggression = SavingAggression.medium;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final aggIndex = prefs.getInt('saving_aggression') ?? 1;
    _aggression = SavingAggression.values[aggIndex];
  }

  Future<void> updateAggression(SavingAggression newAgg) async {
    _aggression = newAgg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saving_aggression', newAgg.index);
  }

  Future<String?> analyzeNewTransaction(
      Transaction transaction, List<Transaction> history) async {
    if (transaction.type == 'credit') return null;

    if (_aggression == SavingAggression.high && transaction.amount > 500) {
      return "That's a large expense! Do you want to categorize this as a 'Want' or 'Need' to track your leakage?";
    }

    final prompt = '''
    You are Thangu, a proactive financial coach. A user just spent ${transaction.amount} QAR at ${transaction.description} in the ${transaction.category} category.
    
    Recent history in ${transaction.category}:
    ${_summarizeCategoryHistory(history, transaction.category)}
    
    If this spending is unusual or represents a "leakage" (unnecessary spend), provide a very short, encouraging nudge (max 20 words) to help them save. 
    If it's normal, return "null".
    
    Response:''';

    try {
      final response = await _aiService.generateResponse(prompt);
      if (response.toLowerCase().contains('null')) return null;
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<String?> analyzeSpendingTrends(List<Transaction> transactions) async {
    if (transactions.isEmpty) return null;

    final prompt = '''
    Analyze these recent transactions and find the BIGGEST saving opportunity.
    Transactions:
    ${transactions.map((t) => "${t.date}: ${t.description} - ${t.amount} QAR (${t.category})").join('\n')}
    
    Identify:
    1. Recurring subscriptions that might be unused.
    2. Categories with a spending spike.
    3. A specific habit that could be reduced.
    
    Provide one actionable saving tip (max 30 words). Be direct and motivating.
    Response:''';

    try {
      return await _aiService.generateResponse(prompt);
    } catch (e) {
      return null;
    }
  }

  String _summarizeCategoryHistory(List<Transaction> history, String category) {
    final categoryTxns = history
        .where((t) => t.category == category && t.type == 'debit')
        .toList();
    if (categoryTxns.isEmpty) return "No previous history in this category.";

    double total = categoryTxns.fold(0, (sum, item) => sum + item.amount);
    return "Total spent in ${category} recently: ${total.toStringAsFixed(2)} QAR over ${categoryTxns.length} transactions.";
  }
}
