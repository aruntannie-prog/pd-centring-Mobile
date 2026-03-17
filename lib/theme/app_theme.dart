import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Ultra Premium Theme Extension for custom colors
class AppColors extends ThemeExtension<AppColors> {
  // Brand
  final Color brand;
  final Color brandLight;

  // Accents (Teal, Amber, Red, Indigo)
  final Color teal;
  final Color tealBg;
  final Color tealBd;

  final Color red;
  final Color redBg;
  final Color redBd;

  final Color amber;
  final Color amberBg;
  final Color amberBd;

  final Color indigo;
  final Color indigoBg;
  final Color indigoBd;

  // Neutrals / Surfaces
  final Color textMain;
  final Color textSub;
  final Color textMuted;

  final Color surface;
  final Color surfaceVariant;
  final Color border;

  // Custom Gradients/Glows
  final Color glow;
  final Color highlight;

  const AppColors({
    required this.brand,
    required this.brandLight,
    required this.teal,
    required this.tealBg,
    required this.tealBd,
    required this.red,
    required this.redBg,
    required this.redBd,
    required this.amber,
    required this.amberBg,
    required this.amberBd,
    required this.indigo,
    required this.indigoBg,
    required this.indigoBd,
    required this.textMain,
    required this.textSub,
    required this.textMuted,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.glow,
    required this.highlight,
  });

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandLight,
    Color? teal,
    Color? tealBg,
    Color? tealBd,
    Color? red,
    Color? redBg,
    Color? redBd,
    Color? amber,
    Color? amberBg,
    Color? amberBd,
    Color? indigo,
    Color? indigoBg,
    Color? indigoBd,
    Color? textMain,
    Color? textSub,
    Color? textMuted,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? glow,
    Color? highlight,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandLight: brandLight ?? this.brandLight,
      teal: teal ?? this.teal,
      tealBg: tealBg ?? this.tealBg,
      tealBd: tealBd ?? this.tealBd,
      red: red ?? this.red,
      redBg: redBg ?? this.redBg,
      redBd: redBd ?? this.redBd,
      amber: amber ?? this.amber,
      amberBg: amberBg ?? this.amberBg,
      amberBd: amberBd ?? this.amberBd,
      indigo: indigo ?? this.indigo,
      indigoBg: indigoBg ?? this.indigoBg,
      indigoBd: indigoBd ?? this.indigoBd,
      textMain: textMain ?? this.textMain,
      textSub: textSub ?? this.textSub,
      textMuted: textMuted ?? this.textMuted,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      glow: glow ?? this.glow,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealBg: Color.lerp(tealBg, other.tealBg, t)!,
      tealBd: Color.lerp(tealBd, other.tealBd, t)!,
      red: Color.lerp(red, other.red, t)!,
      redBg: Color.lerp(redBg, other.redBg, t)!,
      redBd: Color.lerp(redBd, other.redBd, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      amberBd: Color.lerp(amberBd, other.amberBd, t)!,
      indigo: Color.lerp(indigo, other.indigo, t)!,
      indigoBg: Color.lerp(indigoBg, other.indigoBg, t)!,
      indigoBd: Color.lerp(indigoBd, other.indigoBd, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }

  // --- Static Initializers for Light & Dark ---

  static const light = AppColors(
    brand: Color(0xFF14224A), // Navy
    brandLight: Color(0xFF3A4E68),
    teal: Color(0xFF097A6B),
    tealBg: Color(0xFFE2F5F3), // Soft pastel
    tealBd: Color(0xFFBBE5DF),
    red: Color(0xFFB80F1E),
    redBg: Color(0xFFFCEAEB),
    redBd: Color(0xFFF4C4C7),
    amber: Color(0xFFA85600),
    amberBg: Color(0xFFFFF2E2),
    amberBd: Color(0xFFFFDAB2),
    indigo: Color(0xFF2E3EBA),
    indigoBg: Color(0xFFE9ECFA),
    indigoBd: Color(0xFFC8CEF0),
    textMain: Color(0xFF0A1628),
    textSub: Color(0xFF3A4E68),
    textMuted: Color(0xFF6A7A90),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF4F8FC),
    border: Color(0xFFE2EAF2),
    glow: Color(0x14040A18), // Soft dark glow
    highlight: Color(0xFFFFFFFF), // Shine
  );

