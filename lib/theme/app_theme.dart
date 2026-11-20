import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF4A8B9A);
  static const Color primaryLight = Color(0xFF8EBDC6);

  static final Color primaryAlpha06 = primary.withValues(alpha: 0.06);
  static final Color primaryAlpha08 = primary.withValues(alpha: 0.08);
  static final Color primaryAlpha10 = primary.withValues(alpha: 0.10);
  static final Color primaryAlpha12 = primary.withValues(alpha: 0.12);
  static final Color primaryAlpha15 = primary.withValues(alpha: 0.15);
  static final Color primaryAlpha25 = primary.withValues(alpha: 0.25);
  static final Color primaryAlpha50 = primary.withValues(alpha: 0.50);
  static final Color primaryAlpha60 = primary.withValues(alpha: 0.60);
  static final Color primaryAlpha70 = primary.withValues(alpha: 0.70);
  static final Color primaryLightAlpha30 = primaryLight.withValues(alpha: 0.30);
  static final Color whiteAlpha80 = Colors.white.withValues(alpha: 0.80);

  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightPrimarySurface = Color(0xFFE3E9F0);
  static const Color lightTextPrimary = Color(0xFF2C3E50);
  static const Color lightTextSecondary = Color(0xFF7F8C8D);
  static const Color lightCardBackground = Colors.white;
  static const Color lightDivider = Color(0xFFEAEDED);

  static const Color darkBackground = Color(0xFF12181B);
  static const Color darkPrimarySurface = Color(0xFF1F2A30);
  static const Color darkTextPrimary = Color(0xFFF0F3F4);
  static const Color darkTextSecondary = Color(0xFF95A5A6);
  static const Color darkCardBackground = Color(0xFF1A2227);
  static const Color darkDivider = Color(0xFF2C3E50);

  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  static List<BoxShadow> softShadow(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> deepShadow(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.40)
          : primary.withValues(alpha: 0.15),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    background: lightBackground,
    surface: lightPrimarySurface,
    cardBackground: lightCardBackground,
    textPrimary: lightTextPrimary,
    textSecondary: lightTextSecondary,
    divider: lightDivider,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    background: darkBackground,
    surface: darkPrimarySurface,
    cardBackground: darkCardBackground,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    divider: darkDivider,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color cardBackground,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      cardColor: cardBackground,
      dividerColor: divider,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: isDark ? primaryLight : primary,
        inactiveTrackColor: isDark
            ? primaryLight.withValues(alpha: 0.2)
            : primaryLightAlpha30,
        thumbColor: isDark ? primaryLight : primary,
        overlayColor: primary.withValues(alpha: 0.1),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? primaryLight : primary;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? primaryLight.withValues(alpha: 0.5) : primaryLight;
          }
          return Colors.grey.shade300;
        }),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appPrimary => isDark ? AppTheme.primaryLight : AppTheme.primary;

  Color get appTextPrimary =>
      isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

  Color get appTextSecondary =>
      isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

  Color get appCardBackground =>
      isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground;

  Color get appDivider => isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

  Color get appPrimarySurface =>
      isDark ? AppTheme.darkPrimarySurface : AppTheme.lightPrimarySurface;

  List<BoxShadow> get appSoftShadow =>
      AppTheme.softShadow(Theme.of(this).brightness);

  BoxDecoration get appCardDecoration => BoxDecoration(
    color: appCardBackground,
    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    boxShadow: appSoftShadow,
  );
}
