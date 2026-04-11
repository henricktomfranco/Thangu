import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/ai_service.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../models/goal.dart';
import 'goals_screen.dart';
import 'add_transaction_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final AiService _aiService = AiService();
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    try {
      await _aiService.initialize();

      final transactions = await _dbService.getTransactions(limit: 50);
      final goals = await _dbService.getGoals();

      double monthlyIncome = 0, monthlyExpenses = 0;
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

      final advice = await _aiService.getFinancialAdvice(
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        recentTransactions: transactions,
      );

      setState(() {
        _messages.add({
          'text': "Hi! I'm Thangu, your AI finance assistant 🤖\n\n$advice",
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
        _messages.add({
          'text':
              "Hi! I'm Thangu, your AI finance assistant 🤖\n\nI can help you with:\n• Viewing transactions & spending patterns\n• Creating & tracking savings goals\n• Budget planning & financial advice\n• Adding new transactions\n\nWhat would you like to know?",
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      await _aiService.initialize();

      final transactions = await _dbService.getTransactions(limit: 50);
      final goals = await _dbService.getGoals();

      double totalBalance = 0;
      double monthlyIncome = 0, monthlyExpenses = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final txn in transactions) {
        if (txn.type == 'credit') {
          totalBalance += txn.amount;
        } else {
          totalBalance -= txn.amount;
        }
        if (txn.date.isAfter(startOfMonth)) {
          if (txn.type == 'credit') {
            monthlyIncome += txn.amount;
          } else {
            monthlyExpenses += txn.amount;
          }
        }
      }

      final savingsRate = monthlyIncome > 0
          ? ((monthlyIncome - monthlyExpenses) / monthlyIncome * 100)
          : 0;

      final contextPrompt = '''
You are Thangu, an AI finance assistant with access to the user's financial data.

CURRENT FINANCIAL SNAPSHOT:
- Total Balance: QAR ${totalBalance.toStringAsFixed(2)}
- Monthly Income: QAR ${monthlyIncome.toStringAsFixed(2)}
- Monthly Expenses: QAR ${monthlyExpenses.toStringAsFixed(2)}
- Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- Active Savings Goals: ${goals.length}
- Recent Transactions: ${transactions.length}

TOP SPENDING CATEGORIES (This Month):
${_getCategoryBreakdown(transactions)}

SAVINGS GOALS:
${_getGoalsSummary(goals)}

INSTRUCTIONS:
1. Answer questions about their finances using the data above
2. Suggest creating new goals when appropriate
3. Recommend budget improvements based on spending patterns
4. If they ask to add a transaction or goal, say "I can help you with that" and describe what to do
5. Keep responses friendly, concise, and actionable
6. Remember past context from our conversation

CAPABILITIES:
- View transactions and spending patterns
- Create and track savings goals  
- Add new transactions manually
- Provide budget and savings advice
- Answer financial questions

User's message: "$text"
''';

      final List<Map<String, dynamic>> contextMessages =
          _conversationHistory.take(5).toList();

      final lowerText = text.toLowerCase();
      String response;

      if (lowerText.contains('saving') ||
          lowerText.contains('budget') ||
          lowerText.contains('plan')) {
        final userGoals = goals.map((g) => g.name).toList();
        response = await _aiService.getSavingsPlan(
          monthlyIncome: monthlyIncome,
          monthlyExpenses: monthlyExpenses,
          recentTransactions: transactions,
          userGoals: userGoals,
        );
      } else if (lowerText.contains('spending') ||
          lowerText.contains('spend') ||
          lowerText.contains('category') ||
          lowerText.contains('breakdown') ||
          lowerText.contains('analysis')) {
        response = await _aiService.analyzeSpendingPatterns(
            transactions: transactions);
      } else {
        String fullPrompt = contextMessages.isEmpty
            ? contextPrompt
            : '$contextPrompt\n\nConversation History:\n${contextMessages.map((m) => '${m['isUser'] ? "User" : "Assistant"}: ${m['text']}').join('\n')}\n\nUser\'s message: "$text"';

        response = await _aiService.generateResponse(fullPrompt);
      }

      if (mounted) {
        setState(() {
          _conversationHistory.add({
            'text': text,
            'isUser': true,
            'timestamp': DateTime.now(),
          });

          _conversationHistory.add({
            'text': response.isNotEmpty
                ? response
                : "I'm here to help! Ask me anything about your finances.",
            'isUser': false,
            'timestamp': DateTime.now(),
          });

          if (_conversationHistory.length > 10) {
            _conversationHistory.removeRange(
                0, _conversationHistory.length - 10);
          }

          _messages.add({
            'text': response.isNotEmpty
                ? response
                : "I'm here to help! Ask me anything about your finances.",
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text':
                "I'm having trouble right now. Please try again in a moment.",
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _getCategoryBreakdown(List<Transaction> transactions) {
    if (transactions.isEmpty) return 'No transactions yet';

    final Map<String, double> categories = {};
    for (final txn in transactions.where((t) => t.type == 'debit')) {
      categories.update(txn.category, (value) => value + txn.amount,
          ifAbsent: () => txn.amount);
    }

    if (categories.isEmpty) return 'No expense transactions';

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(5)
        .map((e) => '- ${e.key}: QAR ${e.value.toStringAsFixed(2)}')
        .join('\n');
  }

  String _getGoalsSummary(List<SavingsGoal> goals) {
    if (goals.isEmpty) return 'No active goals';

    return goals
        .map((g) =>
            '- ${g.name}: QAR ${g.currentAmount.toStringAsFixed(0)} / QAR ${g.targetAmount.toStringAsFixed(0)} (${(g.progressPercentage * 100).toInt()}%)')
        .join('\n');
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thangu AI',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Financial Assistant',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading && !_isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? _buildWelcome()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          final msg = _messages[index];
                          return _buildMessageBubble(
                            text: msg['text'] as String,
                            isUser: msg['isUser'] as bool,
                            timestamp: msg['timestamp'] as DateTime,
                          );
                        },
                      ),
          ),
          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 48, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          const Text('Ask Thangu anything!',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Get personalized financial advice',
              style: TextStyle(color: AppTheme.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    required DateTime timestamp,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isUser ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 16 : 4),
            topRight: Radius.circular(isUser ? 4 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser
                ? AppTheme.primary.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isUser ? AppTheme.textPrimary : AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isUser
                    ? AppTheme.primaryLight.withOpacity(0.6)
                    : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: AnimatedBuilder(
          animation: _typingController,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.2;
                final t = ((_typingController.value + delay) % 1.0);
                final opacity = (1 - (t * 2 - 1).abs()).clamp(0.3, 1.0);
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildQuickActionChip(
              icon: Icons.savings_rounded,
              label: 'New Goal',
              color: AppTheme.accentGreen,
              onTap: () => _navigateToAddGoal(),
            ),
            const SizedBox(width: 8),
            _buildQuickActionChip(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add Transaction',
              color: AppTheme.accent,
              onTap: () => _navigateToAddTransaction(),
            ),
            const SizedBox(width: 8),
            _buildQuickActionChip(
              icon: Icons.analytics_rounded,
              label: 'My Spending',
              color: AppTheme.accentOrange,
              onTap: () {
                _messageController.text = 'Show me my spending breakdown';
                _sendMessage();
              },
            ),
            const SizedBox(width: 8),
            _buildQuickActionChip(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Tips',
              color: AppTheme.primaryLight,
              onTap: () {
                _messageController.text = 'Give me savings tips';
                _sendMessage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddGoal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  void _navigateToAddTransaction() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildQuickActions(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      fillColor: AppTheme.surfaceInput,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusRound),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
