import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  // Extracted from your Station Football screenshots
  static const Color primaryPurple = Color(0xFF6C2BD9);
  static const Color deepPurple = Color(0xFF3B1877);
  static const Color darkNavyBg = Color(0xFF0D1326);
  static const Color darkNavyCard = Color(0xFF161F38);
  static const Color lightBg = Color(0xFFF4F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color emeraldGreen = Color(0xFF17B957);
  static const Color pitchLineGreen = Color(0xFF23C964);
  static const Color amberOrange = Color(0xFFEB7B26);
  static const Color captainIndigo = Color(0xFF110A30);
  static const Color cyanAccent = Color(0xFF00D4FF);

  static Color fdrColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return const Color(0xFF108538);
      case 2:
        return const Color(0xFF17B957);
      case 3:
        return const Color(0xFF9EA6B8);
      case 4:
        return const Color(0xFFE03A3E);
      case 5:
        return const Color(0xFF8B0D32);
      default:
        return const Color(0xFF9EA6B8);
    }
  }
}

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_theme') ?? true;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final nextDark = themeMode.value != ThemeMode.dark;
    themeMode.value = nextDark ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('is_dark_theme', nextDark);
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkNavyBg,
      cardColor: AppColors.darkNavyCard,
      primaryColor: AppColors.primaryPurple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.emeraldGreen,
        tertiary: AppColors.amberOrange,
        surface: AppColors.darkNavyCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkNavyBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkNavyCard,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      primaryColor: AppColors.primaryPurple,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.emeraldGreen,
        tertiary: AppColors.amberOrange,
        surface: AppColors.lightCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: Color(0xFF0D1326),
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightCard,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.black45,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
