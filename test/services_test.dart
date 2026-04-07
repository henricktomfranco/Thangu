import 'package:flutter_test/flutter_test.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/models/transaction.dart';
import 'package:thangu/models/goal.dart';

void main() {
  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() {
      dbService = DatabaseService();
    });

    tearDown(() {
      // Clean up if needed
    });

    test('DatabaseService can be instantiated', () {
      expect(dbService, isNotNull);
      expect(dbService, isA<DatabaseService>());
    });

    // Transaction tests
    test('Transaction can be created', () {
      final transaction = Transaction(
        id: 'test_id',
        amount: 100.0,
        type: 'debit',
        category: 'Food & Dining',
        description: 'Test transaction',
        date: DateTime.now(),
        sender: 'TESTBANK',
      );

      expect(transaction, isNotNull);
      expect(transaction.id, 'test_id');
      expect(transaction.amount, 100.0);
      expect(transaction.type, 'debit');
      expect(transaction.category, 'Food & Dining');
    });

    // Goal tests
    test('SavingsGoal can be created', () {
      final goal = SavingsGoal(
        id: 'goal_1',
        name: 'Emergency Fund',
        targetAmount: 1000.0,
        currentAmount: 250.0,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        category: 'Emergency Fund',
        icon: 'account_balance',
      );

      expect(goal, isNotNull);
      expect(goal.id, 'goal_1');
      expect(goal.name, 'Emergency Fund');
      expect(goal.targetAmount, 1000.0);
      expect(goal.currentAmount, 250.0);
      expect(goal.progressPercentage, 0.25);
      expect(goal.isAchieved, isFalse);
    });
  });

  group('ExportService Tests', () {
    // Add tests for export service when we have a proper implementation
  });
}
