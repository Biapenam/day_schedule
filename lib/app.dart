import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/app_colors.dart';

class DayScheduleApp extends StatelessWidget {
  const DayScheduleApp({super.key, this.themeMode = ThemeMode.system});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Day Schedule',
    debugShowCheckedModeBanner: false,
    theme: buildScheduleTheme(),
    darkTheme: buildScheduleTheme(brightness: Brightness.dark),
    themeMode: themeMode,
    home: const HomeScreen(),
  );
}

/// One theme for forms, navigation, dialogs and the weekly workspace.
ThemeData buildScheduleTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primaryContainer: dark ? const Color(0xFF254D38) : const Color(0xFFDCEEDF),
    onPrimaryContainer: dark
        ? const Color(0xFFBDECCB)
        : const Color(0xFF163C29),
    surface: dark ? const Color(0xFF111714) : const Color(0xFFF5F7F5),
    surfaceContainerLowest: dark ? const Color(0xFF171E1A) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xFF1D2520)
        : const Color(0xFFEEF2EE),
    surfaceContainerHighest: dark
        ? const Color(0xFF2B352E)
        : const Color(0xFFE8EEE8),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamilyFallback: const [
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
    ],
  );
  final text = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
      height: 1.2,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.5,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: inputBorder(scheme.outlineVariant),
      enabledBorder: inputBorder(scheme.outlineVariant),
      focusedBorder: inputBorder(scheme.primary, 2),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      elevation: 0,
      height: 72,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
  );
}
