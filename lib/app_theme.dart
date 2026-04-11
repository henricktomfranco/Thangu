import 'package:flutter/material.dart';

/// Centralized theme for the Thangu app.
/// A premium dark-mode-first design with glassmorphic accents.
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ───────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1); // Indigo-600
  static const Color primaryLight = Color(0xFF818CF8); // Indigo-400
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo-800
  static const Color accent = Color(0xFF06B6D4); // Cyan-500
  static const Color accentGreen = Color(0xFF10B981); // Emerald-500
  static const Color accentRed = Color(0xFFEF4444); // Red-500
  static const Color accentOrange = Color(0xFFFB923C); // Orange-400
  static const Color accentYellow = Color(0xFFEAB308); // Amber-500

  // ─── Surface / Background ───────────────────────────────────
  static const Color scaffoldBg = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252540);
  static const Color surfaceCard = Color(0xFF1E1E35);
  static const Color surfaceInput = Color(0xFF2A2A45);

  // ─── Text ───────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9E9EB8);
  static const Color textTertiary = Color(0xFF6E6E8A);

  // ─── Income / Expense ───────────────────────────────────────
  static const Color income = Color(0xFF69F0AE);
  static const Color expense = Color(0xFFFF5252);

  // ─── Gradients ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E35), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient balanceGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)], // Indigo to Cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient insightGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Radii ──────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusRound = 24;

  // ─── Shadows ────────────────────────────────────────────────
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Decorations ────────────────────────────────────────────
  static BoxDecoration glassDecoration({
    double opacity = 0.08,
    double borderRadius = radiusLg,
  }) =>
      BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      );

  static BoxDecoration cardDecoration = BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
    boxShadow: softShadow,
  );

  // ─── Text Styles ────────────────────────────────────────────
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textTertiary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: textTertiary,
    letterSpacing: 0.5,
  );

  static const TextStyle amountLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -1,
  );

  static const TextStyle amountMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  // ─── ThemeData ──────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: surface,
          error: accentRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: heading2,
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceInput,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: textTertiary),
          labelStyle: const TextStyle(color: textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textTertiary,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withOpacity(0.06),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceLight,
          contentTextStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: true,
      );

  // ─── Helpers ────────────────────────────────────────────────
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Transportation':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Bills & Utilities':
        return Icons.receipt_long_rounded;
      case 'Groceries':
        return Icons.local_grocery_store_rounded;
      case 'Healthcare':
        return Icons.favorite_rounded;
      case 'Income':
        return Icons.account_balance_rounded;
      case 'Transfer':
        return Icons.swap_horiz_rounded;
      case 'Education':
        return Icons.school_rounded;
      case 'Travel':
        return Icons.flight_rounded;
      case 'Personal Care':
        return Icons.spa_rounded;
      case 'Gifts & Donations':
        return Icons.card_giftcard_rounded;
      case 'Fees & Charges':
        return Icons.money_off_rounded;
      case 'Investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return const Color(0xFFFFA726);
      case 'Transportation':
        return const Color(0xFF42A5F5);
      case 'Shopping':
        return const Color(0xFFEC407A);
      case 'Entertainment':
        return const Color(0xFFAB47BC);
      case 'Bills & Utilities':
        return const Color(0xFF78909C);
      case 'Groceries':
        return const Color(0xFF66BB6A);
      case 'Healthcare':
        return const Color(0xFFEF5350);
      case 'Income':
        return accentGreen;
      case 'Transfer':
        return accent;
      case 'Education':
        return const Color(0xFF5C6BC0);
      case 'Travel':
        return const Color(0xFF26C6DA);
      case 'Personal Care':
        return const Color(0xFFE91E63);
      case 'Gifts & Donations':
        return const Color(0xFFFF7043);
      case 'Fees & Charges':
        return const Color(0xFF8D6E63);
      case 'Investment':
        return const Color(0xFF26A69A);
      default:
        return textSecondary;
    }
  }
}
