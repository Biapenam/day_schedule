import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/app_colors.dart';

class DayScheduleApp extends StatelessWidget {
  const DayScheduleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Day Schedule',
    debugShowCheckedModeBanner: false,
    theme: buildScheduleTheme(),
    home: const HomeScreen(),
  );
}

ThemeData buildScheduleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    surface: AppColors.background,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            color: AppColors.textPrimary,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 72,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(color: AppColors.textBody),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
    ),
  );
}
