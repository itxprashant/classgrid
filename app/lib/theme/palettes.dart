import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// One selectable theme in Settings.
class ThemeOption {
  const ThemeOption({
    required this.id,
    required this.label,
    required this.palette,
  });

  final String id;
  final String label;
  final AppPalette palette;

  bool get isDark => palette.brightness == Brightness.dark;
}

/// Builds coherent light/dark palettes from neutral and accent seeds.
AppPalette buildLightPalette({
  required double neutralHue,
  required double accentHue,
  double neutralChroma = 0.008,
  double accentChroma = 0.085,
  double inkHue = 60,
}) {
  return AppPalette(
    brightness: Brightness.light,
    paper: oklch(0.985, neutralChroma, neutralHue),
    paper2: oklch(0.975, neutralChroma + 0.002, neutralHue),
    surface: oklch(0.995, neutralChroma * 0.625, neutralHue),
    surfaceSunk: oklch(0.97, neutralChroma + 0.004, neutralHue),
    ink: oklch(0.27, 0.02, inkHue),
    ink2: oklch(0.48, 0.018, inkHue),
    ink3: oklch(0.62, 0.015, inkHue),
    ink4: oklch(0.74, 0.012, inkHue + 15),
    line: oklch(0.90, 0.012, neutralHue - 3),
    lineStrong: oklch(0.84, 0.014, neutralHue - 3),
    accent: oklch(0.52, accentChroma, accentHue),
    accentInk: oklch(0.36, accentChroma * 0.88, accentHue),
    accentTint: oklch(0.94, accentChroma * 0.41, accentHue),
    accentEdge: oklch(0.80, accentChroma * 0.71, accentHue),
    accentHover: oklch(0.46, accentChroma * 1.06, accentHue),
    accentFg: oklch(0.99, 0.01, accentHue),
    lectureTint: oklch(0.94, accentChroma * 0.41, accentHue),
    lectureEdge: oklch(0.78, accentChroma * 0.71, accentHue),
    lectureInk: oklch(0.34, accentChroma * 0.82, accentHue + 5),
    tutorialTint: oklch(0.94, 0.05, 80),
    tutorialEdge: oklch(0.80, 0.07, 80),
    tutorialInk: oklch(0.38, 0.07, 75),
    labTint: oklch(0.93, 0.045, 40),
    labEdge: oklch(0.80, 0.07, 40),
    labInk: oklch(0.40, 0.08, 35),
    danger: oklch(0.55, 0.13, 30),
    dangerTint: oklch(0.94, 0.04, 30),
    dangerEdge: oklch(0.80, 0.10, 30),
    success: oklch(0.48, 0.11, 145),
    successInk: oklch(0.34, 0.09, 145),
    successTint: oklch(0.94, 0.04, 145),
    successEdge: oklch(0.78, 0.08, 145),
    shadowCard: oklch(0.5, 0.02, inkHue, 0.06),
    shadowPop: oklch(0.4, 0.02, inkHue, 0.08),
  );
}

