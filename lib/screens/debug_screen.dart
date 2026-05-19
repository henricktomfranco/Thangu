import 'package:flutter/material.dart';
import 'package:thangu/services/database_service.dart';
import 'package:thangu/services/sms_history_service.dart';
import 'package:thangu/models/transaction.dart' as app_txn;
import '../app_theme.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DatabaseService _dbService = DatabaseService();
  final SmsHistoryService _smsService = SmsHistoryService();
  String _output = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('SMS Debug'),
        backgroundColor: AppTheme.scaffoldBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllData,
            tooltip: 'Clear all data',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildButtonRow(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _output.isEmpty ? 'Tap a button above to start debugging' : _output,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonRow() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _debugButton('1. Raw SMS Query', _rawSmsQuery, Icons.sms),
          _debugButton('2. Full Scan', _fullScan, Icons.download),
          _debugButton('3. Check DB', _checkDb, Icons.storage),
          _debugButton('4. Financial Check', _checkFinancial, Icons.filter_list),
          _debugButton('5. FORCE INSERT', _forceInsert, Icons.bolt),
        ],
      ),
    );
  }

  Widget _debugButton(String label, VoidCallback onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _log(String msg) {
    setState(() {
      _output += '$msg\n';
    });
  }

  Future<void> _rawSmsQuery() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    _log('═══ Step 1: Raw SMS Query ═══');
    _log('Querying Android for inbox SMS (last 90 days)...');

    try {
      final result = await _smsService.debugRawSmsQuery();

      if (result == null) {
        _log('⚠ Android returned null — method channel failed');
      } else {
        final List<dynamic> smsList = result as List<dynamic>;
        _log('✓ Android returned ${smsList.length} SMS messages');

        if (smsList.isEmpty) {
          _log('⚠ No SMS found. Possible reasons:');
          _log('  - SMS permission not granted');
          _log('  - No inbox SMS in last 90 days');
          _log('  - Default SMS app is consuming messages');
        } else {
          for (int i = 0; i < smsList.length && i < 15; i++) {
            final msg = smsList[i] as Map<dynamic, dynamic>;
            final body = msg['body'] as String? ?? '';
            final sender = msg['sender'] as String? ?? 'Unknown';
            _log('');
            _log('SMS #${i + 1} from: $sender');
            _log('  ${body.length > 100 ? body.substring(0, 100) + '...' : body}');
          }
          if (smsList.length > 15) {
            _log('... and ${smsList.length - 15} more');
          }
        }
      }
    } catch (e) {
      _log('✗ Error: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _fullScan() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    _log('═══ Step 2: Full SMS Scan ═══');
    
    // Reset scan guard in case it's stuck from a previous crash
    _smsService.resetScanGuard();
    _log('✓ Scan guard reset');
    
    // Also clear processed SMS table so nothing is skipped as duplicate
    await _dbService.clearAllData();
    _log('✓ Cleared processed SMS table');
    
    _log('Running full scan (isFirstLoad=true, no AI)...');

    try {
      final count = await _smsService.loadHistoricalSms(
        lastDays: 90,
        useAI: false,
        isFirstLoad: true,
      );
      _log('✓ Scan returned: $count transactions');
      if (count == 0) {
        _log('');
        _log('⚠ Still 0! Checking DB directly...');
        final txns = await _dbService.getTransactions(limit: 10);
        _log('  Transactions in DB: ${txns.length}');
        if (txns.isNotEmpty) {
          _log('  DB has data but scan returned 0 — possible duplicate skip');
        } else {
          _log('  DB is empty — scan is failing before insert');
        }
      }
    } catch (e, stack) {
      _log('✗ Error: $e');
      _log('  $stack');
    }

    setState(() => _loading = false);
  }

  Future<void> _checkDb() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    _log('═══ Step 3: Database Check ═══');

    try {
      final txns = await _dbService.getTransactions(limit: 50);
      _log('Total transactions in DB: ${txns.length}');

      if (txns.isNotEmpty) {
        _log('');
        for (int i = 0; i < txns.length && i < 10; i++) {
          final t = txns[i];
          _log('#${i + 1} ${t.type.toUpperCase()} QAR${t.amount} - ${t.category}');
          _log('   ${t.description.length > 60 ? t.description.substring(0, 60) + '...' : t.description}');
        }
      } else {
        _log('⚠ No transactions in database');
      }

      final lastSmsId = await _dbService.getLastProcessedSmsId();
      _log('');
      _log('Last processed SMS ID: ${lastSmsId ?? "none"}');
    } catch (e) {
      _log('✗ Error: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _forceInsert() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    _log('═══ Step 5: FORCE INSERT (bypasses all guards) ═══');

    try {
      // Step 1: Get raw SMS from Android
      _log('Step 1: Querying Android for SMS...');
      final result = await _smsService.debugRawSmsQuery();
      if (result == null) {
        _log('✗ Android returned null — method channel failed');
        setState(() => _loading = false);
        return;
      }
      final List<dynamic> smsList = result as List<dynamic>;
      _log('✓ Got ${smsList.length} SMS from Android');

      // Step 2: Clear old data
      _log('Step 2: Clearing old data...');
      await _dbService.clearAllData();
      _log('✓ Cleared');

      // Step 3: Process each SMS manually
      int saved = 0;
      int skippedNonFinancial = 0;
      int skippedError = 0;

      for (int i = 0; i < smsList.length; i++) {
        final msg = smsList[i] as Map<dynamic, dynamic>;
        final body = msg['body'] as String? ?? '';
        final sender = msg['sender'] as String? ?? 'Unknown';
        final timestamp = msg['timestamp'] as int? ?? 0;
        final smsId = msg['sms_id']?.toString();

        if (body.isEmpty) continue;

        final isFin = _smsService.isFinancialSmsForDebug(body);
        if (!isFin) {
          skippedNonFinancial++;
          continue;
        }

        try {
          // Create transaction manually
          final txn = _createTransactionFromSms(body, sender, timestamp, i, smsId);
          
          // Insert directly
          if (smsId != null) {
            try {
              await _dbService.insertTransactionWithSmsTracking(txn, smsId);
            } catch (_) {
              // Fallback: insert without tracking
              await _dbService.insertTransaction(txn);
            }
          } else {
            await _dbService.insertTransaction(txn);
          }
          
          saved++;
          _log('✓ Saved: ${txn.type.toUpperCase()} QAR${txn.amount} - ${txn.description.length > 40 ? txn.description.substring(0, 40) + '...' : txn.description}');
        } catch (e) {
          skippedError++;
          _log('✗ Error on SMS from $sender: $e');
        }
      }

      _log('');
      _log('═══ RESULT ═══');
      _log('Total SMS: ${smsList.length}');
      _log('Non-financial skipped: $skippedNonFinancial');
      _log('Errors skipped: $skippedError');
      _log('✓ Saved: $saved');

      // Verify
      final txns = await _dbService.getTransactions(limit: 10);
      _log('');
      _log('Verification - DB now has: ${txns.length} transactions');
    } catch (e, stack) {
      _log('✗ Fatal error: $e');
      _log('  $stack');
    }

    setState(() => _loading = false);
  }

  app_txn.Transaction _createTransactionFromSms(String body, String sender, int timestamp, int index, String? smsId) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final amount = _extractAmount(body);
    final type = _extractType(body);
    final desc = _extractDescription(body);

    return app_txn.Transaction(
      id: '${timestamp}_${index}_force',
      amount: amount,
      type: type,
      category: 'Other',
      description: desc,
      date: date,
      sender: sender,
      isCategorizedByAI: false,
      aiConfidence: 0.0,
      smsId: smsId,
    );
  }

  double _extractAmount(String body) {
    final pattern = RegExp(r'(?:QAR|QR\.?|Rs\.?|₹|\$)\s*([0-9,]+\.?[0-9]*)', caseSensitive: false);
    final match = pattern.firstMatch(body);
    if (match != null) {
      return double.parse(match.group(1)!.replaceAll(',', ''));
    }
    return 0.0;
  }

  String _extractType(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('credit') || lower.contains('deposited') || lower.contains('received') || lower.contains('refund')) {
      return 'credit';
    }
    return 'debit';
  }

  String _extractDescription(String body) {
    if (body.length > 80) return body.substring(0, 80) + '...';
    return body;
  }

  Future<void> _checkFinancial() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    _log('═══ Step 4: Financial SMS Check ═══');
    _log('Checking which SMS are classified as financial...');

    try {
      final result = await _smsService.debugRawSmsQuery();
      if (result != null) {
        final List<dynamic> smsList = result as List<dynamic>;
        int financial = 0;
        int nonFinancial = 0;

        for (final msg in smsList) {
          final m = msg as Map<dynamic, dynamic>;
          final body = m['body'] as String? ?? '';
          final sender = m['sender'] as String? ?? 'Unknown';
          final isFin = _smsService.isFinancialSmsForDebug(body);

          if (isFin) {
            financial++;
            _log('✓ FINANCIAL [$sender] ${body.substring(0, body.length < 80 ? body.length : 80)}');
          } else {
            nonFinancial++;
          }
        }

        _log('');
        _log('Summary: $financial financial, $nonFinancial non-financial out of ${smsList.length} total');
      }
    } catch (e) {
      _log('✗ Error: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete all transactions and SMS tracking. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.clearAllData();
      setState(() => _output = '✓ All data cleared. Tap "1. Raw SMS Query" to start fresh.');
    }
  }
}
