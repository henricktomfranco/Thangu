import 'package:thangu/services/account_service.dart';

void main() {
  final accountService = AccountService();

  // Test SMS messages
  final testMessages = [
    'Debit Card **6260 was used for QAR 38.00 at MCDONALDS OLD AIRPOR at 00:57 10-Apr-26 Balance: QAR 17,189.73 Enquiry 44490000',
    'Credit Card ***1234 payment of QAR 50.00 processed',
    'Account ****4321: QAR 100.00 transferred to savings',
    'Transaction XXX6455 approved for QAR 75.00',
    'No account info in this message',
  ];

  for (final message in testMessages) {
    final accountInfo = accountService.extractAccountInfo(message);
    print("SMS: '${message.substring(0, 30)}...'");
    print("Account Number: ${accountInfo.number}");
    print("Account Name: ${accountInfo.name}");
    print("Account Type: ${accountInfo.type}");
    print("---");
  }
}