AppPalette buildDarkPalette({
  required double neutralHue,
  required double accentHue,
  double paperL = 0.18,
  double accentChroma = 0.085,
  double neutralChroma = 0.015,
}) {
  return AppPalette(
    brightness: Brightness.dark,
    paper: oklch(paperL, neutralChroma, neutralHue),
    paper2: oklch(paperL - 0.02, neutralChroma + 0.003, neutralHue),
    surface: oklch(paperL + 0.04, neutralChroma * 0.8, neutralHue),
    surfaceSunk: oklch(paperL - 0.04, neutralChroma + 0.005, neutralHue),
    ink: oklch(0.92, 0.012, neutralHue + 10),
    ink2: oklch(0.78, 0.014, neutralHue + 8),
    ink3: oklch(0.62, 0.012, neutralHue + 5),
    ink4: oklch(0.50, 0.010, neutralHue),
    line: oklch(paperL + 0.12, neutralChroma, neutralHue),
    lineStrong: oklch(paperL + 0.18, neutralChroma + 0.005, neutralHue),
    accent: oklch(0.62, accentChroma, accentHue),
    accentInk: oklch(0.78, accentChroma * 0.75, accentHue),
    accentTint: oklch(paperL + 0.08, accentChroma * 0.35, accentHue),
    accentEdge: oklch(paperL + 0.16, accentChroma * 0.5, accentHue),
    accentHover: oklch(0.68, accentChroma * 1.05, accentHue),
    accentFg: oklch(0.16, 0.02, accentHue),
    lectureTint: oklch(paperL + 0.06, accentChroma * 0.35, accentHue),
    lectureEdge: oklch(paperL + 0.14, accentChroma * 0.55, accentHue),
    lectureInk: oklch(0.82, accentChroma * 0.7, accentHue + 5),
    tutorialTint: oklch(paperL + 0.06, 0.04, 80),
    tutorialEdge: oklch(paperL + 0.14, 0.06, 80),
    tutorialInk: oklch(0.84, 0.06, 75),
    labTint: oklch(paperL + 0.05, 0.038, 40),
    labEdge: oklch(paperL + 0.13, 0.055, 40),
    labInk: oklch(0.82, 0.065, 35),
    danger: oklch(0.65, 0.14, 30),
    dangerTint: oklch(paperL + 0.06, 0.05, 30),
    dangerEdge: oklch(paperL + 0.14, 0.08, 30),
    success: oklch(0.62, 0.11, 145),
    successInk: oklch(0.78, 0.09, 145),
    successTint: oklch(paperL + 0.06, 0.04, 145),
    successEdge: oklch(paperL + 0.14, 0.07, 145),
    shadowCard: oklch(0.05, 0.01, neutralHue, 0.35),
    shadowPop: oklch(0.02, 0.01, neutralHue, 0.5),
  );
}

/// All built-in themes. [defaultId] is the exact current ClassGrid palette.
class AppPalettes {
  AppPalettes._();

  static const defaultId = 'paper';

  static AppPalette get paperDefault => T.defaultPalette;

  static final List<ThemeOption> all = [
    ThemeOption(id: 'paper', label: 'Paper', palette: paperDefault),
    ThemeOption(
      id: 'rose',
      label: 'Rose',
      palette: buildLightPalette(neutralHue: 20, accentHue: 350, accentChroma: 0.09),
    ),
    ThemeOption(
      id: 'sage',
      label: 'Sage',
      palette: buildLightPalette(neutralHue: 130, accentHue: 145, accentChroma: 0.08, inkHue: 130),
    ),
    ThemeOption(
      id: 'sand',
      label: 'Sand',
      palette: buildLightPalette(neutralHue: 75, accentHue: 45, accentChroma: 0.09, inkHue: 55),
    ),
    ThemeOption(
      id: 'mist',
      label: 'Mist',
      palette: buildLightPalette(neutralHue: 250, accentHue: 265, accentChroma: 0.08, inkHue: 250),
    ),
    ThemeOption(
      id: 'lavender',
      label: 'Lavender',
      palette: buildLightPalette(neutralHue: 290, accentHue: 305, accentChroma: 0.085, inkHue: 285),
    ),
    ThemeOption(
      id: 'espresso',
      label: 'Espresso',
      palette: buildDarkPalette(neutralHue: 55, accentHue: 195, paperL: 0.17),
    ),
    ThemeOption(
      id: 'midnight',
      label: 'Midnight',
      palette: buildDarkPalette(neutralHue: 260, accentHue: 265, paperL: 0.16, neutralChroma: 0.018),
    ),
    ThemeOption(
      id: 'charcoal',
      label: 'Charcoal',
      palette: buildDarkPalette(neutralHue: 240, accentHue: 75, paperL: 0.19, accentChroma: 0.1),
    ),
    ThemeOption(
      id: 'mulberry',
      label: 'Mulberry',
      palette: buildDarkPalette(neutralHue: 320, accentHue: 340, paperL: 0.17, accentChroma: 0.09),
    ),
  ];

  static ThemeOption byId(String id) {
    return all.firstWhere(
      (o) => o.id == id,
      orElse: () => all.first,
    );
  }

  static List<ThemeOption> get lightThemes =>
      all.where((o) => !o.isDark).toList();

  static List<ThemeOption> get darkThemes =>
      all.where((o) => o.isDark).toList();
}
