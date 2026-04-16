import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../models/investment.dart';
import '../services/ai_service.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Investment> _investments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  Future<void> _loadInvestments() async {
    setState(() => _isLoading = true);
    try {
      final investments = await _dbService.getInvestments();
      setState(() {
        _investments = investments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAIInsights(BuildContext context) async {
    if (_investments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add investments first to get AI insights.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final aiService = AiService();
      final insights = await aiService.analyzeInvestments(_investments);

      setState(() => _isLoading = false);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surfaceCard,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: AppTheme.accentOrange),
                    const SizedBox(width: 8),
                    const Text('AI Portfolio Analysis',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(insights,
                        style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addInvestment() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController();
    InvestmentType selectedType = InvestmentType.stock;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Investment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Asset Name',
                    hintText: 'e.g., Apple Inc, Bitcoin',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<InvestmentType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppTheme.surfaceCard,
                  items: InvestmentType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_getTypeText(t)),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(
                      () => selectedType = v ?? InvestmentType.stock),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Purchase Price',
                          hintText: 'Price per unit',
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          hintText: 'Units',
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          priceController.text.isEmpty ||
                          qtyController.text.isEmpty) return;
                      final price = double.tryParse(priceController.text);
                      final qty = double.tryParse(qtyController.text);
                      if (price == null || qty == null) return;

                      final inv = Investment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        type: selectedType,
                        purchasePrice: price,
                        quantity: qty,
                        purchaseDate: DateTime.now(),
                        currentPrice: price,
                        updatedAt: DateTime.now(),
                      );

                      await _dbService.insertInvestment(inv);
                      if (mounted) Navigator.pop(context);
                      _loadInvestments();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Investment'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getTypeText(InvestmentType t) {
    switch (t) {
      case InvestmentType.stock:
        return 'Stock';
      case InvestmentType.etf:
        return 'ETF';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.bond:
        return 'Bond';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalValue =
        _investments.fold(0.0, (sum, inv) => sum + inv.totalValue);
    final totalCost = _investments.fold(0.0, (sum, inv) => sum + inv.totalCost);
    final totalPL = totalValue - totalCost;
    final plPercent = totalCost > 0 ? (totalPL / totalCost) * 100 : 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Investments',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            )),
        actions: [
          TextButton.icon(
            onPressed: () => _showAIInsights(context),
            icon: const Icon(Icons.auto_awesome,
                size: 18, color: AppTheme.accentOrange),
            label: const Text('AI Insights',
                style: TextStyle(color: AppTheme.accentOrange, fontSize: 13)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _investments.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSummaryCard(
                        totalValue, totalCost, totalPL, plPercent.toDouble()),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _investments.length,
                        itemBuilder: (context, index) {
                          return _buildInvestmentCard(_investments[index]);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addInvestment,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          const Text('No investments yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Tap + to add your first investment', style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      double totalValue, double totalCost, double pl, double plPercent) {
    final isProfit = pl >= 0;
    final color = isProfit ? AppTheme.accentGreen : AppTheme.accentRed;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Total Portfolio Value',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('QAR${totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isProfit ? '+' : ''}QAR${pl.toStringAsFixed(2)} (${plPercent.toStringAsFixed(1)}%)',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(Investment inv) {
    final color = inv.isProfit ? AppTheme.accentGreen : AppTheme.accentRed;
    final invColor = inv.type == InvestmentType.crypto
        ? Colors.orange
        : inv.type == InvestmentType.stock
            ? AppTheme.primary
            : AppTheme.accent;

    return Dismissible(
      key: Key(inv.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await _dbService.deleteInvestment(inv.id);
        _loadInvestments();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: invColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.trending_up, color: invColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    '${inv.quantity} @ QAR${inv.purchasePrice.toStringAsFixed(2)}',
                    style: AppTheme.caption,
                  ),
                  Text(
                    inv.typeText,
                    style: TextStyle(color: invColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('QAR${inv.totalValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    )),
                Text(
                  '${inv.isProfit ? '+' : ''}QAR${inv.profitLoss.toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