  // ── Rathinamangalam branch: Purple / Violet identity ──────────────────────
  static const lightBranch2 = AppColors(
    brand: Color(0xFF5B21B6),       // Deep Violet (was Navy)
    brandLight: Color(0xFF7C3AED),
    teal: Color(0xFF097A6B),
    tealBg: Color(0xFFE2F5F3),
    tealBd: Color(0xFFBBE5DF),
    red: Color(0xFFB80F1E),
    redBg: Color(0xFFFCEAEB),
    redBd: Color(0xFFF4C4C7),
    amber: Color(0xFFA85600),
    amberBg: Color(0xFFFFF2E2),
    amberBd: Color(0xFFFFDAB2),
    indigo: Color(0xFF6D28D9),      // Violet (was Indigo-blue)
    indigoBg: Color(0xFFEDE9FE),
    indigoBd: Color(0xFFC4B5FD),
    textMain: Color(0xFF0A1628),
    textSub: Color(0xFF3A4E68),
    textMuted: Color(0xFF6A7A90),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF5F3FF),  // Subtle violet tint
    border: Color(0xFFE4DEFF),
    glow: Color(0x14040A18),
    highlight: Color(0xFFFFFFFF),
  );

  static const darkBranch2 = AppColors(
    brand: Color(0xFFDDD6FE),       // Light Violet (was Off-white/Ice)
    brandLight: Color(0xFFA78BFA),
    teal: Color(0xFF20E5CD),
    tealBg: Color(0x2620E5CD),
    tealBd: Color(0x5920E5CD),
    red: Color(0xFFFF4D5E),
    redBg: Color(0x26FF4D5E),
    redBd: Color(0x59FF4D5E),
    amber: Color(0xFFFFB347),
    amberBg: Color(0x26FFB347),
    amberBd: Color(0x59FFB347),
    indigo: Color(0xFFA78BFA),      // Neon Violet (was Neon Indigo)
    indigoBg: Color(0x26A78BFA),
    indigoBd: Color(0x59A78BFA),
    textMain: Color(0xFFF4F8FC),
    textSub: Color(0xFFC8D4E0),
    textMuted: Color(0xFF6A7A90),
    surface: Color(0xFF100D1A),     // Deep dark with purple tint
    surfaceVariant: Color(0xFF1A1628),
    border: Color(0xFF2E2440),
    glow: Color(0x66000000),
    highlight: Color(0x14FFFFFF),
  );

  static const dark = AppColors(
    brand: Color(0xFFE8F0F8), // Off-white/Ice
    brandLight: Color(0xFF9AAABB),
    teal: Color(0xFF20E5CD), // Neon Teal
    tealBg: Color(0x2620E5CD), // Translucent glow
    tealBd: Color(0x5920E5CD),
    red: Color(0xFFFF4D5E), // Neon Red
    redBg: Color(0x26FF4D5E),
    redBd: Color(0x59FF4D5E),
    amber: Color(0xFFFFB347), // Neon Amber
    amberBg: Color(0x26FFB347),
    amberBd: Color(0x59FFB347),
    indigo: Color(0xFF7B8CFF), // Neon Indigo
    indigoBg: Color(0x267B8CFF),
    indigoBd: Color(0x597B8CFF),
    textMain: Color(0xFFF4F8FC), // Almost White
    textSub: Color(0xFFC8D4E0),
    textMuted: Color(0xFF6A7A90),
    surface: Color(0xFF0D1421), // Deep Obsidian
    surfaceVariant: Color(0xFF162133), // Slightly elevated obsidian
    border: Color(0xFF26364D),
    glow: Color(0x66000000), // Deep black glow
    highlight: Color(0x14FFFFFF), // Subtle glass shine
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final colors = AppColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor:
          const Color(0xFFF8FAFC), // Ultra premium soft background
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF14224A),
        brightness: Brightness.light,
        background: const Color(0xFFF8FAFC),
        surface: colors.surface,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colors.textMain,
        displayColor: colors.textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Glassmorphic approach
        foregroundColor: colors.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: colors.textMain,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colors = AppColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF050A14), // True dark space
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF20E5CD),
        brightness: Brightness.dark,
        background: const Color(0xFF050A14),
        surface: colors.surface,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colors.textMain,
        displayColor: colors.textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: colors.textMain,
        ),
      ),
    );
  }

  // ── Rathinamangalam branch themes ──────────────────────────────────────────

  static ThemeData get lightThemeBranch2 {
    final colors = AppColors.lightBranch2;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F6FF), // Soft violet-white
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D28D9),
        brightness: Brightness.light,
        background: const Color(0xFFF8F6FF),
        surface: colors.surface,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colors.textMain,
        displayColor: colors.textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: colors.textMain,
        ),
      ),
    );
  }

  static ThemeData get darkThemeBranch2 {
    final colors = AppColors.darkBranch2;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF08070F), // Deep violet-black
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFA78BFA),
        brightness: Brightness.dark,
        background: const Color(0xFF08070F),
        surface: colors.surface,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colors.textMain,
        displayColor: colors.textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: colors.textMain,
        ),
      ),
    );
  }
}

// Extension to easily access AppColors anywhere
extension ThemeColorsExt on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

// Text styles (context-aware helpers)
TextStyle playfair(BuildContext context,
        {double size = 16,
        FontWeight weight = FontWeight.w900,
        Color? color,
        bool italic = false}) =>
    GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: weight,
        color: color ?? context.appColors.textMain,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal);

TextStyle jakarta(BuildContext context,
        {double size = 14,
        FontWeight weight = FontWeight.w500,
        Color? color}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? context.appColors.textMain);
