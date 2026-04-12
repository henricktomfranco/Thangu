import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart' as app_transaction;
import '../models/goal.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  static const String _databaseName = 'thangu.db';
  static const int _databaseVersion = 1;

  static const String tableTransactions = 'transactions';
  static const String tableGoals = 'goals';

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
    return await db.delete(
      tableGoals,
      where: '$columnGoalId = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
