import 'package:flutter/material.dart';

/// Colour tokens of the "pub receipt" design: paper ground, white receipt
/// slips, ink text, emerald for actions and money coming in.
class AppColors {
  AppColors._();

  // Paper world
  static const Color paper = Color(0xFFEEEAE0);
  static const Color slip = Color(0xFFFFFDF8);
  static const Color ink = Color(0xFF1B1A17);
  static const Color muted = Color(0xFF6B675E);
  static const Color mutedStrong = Color(0xFF5C584F);
  static const Color body = Color(0xFF3F3C35);
  static const Color line = Color(0xFFDDD8CC);
  static const Color hairline = Color(0xFFEAE6DC);
  static const Color outline = Color(0xFF857F72);
  static const Color dots = Color(0xFFB5AFA2);
  static const Color segment = Color(0xFFE0DBCF);
  static const Color handle = Color(0xFFC9C3B6);
  static const Color track = Color(0xFFCFC8B8);
  static const Color doneFill = Color(0xFFF7F4EC);
  static const Color soft = Color(0xFFF3EFE4);
  static const Color disabled = Color(0xFFDDD8CC);
  static const Color disabledText = Color(0xFF9A9488);

  // Actions and money
  static const Color emerald = Color(0xFF0B7A53);
  static const Color emeraldDark = Color(0xFF075C3E);
  static const Color mint = Color(0xFFCDEBDD);
  static const Color red = Color(0xFFB4232A);

  // Open / needs attention
  static const Color amber = Color(0xFF8A5A00);
  static const Color amberLine = Color(0xFFD6A84A);
  static const Color amberStrong = Color(0xFFB7790F);
  static const Color amberBg = Color(0xFFFBF1DD);
  static const Color amberBorder = Color(0xFFE3C98F);
  static const Color amberText = Color(0xFF5C3D00);

  // Dark screens (camera, QR)
  static const Color night = Color(0xFF1B1A17);
  static const Color nightPanel = Color(0xFF2A2925);
  static const Color nightLine = Color(0xFF34332E);
  static const Color nightText = Color(0xFFF3EFE4);
  static const Color nightMuted = Color(0xFFBDB8AC);
  static const Color nightOutline = Color(0xFF77746B);
  static const Color mintBright = Color(0xFF7BE0B0);
  static const Color mintInk = Color(0xFF0D3B28);

  /// Avatar tints for members, picked by position in the group.
  static const List<Color> avatarTints = [
    Color(0xFFF3DCC8),
    Color(0xFFD9DDF3),
    Color(0xFFF0D6DE),
    Color(0xFFE2EDE3),
    Color(0xFFE8E2F0),
    Color(0xFFE4E0D6),
  ];
}

/// Font families bundled in `assets/fonts`.
class AppFonts {
  AppFonts._();

  static const String ui = 'SchibstedGrotesk';
  static const String mono = 'IBMPlexMono';

  /// Amounts and other figures.
  static TextStyle money({
    double size = 15,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

/// App theme definitions using Material 3.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = AppColors.emerald;

  /// Money the user is owed.
  static const Color positiveColor = AppColors.emerald;

  /// Money the user owes.
  static const Color negativeColor = AppColors.red;

  /// Colour for a balance: green when owed, red when owing, ink when settled.
  static Color balanceColor(double balance) {
    if (balance > 0.005) return positiveColor;
    if (balance < -0.005) return negativeColor;
    return AppColors.muted;
  }

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.emerald,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.emerald,
          onPrimary: Colors.white,
          surface: AppColors.paper,
          onSurface: AppColors.ink,
          error: AppColors.red,
          outline: AppColors.outline,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      dividerColor: AppColors.line,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.emerald,
        selectionColor: AppColors.mint,
        selectionHandleColor: AppColors.emerald,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.slip,
          fontSize: 14,
        ),
        actionTextColor: AppColors.mintBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slip,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}
