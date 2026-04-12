import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart' as app_transaction;
import '../models/goal.dart';
import '../models/budget.dart';
import '../models/bill_reminder.dart';
import '../models/investment.dart';
import '../models/debt.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  static const String _databaseName = 'thangu.db';
  static const int _databaseVersion = 1;

  static const String tableTransactions = 'transactions';
  static const String tableGoals = 'goals';
  static const String tableBudgets = 'budgets';
  static const String tableBillReminders = 'bill_reminders';
  static const String tableInvestments = 'investments';
  static const String tableDebts = 'debts';

  // Column names for transactions
  static const String columnId = 'id';
  static const String columnAmount = 'amount';
  static const String columnCurrency = 'currency';
  static const String columnType = 'type';
  static const String columnCategory = 'category';
  static const String columnDescription = 'description';
  static const String columnDate = 'date';
  static const String columnSender = 'sender';
  static const String columnIsCategorizedByAI = 'is_categorized_by_ai';
  static const String columnAiConfidence = 'ai_confidence';
  // Account fields
  static const String columnAccountNumber = 'account_number';
  static const String columnAccountName = 'account_name';
  static const String columnAccountType = 'account_type';

  // Column names for goals
  static const String columnGoalId = 'id';
  static const String columnGoalName = 'name';
  static const String columnTargetAmount = 'target_amount';
  static const String columnCurrentAmount = 'current_amount';
  static const String columnTargetDate = 'target_date';
  static const String columnGoalCategory = 'category';
  static const String columnGoalIcon = 'icon';

  // Column names for budgets
  static const String columnBudgetId = 'id';
  static const String columnBudgetCategory = 'category';
  static const String columnBudgetLimit = 'limit_amount';
  static const String columnBudgetSpent = 'spent_amount';
  static const String columnBudgetPeriodStart = 'period_start';
  static const String columnBudgetPeriodEnd = 'period_end';
  static const String columnBudgetEnabled = 'enabled';
  static const String columnBudgetCreatedAt = 'created_at';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTransactions (
        $columnId TEXT PRIMARY KEY,
        $columnAmount REAL NOT NULL,
        $columnCurrency TEXT NOT NULL DEFAULT 'QAR',
        $columnType TEXT NOT NULL,
        $columnCategory TEXT NOT NULL,
        $columnDescription TEXT,
        $columnDate TEXT NOT NULL,
        $columnSender TEXT,
        $columnIsCategorizedByAI INTEGER NOT NULL,
        $columnAiConfidence REAL NOT NULL,
        $columnAccountNumber TEXT,
        $columnAccountName TEXT,
        $columnAccountType TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableGoals (
        $columnGoalId TEXT PRIMARY KEY,
        $columnGoalName TEXT NOT NULL,
        $columnTargetAmount REAL NOT NULL,
        $columnCurrentAmount REAL NOT NULL,
        $columnTargetDate TEXT NOT NULL,
        $columnGoalCategory TEXT NOT NULL,
        $columnGoalIcon TEXT NOT NULL
      )
    ''');

    // Budgets table for tracking category-based budgets
    await db.execute('''
      CREATE TABLE $tableBudgets (
        $columnBudgetId TEXT PRIMARY KEY,
        $columnBudgetCategory TEXT NOT NULL,
        $columnBudgetLimit REAL NOT NULL,
        $columnBudgetSpent REAL NOT NULL DEFAULT 0,
        $columnBudgetPeriodStart TEXT NOT NULL,
        $columnBudgetPeriodEnd TEXT NOT NULL,
        $columnBudgetEnabled INTEGER NOT NULL DEFAULT 1,
        $columnBudgetCreatedAt TEXT NOT NULL
      )
    ''');

    // Bill reminders table
    await db.execute('''
      CREATE TABLE $tableBillReminders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT NOT NULL,
        recurrence INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        reminder_days_before INTEGER NOT NULL DEFAULT 3,
        created_at TEXT NOT NULL
)
    ''');

    // Investments table
    await db.execute('''
      CREATE TABLE $tableInvestments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        quantity REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        current_price REAL,
        exchange TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Debts table
    await db.execute('''
      CREATE TABLE $tableDebts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        principal REAL NOT NULL,
        interest_rate REAL NOT NULL,
        term_months INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        monthly_payment REAL NOT NULL,
        remaining_balance REAL NOT NULL,
        lender TEXT,
        is_paid_off INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertTransaction(app_transaction.Transaction transaction) async {
    final db = await database;
    return await db.insert(tableTransactions, transaction.toMap());
  }

  Future<List<app_transaction.Transaction>> getTransactions(
      {int limit = 50, DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = 'SELECT * FROM $tableTransactions';
    List<dynamic> whereArgs = [];

    if (startDate != null || endDate != null) {
      List<String> conditions = [];
      if (startDate != null) {
        conditions.add('$columnDate >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        conditions.add('$columnDate <= ?');
        whereArgs.add(endDate.toIso8601String());
      }
      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }
    }

    query += ' LIMIT $limit';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);
    return List.generate(
        maps.length, (i) => app_transaction.Transaction.fromMap(maps[i]));
  }

  Future<int> updateTransaction(app_transaction.Transaction transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: '$columnId = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Goal methods
  Future<int> insertGoal(SavingsGoal goal) async {
    final db = await database;
    return await db.insert(tableGoals, {
      columnGoalId: goal.id,
      columnGoalName: goal.name,
      columnTargetAmount: goal.targetAmount,
      columnCurrentAmount: goal.currentAmount,
      columnTargetDate: goal.targetDate.toIso8601String(),
      columnGoalCategory: goal.category,
      columnGoalIcon: goal.icon,
    });
  }

  Future<List<SavingsGoal>> getGoals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableGoals);
    return List.generate(
      maps.length,
      (i) => SavingsGoal(
        id: maps[i][columnGoalId],
        name: maps[i][columnGoalName],
        targetAmount: maps[i][columnTargetAmount].toDouble(),
        currentAmount: maps[i][columnCurrentAmount].toDouble(),
        targetDate: DateTime.parse(maps[i][columnTargetDate]),
        category: maps[i][columnGoalCategory],
        icon: maps[i][columnGoalIcon],
      ),
    );
  }

  Future<int> updateGoal(SavingsGoal goal) async {
    final db = await database;
    return await db.update(
      tableGoals,
      {
        columnGoalId: goal.id,
        columnGoalName: goal.name,
        columnTargetAmount: goal.targetAmount,
        columnCurrentAmount: goal.currentAmount,
        columnTargetDate: goal.targetDate.toIso8601String(),
        columnGoalCategory: goal.category,
        columnGoalIcon: goal.icon,
      },
      where: '$columnGoalId = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(String id) async {
    final db = await database;
    return await db
        .delete(tableGoals, where: '$columnGoalId = ?', whereArgs: [id]);
  }

  // ─── Budget Operations ─────────────────────────────────────

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert(tableBudgets, budget.toMap());
  }

  Future<List<Budget>> getBudgets(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = 'SELECT * FROM $tableBudgets WHERE $columnBudgetEnabled = 1';

    if (startDate != null && endDate != null) {
      query +=
          ' AND $columnBudgetPeriodStart >= ? AND $columnBudgetPeriodEnd <= ?';
      final List<Map<String, dynamic>> maps = await db.rawQuery(
          query, [startDate.toIso8601String(), endDate.toIso8601String()]);
      return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      tableBudgets,
      budget.toMap(),
      where: '$columnBudgetId = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db
        .delete(tableBudgets, where: '$columnBudgetId = ?', whereArgs: [id]);
  }

  /// Get budget by category
  Future<Budget?> getBudgetByCategory(
      String category, DateTime periodStart) async {
    final budgets = await getBudgets();
    return budgets.where((b) {
      return b.category == category &&
          b.periodStart.isAtSameMomentAs(periodStart);
    }).firstOrNull;
  }

  /// Update budget spent amount
  Future<int> updateBudgetSpent(
      String categoryId, double spent, DateTime periodStart) async {
    final budget = await getBudgetByCategory(categoryId, periodStart);
    if (budget != null) {
      final updated = budget.withSpent(spent);
      return await updateBudget(updated);
    }
    return 0;
  }

  // Bill Reminders CRUD
  Future<int> insertBillReminder(BillReminder bill) async {
    final db = await database;
    return await db.insert(tableBillReminders, bill.toMap());
  }

  Future<int> updateBillReminder(BillReminder bill) async {
    final db = await database;
    return await db.update(
      tableBillReminders,
      bill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );
  }

  Future<List<BillReminder>> getBillReminders() async {
    final db = await database;
    final maps = await db.query(tableBillReminders, orderBy: 'due_date ASC');
    return maps.map((map) => BillReminder.fromMap(map)).toList();
  }

  Future<BillReminder?> getBillReminderById(String id) async {
    final db = await database;
    final maps = await db.query(
      tableBillReminders,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BillReminder.fromMap(maps.first);
  }

  Future<int> deleteBillReminder(String id) async {
    final db = await database;
    return await db
        .delete(tableBillReminders, where: 'id = ?', whereArgs: [id]);
  }

  // Investment CRUD
  Future<int> insertInvestment(Investment inv) async {
    final db = await database;
    return await db.insert(tableInvestments, inv.toMap());
  }

  Future<int> updateInvestment(Investment inv) async {
    final db = await database;
    return await db.update(
      tableInvestments,
      inv.toMap(),
      where: 'id = ?',
      whereArgs: [inv.id],
    );
  }

  Future<List<Investment>> getInvestments() async {
    final db = await database;
    final maps = await db.query(tableInvestments, orderBy: 'name ASC');
    return maps.map((map) => Investment.fromMap(map)).toList();
  }

  Future<int> deleteInvestment(String id) async {
    final db = await database;
    return await db.delete(tableInvestments, where: 'id = ?', whereArgs: [id]);
  }

  // Debt CRUD
  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return await db.insert(tableDebts, debt.toMap());
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return await db.update(tableDebts, debt.toMap(),
        where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<List<Debt>> getDebts() async {
    final db = await database;
    final maps = await db.query(tableDebts, orderBy: 'name ASC');
    return maps.map((map) => Debt.fromMap(map)).toList();
  }

  Future<int> deleteDebt(String id) async {
    final db = await database;
    return await db.delete(tableDebts, where: 'id = ?', whereArgs: [id]);
  }

  /// Close database connection (optional cleanup)
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
