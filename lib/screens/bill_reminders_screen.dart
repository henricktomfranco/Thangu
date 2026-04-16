import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/bill_reminder.dart';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});

  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen> {
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notifService = NotificationService();
  List<BillReminder> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    try {
      var bills = await _dbService.getBillReminders();
      
      // Auto-advance overdue recurring bills
      bool updatedAny = false;
      for (int i = 0; i < bills.length; i++) {
        final bill = bills[i];
        if (bill.enabled && bill.isDue && bill.recurrence != RecurrencePeriod.once) {
          final nextDue = bill.getNextDueDate();
          if (nextDue != null && nextDue.isAfter(bill.dueDate)) {
            final updatedBill = bill.copyWith(dueDate: nextDue);
            await _dbService.updateBillReminder(updatedBill);
            bills[i] = updatedBill;
            updatedAny = true;
          }
        }
      }
      if (updatedAny) {
        bills = await _dbService.getBillReminders();
      }

      setState(() {
        _bills = bills;
        _isLoading = false;
      });
      await _scheduleReminders();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleReminders() async {
    for (final bill in _bills) {
      if (bill.enabled) {
        await _notifService.scheduleBillReminder(
          billId: bill.id,
          billName: bill.name,
          amount: bill.amount,
          dueDate: bill.dueDate,
          daysBefore: bill.reminderDaysBefore,
        );
      }
    }
  }

  Future<void> _addBill() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    RecurrencePeriod selectedRecurrence = RecurrencePeriod.monthly;
    int reminderDays = 3;

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
                const Text('Add Bill Reminder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Bill Name',
                    hintText: 'e.g., Netflix, Electric Bill',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (QAR)',
                    hintText: 'e.g., 100',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() => selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Due Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  )),
                              const SizedBox(height: 4),
                              Text(DateFormat('MMM d, yyyy')
                                  .format(selectedDate)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RecurrencePeriod>(
                  value: selectedRecurrence,
                  decoration: InputDecoration(
                    labelText: 'Recurrence',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppTheme.surfaceCard,
                  items: RecurrencePeriod.values.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(_getRecurrenceText(r)),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(
                      () => selectedRecurrence = v ?? RecurrencePeriod.monthly),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: reminderDays,
                  decoration: InputDecoration(
                    labelText: 'Remind Before',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppTheme.surfaceCard,
                  items: [1, 3, 7, 14].map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text('$d days before'),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => reminderDays = v ?? 3),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          amountController.text.isEmpty) return;
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) return;

                      final bill = BillReminder(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        amount: amount,
                        dueDate: selectedDate,
                        recurrence: selectedRecurrence,
                        category: 'Bills & Utilities',
                        reminderDaysBefore: reminderDays,
                        createdAt: DateTime.now(),
                      );

                      await _dbService.insertBillReminder(bill);
                      await _notifService.scheduleBillReminder(
                        billId: bill.id,
                        billName: bill.name,
                        amount: bill.amount,
                        dueDate: bill.dueDate,
                        daysBefore: bill.reminderDaysBefore,
                      );

                      if (mounted) Navigator.pop(context);
                      _loadBills();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Reminder'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRecurrenceText(RecurrencePeriod r) {
    switch (r) {
      case RecurrencePeriod.once:
        return 'One-time';
      case RecurrencePeriod.weekly:
        return 'Weekly';
      case RecurrencePeriod.monthly:
        return 'Monthly';
      case RecurrencePeriod.quarterly:
        return 'Quarterly';
      case RecurrencePeriod.yearly:
        return 'Yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcomingBills =
        _bills.where((b) => b.enabled && b.isUpcoming).toList();
    final dueBills = _bills.where((b) => b.enabled && b.isDue).toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bill Reminders',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            )),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _bills.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          if (dueBills.isNotEmpty) ...[
                            _buildAlertCard('Bills Due Now!', dueBills.length,
                                AppTheme.accentRed),
                            const SizedBox(height: 12),
                          ],
                          if (upcomingBills.isNotEmpty) ...[
                            _buildAlertCard('Due Soon', upcomingBills.length,
                                AppTheme.accentOrange),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }
                    final bill = _bills[index - 1];
                    return _buildBillCard(bill);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBill,
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
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          const Text('No bill reminders',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Tap + to add your first bill reminder',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
              color == AppTheme.accentRed
                  ? Icons.warning_amber
                  : Icons.schedule,
              color: color),
          const SizedBox(width: 12),
          Text('$title ($count)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _buildBillCard(BillReminder bill) {
    final color = bill.isDue
        ? AppTheme.accentRed
        : bill.isUpcoming
            ? AppTheme.accentOrange
            : AppTheme.accentGreen;
    final daysUntil = bill.dueDate.difference(DateTime.now()).inDays;

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await _dbService.deleteBillReminder(bill.id);
        await _notifService.cancelNotification(bill.id);
        _loadBills();
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
          border: Border.all(
              color: bill.enabled
                  ? color.withOpacity(0.3)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                bill.isDue ? Icons.warning_amber : Icons.receipt,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'QAR${bill.amount.toStringAsFixed(0)} • ${bill.recurrenceText}',
                    style: AppTheme.caption,
                  ),
                  Text(
                    daysUntil == 0
                        ? 'Due today'
                        : daysUntil < 0
                            ? '${daysUntil.abs()} days overdue'
                            : 'Due in $daysUntil days',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: bill.enabled,
              onChanged: (_) async {
                final updated = bill.copyWith(enabled: !bill.enabled);
                await _dbService.updateBillReminder(updated);
                if (!bill.enabled) {
                  await _notifService.scheduleBillReminder(
                    billId: bill.id,
                    billName: bill.name,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    daysBefore: bill.reminderDaysBefore,
                  );
                } else {
                  await _notifService.cancelNotification(bill.id);
                }
                _loadBills();
              },
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
