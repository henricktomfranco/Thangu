import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/goal.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  // Database constants
  static const String _databaseName = 'thangu.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableTransactions = 'transactions';
  static const String tableGoals = 'goals';

  // Column names for transactions table
  static const String columnId = 'id';
  static const String columnAmount = 'amount';
  static const String columnType = 'type';
  static const String columnCategory = 'category';
  static const String columnDescription = 'description';
  static const String columnDate = 'date';
  static const String columnSender = 'sender';
  static const String columnIsCategorizedByAI = 'is_categorized_by_ai';
  static const String columnAiConfidence = 'ai_confidence';

  // Column names for goals table
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
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = '${documentsDirectory.path}/$_databaseName';
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create transactions table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        $columnId TEXT PRIMARY KEY,
        $columnAmount REAL NOT NULL,
        $columnType TEXT NOT NULL,
        $columnCategory TEXT NOT NULL,
        $columnDescription TEXT,
        $columnDate TEXT NOT NULL,
        $columnSender TEXT,
        $columnIsCategorizedByAI INTEGER NOT NULL,
        $columnAiConfidence REAL NOT NULL
      )
    ''');

    // Create goals table
    await db.execute('''
      CREATE TABLE $tableGoals (
        $columnGoalId TEXT PRIMARY KEY,
        $columnGoalName TEXT NOT NULL,
        $columnTargetAmount REAL NOT NULL,
        $columnCurrentAmount REAL NOT NULL DEFAULT 0,
        $columnTargetDate TEXT NOT NULL,
        $columnGoalCategory TEXT NOT NULL,
        $columnGoalIcon TEXT NOT NULL
      )
    ''');
  }

// Transaction CRUD operations
  Future<int> insertTransaction(app_transaction.Transaction transaction) async {
    final db = await database;
    return await db.insert(tableTransactions, transaction.toMap());
  }

  Future<List<app_transaction.Transaction>> getTransactions({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    var query = 'SELECT * FROM $tableTransactions';
    final List<String> whereArgs = [];

    if (startDate != null || endDate != null) {
      query += ' WHERE';
      if (startDate != null) {
        query += ' $columnDate >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        if (startDate != null) query += ' AND';
        query += ' $columnDate <= ?';
        whereArgs.add(endDate.toIso8601String());
      }
    }

    query += ' ORDER BY $columnDate DESC';
    if (limit > 0) {
      query += ' LIMIT $limit';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      limit: limit,
      orderBy: '$columnDate DESC',
    );

    return List.generate(maps.length, (i) {
      return app_transaction.Transaction.fromMap(maps[i]);
    });
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

  // Goal CRUD operations
  Future<int> insertGoal(SavingsGoal goal) async {
    final db = await database;
    return await db.insert(tableGoals, goal.toMap());
  }

  Future<List<SavingsGoal>> getGoals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableGoals);

    return List.generate(maps.length, (i) {
      return SavingsGoal.fromMap(maps[i]);
    });
  }

  Future<int> updateGoal(SavingsGoal goal) async {
    final db = await database;
    return await db.update(
      tableGoals,
      goal.toMap(),
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

  // Close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
