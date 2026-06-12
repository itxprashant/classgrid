import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Typography helpers matching the web design system:
/// Inter for UI/body, Fraunces for page titles, IBM Plex Mono for code/data.
class AppText {
  AppText._();

  static TextStyle sans({
    double size = T.fs14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? T.ink,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: TextDecoration.none,
      );

  static TextStyle serif({
    double size = T.fs26,
    FontWeight weight = FontWeight.w600,
    Color? color,
    FontStyle? fontStyle,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color ?? T.ink,
        fontStyle: fontStyle,
        height: height,
        decoration: TextDecoration.none,
      );

  static TextStyle mono({
    double size = T.fs13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? T.ink,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: TextDecoration.none,
      );
}

TextTheme _textThemeWithoutUnderline(TextTheme base) {
  TextStyle? strip(TextStyle? s) =>
      s?.copyWith(decoration: TextDecoration.none, decorationColor: null);

  return TextTheme(
    displayLarge: strip(base.displayLarge),
    displayMedium: strip(base.displayMedium),
    displaySmall: strip(base.displaySmall),
    headlineLarge: strip(base.headlineLarge),
    headlineMedium: strip(base.headlineMedium),
    headlineSmall: strip(base.headlineSmall),
    titleLarge: strip(base.titleLarge),
    titleMedium: strip(base.titleMedium),
    titleSmall: strip(base.titleSmall),
    bodyLarge: strip(base.bodyLarge),
    bodyMedium: strip(base.bodyMedium),
    bodySmall: strip(base.bodySmall),
    labelLarge: strip(base.labelLarge),
    labelMedium: strip(base.labelMedium),
    labelSmall: strip(base.labelSmall),
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final brightness = T.active.brightness;
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: T.paper,
      canvasColor: T.paper,
      cardColor: T.surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: T.accent,
        onPrimary: T.accentFg,
        secondary: T.accentInk,
        onSecondary: T.paper,
        surface: T.surface,
        onSurface: T.ink,
        error: T.danger,
        onError: T.paper,
      ),
      textTheme: _textThemeWithoutUnderline(
        GoogleFonts.interTextTheme().apply(
          bodyColor: T.ink,
          displayColor: T.ink,
        ),
      ),
      dividerColor: T.line,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: T.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: T.ink,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: AppText.serif(size: T.fs21, weight: FontWeight.w600, color: T.ink),
        shape: Border(bottom: BorderSide(color: T.line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: T.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.r),
          borderSide: BorderSide(color: T.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.r),
          borderSide: BorderSide(color: T.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.r),
          borderSide: BorderSide(color: T.accent, width: 1.5),
        ),
        hintStyle: AppText.sans(color: T.ink3),
        labelStyle: AppText.sans(color: T.ink2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: T.accent,
          foregroundColor: T.accentFg,
          textStyle: AppText.sans(weight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.r)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: T.ink,
          side: BorderSide(color: T.lineStrong),
          textStyle: AppText.sans(weight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.r)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: T.accentInk,
          textStyle: AppText.sans(weight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        color: T.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rLg),
          side: BorderSide(color: T.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: T.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
        titleTextStyle: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink),
        contentTextStyle: AppText.sans(color: T.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: T.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: T.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: T.accentTint,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.sans(
            size: T.fs12,
            weight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? T.accentInk : T.ink3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? T.accentInk : T.ink3,
            size: 22,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: T.accentTint,
        selectedColor: T.accent,
        disabledColor: T.paper2,
        side: BorderSide(color: T.accentEdge),
        checkmarkColor: T.accentFg,
        labelStyle: AppText.mono(size: T.fs12, color: T.accentInk),
        secondaryLabelStyle: AppText.mono(size: T.fs12, color: T.accentFg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rSm)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: T.ink,
        contentTextStyle: AppText.sans(color: T.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.r)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: T.surface,
        dialBackgroundColor: T.paper2,
        hourMinuteColor: T.accentTint,
        dayPeriodColor: T.accentTint,
        entryModeIconColor: T.ink3,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: T.surface,
        headerBackgroundColor: T.paper2,
        headerForegroundColor: T.ink,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: T.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: AppText.sans(color: T.ink),
      ),
      listTileTheme: ListTileThemeData(
        textColor: T.ink,
        iconColor: T.ink3,
      ),
    );
  }
}
