import 'package:flutter/material.dart';

/// Semantic aliases keep every screen on the same Material 3 color roles.
extension ScheduleColors on BuildContext {
  AppPalette get colors => AppPalette(Theme.of(this).colorScheme);
}

abstract final class AppColors {
  static const primary = Color(0xFF356A51);
}

class AppPalette {
  const AppPalette(this.scheme);
  final ColorScheme scheme;
  Color get primary => scheme.primary;
  Color get onPrimary => scheme.onPrimary;
  Color get secondary => scheme.secondary;
  Color get background => scheme.surface;
  Color get surface => scheme.surfaceContainerLowest;
  Color get surfaceContainer => scheme.surfaceContainerLow;
  Color get primaryContainer => scheme.primaryContainer;
  Color get onPrimaryContainer => scheme.onPrimaryContainer;
  Color get textPrimary => scheme.onSurface;
  Color get textBody => scheme.onSurfaceVariant;
  Color get textSecondary => scheme.onSurfaceVariant;
  Color get inputFill => scheme.surfaceContainerHighest;
  Color get borderLight => scheme.outlineVariant;
  Color get error => scheme.error;
}
