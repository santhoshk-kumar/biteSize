import 'package:flutter/material.dart';

/// Semantic color palette for BiteSize's modern Gen-Z aesthetic.
/// Built with high-voltage neon accents, OLED obsidian surfaces, and punchy contrast.
@immutable
class ZenColors extends ThemeExtension<ZenColors> {
  const ZenColors({
    required this.sage,
    required this.sageSoft,
    required this.surfaceSubtle,
    required this.borderSoft,
    required this.inkPrimary,
    required this.inkMuted,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
    required this.fiber,
    required this.gentleClay,
  });

  /// Primary energetic accent (Neon Acid Lime / Volt in dark, Punchy Emerald in light)
  final Color sage;
  final Color sageSoft;
  final Color surfaceSubtle;
  final Color borderSoft;
  final Color inkPrimary;
  final Color inkMuted;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color water;
  final Color fiber;
  final Color gentleClay;

  static const ZenColors light = ZenColors(
    sage: Color(0xFF059669), // Rich Forest Emerald
    sageSoft: Color(0xFFD1FAE5), // Mint Tint
    surfaceSubtle: Color(0xFFF1F5F9), // Crisp Slate Surface
    borderSoft: Color(0xFFE2E8F0), // Cool Grey Border
    inkPrimary: Color(0xFF0F172A), // Deep Slate Black
    inkMuted: Color(0xFF64748B), // Slate Muted
    protein: Color(0xFF0284C7), // Ocean Cyan
    carbs: Color(0xFFD97706), // Warm Amber
    fat: Color(0xFFE11D48), // Velvet Rose
    water: Color(0xFF0D9488), // Mineral Teal
    fiber: Color(0xFF7C3AED), // Royal Purple
    gentleClay: Color(0xFFE11D48), // Hot Coral Alert
  );

  static const ZenColors dark = ZenColors(
    sage: Color(0xFF10B981), // Refined Emerald Jewel (Luxury Oura/Apple Fitness+)
    sageSoft: Color(0xFF064E3B), // Deep Emerald Glow Tint
    surfaceSubtle: Color(0xFF1A202C), // Secondary Titanium Gunmetal
    borderSoft: Color(0xFF222938), // Refined Metallic Hairline Border
    inkPrimary: Color(0xFFF8FAFC), // Crisp Titanium White
    inkMuted: Color(0xFF94A3B8), // Cool Slate Muted
    protein: Color(0xFF38BDF8), // Ice Cyan Pop
    carbs: Color(0xFFFBBF24), // Warm Champagne Amber
    fat: Color(0xFFFB7185), // Velvet Coral Rose
    water: Color(0xFF2DD4BF), // Mineral Aquamarine
    fiber: Color(0xFFA855F7), // Royal Amethyst
    gentleClay: Color(0xFFF43F5E), // Coral Alert
  );

  @override
  ZenColors copyWith({
    Color? sage,
    Color? sageSoft,
    Color? surfaceSubtle,
    Color? borderSoft,
    Color? inkPrimary,
    Color? inkMuted,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? water,
    Color? fiber,
    Color? gentleClay,
  }) {
    return ZenColors(
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderSoft: borderSoft ?? this.borderSoft,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkMuted: inkMuted ?? this.inkMuted,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      water: water ?? this.water,
      fiber: fiber ?? this.fiber,
      gentleClay: gentleClay ?? this.gentleClay,
    );
  }

  @override
  ZenColors lerp(ThemeExtension<ZenColors>? other, double t) {
    if (other is! ZenColors) return this;
    return ZenColors(
      sage: Color.lerp(sage, other.sage, t)!,
      sageSoft: Color.lerp(sageSoft, other.sageSoft, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      water: Color.lerp(water, other.water, t)!,
      fiber: Color.lerp(fiber, other.fiber, t)!,
      gentleClay: Color.lerp(gentleClay, other.gentleClay, t)!,
    );
  }
}

extension ZenThemeContext on BuildContext {
  ZenColors get zen =>
      Theme.of(this).extension<ZenColors>() ?? ZenColors.dark;
}

class ZenTheme {
  static ThemeData light() => _build(Brightness.light, ZenColors.light);
  static ThemeData dark() => _build(Brightness.dark, ZenColors.dark);

  static ThemeData _build(Brightness brightness, ZenColors zen) {
    final isLight = brightness == Brightness.light;
    final scaffoldBg =
        isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0B0D11); // Deep Titanium Matte
    final cardSurface =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF13171F); // Smoked Gunmetal Bento Surface

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: zen.sage,
      onPrimary: isLight ? Colors.white : const Color(0xFF090A0E),
      primaryContainer: zen.sageSoft,
      onPrimaryContainer: isLight ? zen.inkPrimary : zen.sage,
      secondary: zen.protein,
      onSecondary: const Color(0xFF090A0E),
      secondaryContainer: zen.surfaceSubtle,
      onSecondaryContainer: zen.inkPrimary,
      tertiary: zen.carbs,
      onTertiary: const Color(0xFF090A0E),
      error: zen.gentleClay,
      onError: Colors.white,
      surface: cardSurface,
      onSurface: zen.inkPrimary,
      surfaceContainerHighest: zen.surfaceSubtle,
      onSurfaceVariant: zen.inkMuted,
      outline: zen.borderSoft,
      outlineVariant: zen.borderSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      extensions: [zen],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: zen.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: zen.borderSoft, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: zen.borderSoft, width: 1.2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zen.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: zen.borderSoft, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: zen.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: zen.sage, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: zen.surfaceSubtle,
        selectedColor: zen.sageSoft,
        side: BorderSide(color: zen.borderSoft, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        labelStyle: TextStyle(
          color: zen.inkPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF0F172A) : const Color(0xFF1E2433),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zen.sage,
          foregroundColor: isLight ? Colors.white : const Color(0xFF090A0E),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zen.inkPrimary,
          side: BorderSide(color: zen.borderSoft, width: 1.2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        elevation: 0,
        indicatorColor: zen.sage,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isLight ? Colors.white : const Color(0xFF090A0E),
              size: 24,
            );
          }
          return IconThemeData(color: zen.inkMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: zen.inkPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: zen.inkMuted,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
    );
  }
}
