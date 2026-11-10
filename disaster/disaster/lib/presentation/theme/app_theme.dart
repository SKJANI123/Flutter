import 'package:flutter/material.dart';

import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';

/// Material 3 theme + emergency-focused color system.
class AppTheme {
  AppTheme._();

  static const seed = Color(0xFFB3261E);
  static const danger = Color(0xFFB3261E);
  static const warningA = Color(0xFFF29900);
  static const warningB = Color(0xFF7C4A03);
  static const safe = Color(0xFF2E7D32);
  static const info = Color(0xFF1565C0);
  static const primary = Color(0xFFB3261E);
  static const secondary = Color(0xFF5E35B1);

  static Color forLevel(AlertLevel level) => switch (level) {
    AlertLevel.critical => danger,
    AlertLevel.danger => const Color(0xFF8C1D18),
    AlertLevel.warning => warningA,
    AlertLevel.safe => safe,
  };

  static Color alertColor(AlertLevel level) => forLevel(level);

  static Color severityColor(Severity severity) => switch (severity) {
    Severity.extreme => danger,
    Severity.severe => const Color(0xFFE53935),
    Severity.moderate => warningA,
    Severity.minor => const Color(0xFFFBBC04),
    Severity.info => info,
  };

  static IconData typeIcon(DisasterType type) => switch (type) {
    DisasterType.earthquake => Icons.vibration,
    DisasterType.flood => Icons.water,
    DisasterType.cyclone => Icons.tornado,
    DisasterType.tsunami => Icons.emoji_nature,
    DisasterType.landslide => Icons.terrain,
    DisasterType.wildfire => Icons.local_fire_department,
    DisasterType.heavyRain => Icons.umbrella,
    DisasterType.lightning => Icons.bolt,
    DisasterType.storm => Icons.air,
    DisasterType.extremeHeat => Icons.wb_sunny,
    DisasterType.volcano => Icons.volcano,
  };

  static Color typeColor(DisasterType type) => switch (type) {
    DisasterType.earthquake => const Color(0xFF6D4C41),
    DisasterType.flood => const Color(0xFF0277BD),
    DisasterType.cyclone => const Color(0xFF00838F),
    DisasterType.tsunami => const Color(0xFF00695C),
    DisasterType.landslide => const Color(0xFF8D6E63),
    DisasterType.wildfire => const Color(0xFFE64A19),
    DisasterType.heavyRain => const Color(0xFF4FC3F7),
    DisasterType.lightning => const Color(0xFFFFB300),
    DisasterType.storm => const Color(0xFF546E7A),
    DisasterType.extremeHeat => const Color(0xFFF57F17),
    DisasterType.volcano => const Color(0xFFBF360C),
  };

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F6F3),
    );
    return _polish(base);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFFB4AB),
      brightness: Brightness.dark,
    );
    return _polish(ThemeData(useMaterial3: true, colorScheme: scheme));
  }

  static ThemeData _polish(ThemeData base) {
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: base.colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(thickness: 0.5, space: 0.5),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
