import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Colour tokens
// ---------------------------------------------------------------------------
class AppColors {
  // Brand
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFFEDECFF);
  static const secondary = Color(0xFF48CAE4);

  // Macros
  static const protein = Color(0xFFFF9A3C);
  static const fat = Color(0xFFB57BEA);
  static const carbs = Color(0xFFFF6B6B);
  static const fiber = Color(0xFF2EC4B6);

  // State
  static const success = Color(0xFF2EC4B6);
  static const warning = Color(0xFFFFB347);
  static const danger = Color(0xFFFF4D4D);

  // Surfaces — light
  static const bg = Color(0xFFF3F4F8);
  static const card = Colors.white;

  // Surfaces — dark
  static const bgDark = Color(0xFF0F0F16);
  static const cardDark = Color(0xFF1C1C2B);
  static const surfaceDark = Color(0xFF252535);
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------
class AppTheme {
  static const _buttonRadius = 16.0;

  // ── Light ──────────────────────────────────────────────────────────────
  static ThemeData get light => _build(brightness: Brightness.light);

  // ── Dark ───────────────────────────────────────────────────────────────
  static ThemeData get dark => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: isDark ? AppColors.cardDark : AppColors.card,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: isDark ? Colors.white.withValues(alpha: .9) : Colors.black87,
      displayColor:
          isDark ? Colors.white.withValues(alpha: .9) : Colors.black87,
    );

    const cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
      textTheme: textTheme,

      // ── Cards
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: cardShape,
        elevation: 0,
        color: isDark ? AppColors.cardDark : AppColors.card,
      ),

      // ── Inputs — unified look
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark
                ? AppColors.surfaceDark
                : AppColors.primary.withValues(alpha: .04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: .1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),

      // ── Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_buttonRadius)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_buttonRadius)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_buttonRadius)),
          ),
          side: BorderSide(color: AppColors.primary.withValues(alpha: .5)),
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Chips
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        backgroundColor: AppColors.primary.withValues(alpha: .08),
        selectedColor: AppColors.primary.withValues(alpha: .18),
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        centerTitle: false,
      ),

      // ── Divider
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: .08),
        thickness: 1,
        space: 1,
      ),

      // ── Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: .12),
        inactiveTrackColor: AppColors.primary.withValues(alpha: .18),
      ),

      // ── SnackBar — floating, rounded
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.black87,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actionTextColor: AppColors.primary,
      ),

      // ── Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
      ),

      // ── BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
        showDragHandle: false,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card decoration helper — lighter shadow
// ---------------------------------------------------------------------------
BoxDecoration appCardDecoration({bool isDark = false}) => BoxDecoration(
  color: isDark ? AppColors.cardDark : AppColors.card,
  borderRadius: BorderRadius.circular(20),
  boxShadow: isDark
      ? []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
);

// ---------------------------------------------------------------------------
// Macro colour helper
// ---------------------------------------------------------------------------
Color macroColor(String macro) => switch (macro.toLowerCase()) {
  'protein' => AppColors.protein,
  'carbs' => AppColors.carbs,
  'fat' => AppColors.fat,
  'fiber' => AppColors.fiber,
  _ => AppColors.primary,
};
