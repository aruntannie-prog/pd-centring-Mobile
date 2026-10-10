import 'package:flutter/material.dart';

import '../domain/expiry.dart';

/// SD Centring design system.
///
/// Warm off-white surfaces, ink-dark hero areas and an ember-orange accent,
/// set in Manrope. Deliberately different from the PD Centring app.
class SdColors {
  SdColors._();

  static const ember = Color(0xFFEE5A24);
  static const emberDeep = Color(0xFFC2410C);
  static const ink = Color(0xFF14161A);
  static const ink2 = Color(0xFF262A31);

  // Kept for older call sites.
  static const orange = ember;
  static const graphite = ink;

  // Status colours (strong = text/icons, tints are derived).
  static const expired = Color(0xFFE5484D);
  static const today = Color(0xFFF76B15);
  static const soon = Color(0xFFD48A00);
  static const active = Color(0xFF1E9E63);
  static const closed = Color(0xFF8B8F98);

  static const whatsApp = Color(0xFF128C7E);
}

/// Colours that differ between light and dark mode.
@immutable
class SdTokens extends ThemeExtension<SdTokens> {
  const SdTokens({
    required this.card,
    required this.muted,
    required this.line,
    required this.field,
    required this.shadow,
  });

  final Color card;
  final Color muted;
  final Color line;
  final Color field;
  final List<BoxShadow> shadow;

  static const light = SdTokens(
    card: Colors.white,
    muted: Color(0xFF6B6F78),
    line: Color(0xFFEAE6DF),
    field: Color(0xFFF3F0EB),
    shadow: [
      BoxShadow(color: Color(0x0A14161A), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0F14161A), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const dark = SdTokens(
    card: Color(0xFF1B1E23),
    muted: Color(0xFF9BA1A9),
    line: Color(0xFF2B2F36),
    field: Color(0xFF23272D),
    shadow: [],
  );

  @override
  SdTokens copyWith() => this;

  @override
  SdTokens lerp(SdTokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension SdThemeX on BuildContext {
  SdTokens get sd => Theme.of(this).extension<SdTokens>() ?? SdTokens.light;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final tokens = dark ? SdTokens.dark : SdTokens.light;
  final ink = dark ? const Color(0xFFF2F1EE) : SdColors.ink;
  final background = dark ? const Color(0xFF0F1114) : const Color(0xFFF5F3EF);
  final primary = dark ? const Color(0xFFFF7A45) : SdColors.ember;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: SdColors.ember,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: background,
        onSurface: ink,
        onSurfaceVariant: tokens.muted,
        outline: tokens.line,
        outlineVariant: tokens.line,
        surfaceContainerHighest: tokens.field,
        surfaceTint: Colors.transparent,
      );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Manrope',
  );

  TextStyle? t(TextStyle? s, double size, FontWeight w, {double ls = 0}) =>
      s?.copyWith(fontSize: size, fontWeight: w, letterSpacing: ls, color: ink);

  final text = base.textTheme.copyWith(
    displaySmall: t(base.textTheme.displaySmall, 36, FontWeight.w800, ls: -1),
    headlineMedium: t(
      base.textTheme.headlineMedium,
      28,
      FontWeight.w800,
      ls: -0.6,
    ),
    headlineSmall: t(
      base.textTheme.headlineSmall,
      24,
      FontWeight.w800,
      ls: -0.4,
    ),
    titleLarge: t(base.textTheme.titleLarge, 20, FontWeight.w800, ls: -0.3),
    titleMedium: t(base.textTheme.titleMedium, 16, FontWeight.w700, ls: -0.1),
    titleSmall: t(base.textTheme.titleSmall, 14, FontWeight.w700),
    bodyLarge: t(base.textTheme.bodyLarge, 15, FontWeight.w500),
    bodyMedium: t(base.textTheme.bodyMedium, 14, FontWeight.w500),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: tokens.muted,
    ),
    labelLarge: t(base.textTheme.labelLarge, 14, FontWeight.w700),
    labelMedium: t(base.textTheme.labelMedium, 12, FontWeight.w700),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: tokens.muted,
    ),
  );

  final radius16 = BorderRadius.circular(14);

  return base.copyWith(
    extensions: [tokens],
    textTheme: text,
    scaffoldBackgroundColor: background,
    dividerColor: tokens.line,
    dividerTheme: DividerThemeData(color: tokens.line, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: TextStyle(color: tokens.muted, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(color: tokens.muted, fontWeight: FontWeight.w500),
      prefixIconColor: tokens.muted,
      suffixIconColor: tokens.muted,
      border: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: const BorderSide(color: SdColors.expired, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: const BorderSide(color: SdColors.expired, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: radius16),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: ink,
        side: BorderSide(color: tokens.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: radius16),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.card,
      selectedColor: ink,
      side: BorderSide(color: tokens.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: dark ? SdColors.ink : Colors.white,
      ),
      checkmarkColor: dark ? SdColors.ink : Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: primary.withValues(alpha: 0.14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary : tokens.muted,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? ink : tokens.muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.card,
      indicatorColor: primary.withValues(alpha: 0.14),
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: tokens.muted),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: tokens.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: tokens.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: SdColors.ink,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2B2F36) : SdColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: text.bodyMedium,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.muted,
      titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
      subtitleTextStyle: text.bodySmall,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: tokens.field,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: SdColors.expired),
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
