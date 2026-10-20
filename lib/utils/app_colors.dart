import 'package:flutter/material.dart';

/// Semantic aliases keep every screen on the same Material 3 color roles.
extension ScheduleColors on BuildContext {
  AppPalette get colors => AppPalette(Theme.of(this).colorScheme);
}

abstract final class AppColors {
  static const primary = Color(0xFF356A51);

  static final Map<int, ColorScheme> _courseSchemes = {};

  /// fromSeed 会生成整套色板，课程块每次 build 都调用代价很高，按颜色缓存。
  static ColorScheme colorSchemeFor(int colorValue, Brightness brightness) {
    final key = colorValue * 2 + (brightness == Brightness.dark ? 1 : 0);
    final cached = _courseSchemes[key];
    if (cached != null) return cached;
    if (_courseSchemes.length >= 128) _courseSchemes.clear();
    return _courseSchemes[key] = ColorScheme.fromSeed(
      seedColor: Color(colorValue),
      brightness: brightness,
    );
  }
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
