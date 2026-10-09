import 'package:flutter/material.dart';

import '../domain/expiry.dart';

/// SD Centring look: safety orange on graphite. Deliberately different from
/// the PD Centring app (blue, serif headings, custom bottom bar).
class SdColors {
  SdColors._();

  static const orange = Color(0xFFE8590C);
  static const graphite = Color(0xFF1F2328);

  static const expired = Color(0xFFD92D20);
  static const today = Color(0xFFE8590C);
  static const soon = Color(0xFFB54708);
  static const active = Color(0xFF067647);
  static const closed = Color(0xFF667085);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: SdColors.orange,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFFF8A4C) : SdColors.orange,
        onPrimary: dark ? SdColors.graphite : Colors.white,
        surface: dark ? const Color(0xFF16191D) : const Color(0xFFFAF8F6),
      );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF16191D) : SdColors.graphite,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF1F2328) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}

Color statusColor(ExpiryStatus s) => switch (s) {
  ExpiryStatus.expired => SdColors.expired,
  ExpiryStatus.dueToday => SdColors.today,
  ExpiryStatus.dueSoon => SdColors.soon,
  ExpiryStatus.active => SdColors.active,
  ExpiryStatus.closed => SdColors.closed,
};

String statusName(ExpiryStatus s) => switch (s) {
  ExpiryStatus.expired => 'Expired',
  ExpiryStatus.dueToday => 'Due today',
  ExpiryStatus.dueSoon => 'Expiring soon',
  ExpiryStatus.active => 'Active',
  ExpiryStatus.closed => 'Returned',
};

IconData statusIcon(ExpiryStatus s) => switch (s) {
  ExpiryStatus.expired => Icons.error_rounded,
  ExpiryStatus.dueToday => Icons.today_rounded,
  ExpiryStatus.dueSoon => Icons.hourglass_bottom_rounded,
  ExpiryStatus.active => Icons.local_shipping_rounded,
  ExpiryStatus.closed => Icons.task_alt_rounded,
};
