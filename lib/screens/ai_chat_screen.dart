import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../services/database_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiService _aiService = AiService();
  final DatabaseService _dbService = DatabaseService();

  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get some financial data to provide context
      final transactions = await _dbService.getTransactions(limit: 20);
      final goals = await _dbService.getGoals();

      // Calculate monthly income/expenses
      double monthlyIncome = 0;
      double monthlyExpenses = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final txn in transactions) {
        if (txn.date.isAfter(startOfMonth)) {
          if (txn.type == 'credit') {
            monthlyIncome += txn.amount;
          } else {
            monthlyExpenses += txn.amount;
          }
        }
      }

      // Get initial advice from Thangu AI
      final advice = await _aiService.getFinancialAdvice(
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        recentTransactions: transactions,
      );

      setState(() {
        _messages.add({
          'text': advice,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
      if (mounted) {
        _messages.add({
          'text':
              "Hello! I'm Thangu, your AI finance assistant. I'm having trouble connecting to my knowledge base right now, but I can still help you track your transactions and savings goals!",
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final String messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add({
        'text': messageText,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
      _isLoading = true;
    });

    try {
      // Get financial context for better responses
      final transactions = await _dbService.getTransactions(limit: 50);
      final goals = await _dbService.getGoals();

      double monthlyIncome = 0;
      double monthlyExpenses = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final txn in transactions) {
        if (txn.date.isAfter(startOfMonth)) {
          if (txn.type == 'credit') {
            monthlyIncome += txn.amount;
          } else {
            monthlyExpenses += txn.amount;
          }
        }
      }

      // Get AI response
      final response = await _aiService.getFinancialAdvice(
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        recentTransactions: transactions,
      );

      // Add bot response
      if (mounted) {
        setState(() {
          _messages.add({
            'text': response,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text':
                "I'm sorry, I'm having trouble thinking right now. Please try again in a moment.",
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance, color: Colors.white),
            SizedBox(width: 8),
            Text('Thangu AI'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Start the conversation!',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final bool isUser = message['isUser'] as bool;
                          final String text = message['text'] as String;
                          final DateTime timestamp =
                              message['timestamp'] as DateTime;

                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.deepPurple[100]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isUser ? 16 : 0),
                                  topRight: Radius.circular(isUser ? 0 : 16),
                                  bottomLeft: const Radius.circular(16),
                                  bottomRight: const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isUser
                                          ? Colors.deepPurple[600]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          _isLoading && _isInitialized
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Ask Thangu about your finances...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            filled: true,
                            fillColor: Colors.grey[100],
                            prefixIcon: const Icon(Icons.chat_bubble_outline),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendMessage,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
