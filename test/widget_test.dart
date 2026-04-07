// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of the widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thangu/main.dart';

void main() {
  testWidgets('Thangu app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ThanguApp());

    // Verify that the app starts with HomeScreen
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
  });
}
