import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/ai_chat_screen.dart';

void main() {
  runApp(const ThanguApp());
}

class ThanguApp extends StatelessWidget {
  const ThanguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thangu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}