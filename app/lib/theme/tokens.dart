import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Converts an OKLCH color (matching the CSS `oklch(L C H)` tokens used by the
/// web app's `src/index.css`) into a Flutter sRGB [Color].
///
/// [l] is lightness 0..1, [c] is chroma, [h] is hue in degrees, [opacity] 0..1.
/// The conversion mirrors the standard OKLab -> linear sRGB -> gamma pipeline so
/// the mobile palette is pixel-faithful to the web design system.
Color oklch(double l, double c, double h, [double opacity = 1.0]) {
  final hRad = h * math.pi / 180.0;
  final a = c * math.cos(hRad);
  final b = c * math.sin(hRad);

  final lp = l + 0.3963377774 * a + 0.2158037573 * b;
  final mp = l - 0.1055613458 * a - 0.0638541728 * b;
  final sp = l - 0.0894841775 * a - 1.2914855480 * b;

  final l3 = lp * lp * lp;
  final m3 = mp * mp * mp;
  final s3 = sp * sp * sp;

  final rLin = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  final gLin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  final bLin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  int channel(double v) {
    final srgb = v <= 0.0031308
        ? 12.92 * v
        : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
    return (srgb.clamp(0.0, 1.0) * 255.0).round();
  }

  return Color.fromARGB(
    (opacity.clamp(0.0, 1.0) * 255).round(),
    channel(rLin),
    channel(gLin),
    channel(bLin),
  );
}

/// Full color palette for one app theme. Session tints and state colors follow
/// the same relationships as the default paper planner in DESIGN.md.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.paper,
    required this.paper2,
    required this.surface,
    required this.surfaceSunk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentInk,
    required this.accentTint,
    required this.accentEdge,
    required this.accentHover,
    required this.accentFg,
    required this.lectureTint,
    required this.lectureEdge,
    required this.lectureInk,
    required this.tutorialTint,
    required this.tutorialEdge,
    required this.tutorialInk,
    required this.labTint,
    required this.labEdge,
    required this.labInk,
    required this.danger,
    required this.dangerTint,
    required this.dangerEdge,
    required this.success,
    required this.successInk,
    required this.successTint,
    required this.successEdge,
    required this.shadowCard,
    required this.shadowPop,
  });

  final Brightness brightness;
  final Color paper;
  final Color paper2;
  final Color surface;
  final Color surfaceSunk;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentInk;
  final Color accentTint;
  final Color accentEdge;
  final Color accentHover;
  final Color accentFg;
  final Color lectureTint;
  final Color lectureEdge;
  final Color lectureInk;
  final Color tutorialTint;
  final Color tutorialEdge;
  final Color tutorialInk;
  final Color labTint;
  final Color labEdge;
  final Color labInk;
  final Color danger;
  final Color dangerTint;
  final Color dangerEdge;
  final Color success;
  final Color successInk;
  final Color successTint;
  final Color successEdge;
  final Color shadowCard;
  final Color shadowPop;
}

/// Design tokens ported from `src/index.css` (`:root`) and `DESIGN.md`.
/// Color getters delegate to [active]; radii and type scale are fixed.
class T {
  T._();

  static AppPalette active = defaultPalette;

  static void apply(AppPalette palette) {
    active = palette;
  }

  /// Exact current ClassGrid default — kept verbatim for zero regression.
  static final AppPalette defaultPalette = AppPalette(
    brightness: Brightness.light,
    paper: oklch(0.985, 0.008, 83),
    paper2: oklch(0.975, 0.01, 83),
    surface: oklch(0.995, 0.005, 83),
    surfaceSunk: oklch(0.97, 0.012, 83),
    ink: oklch(0.27, 0.02, 60),
    ink2: oklch(0.48, 0.018, 60),
    ink3: oklch(0.62, 0.015, 60),
    ink4: oklch(0.74, 0.012, 75),
    line: oklch(0.90, 0.012, 80),
    lineStrong: oklch(0.84, 0.014, 80),
    accent: oklch(0.52, 0.085, 195),
    accentInk: oklch(0.36, 0.075, 195),
    accentTint: oklch(0.94, 0.035, 195),
    accentEdge: oklch(0.80, 0.06, 195),
    accentHover: oklch(0.46, 0.09, 195),
    accentFg: oklch(0.99, 0.01, 195),
    lectureTint: oklch(0.94, 0.035, 195),
    lectureEdge: oklch(0.78, 0.06, 195),
    lectureInk: oklch(0.34, 0.07, 200),
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
    shadowCard: oklch(0.5, 0.02, 60, 0.06),
    shadowPop: oklch(0.4, 0.02, 60, 0.08),
  );

  // Paper / surfaces
  static Color get paper => active.paper;
  static Color get paper2 => active.paper2;
  static Color get surface => active.surface;
  static Color get surfaceSunk => active.surfaceSunk;

  // Ink
  static Color get ink => active.ink;
  static Color get ink2 => active.ink2;
  static Color get ink3 => active.ink3;
  static Color get ink4 => active.ink4;

  // Lines
  static Color get line => active.line;
  static Color get lineStrong => active.lineStrong;

  // Accent
  static Color get accent => active.accent;
  static Color get accentInk => active.accentInk;
  static Color get accentTint => active.accentTint;
  static Color get accentEdge => active.accentEdge;
  static Color get accentHover => active.accentHover;
  static Color get accentFg => active.accentFg;

  // Session tints
  static Color get lectureTint => active.lectureTint;
  static Color get lectureEdge => active.lectureEdge;
  static Color get lectureInk => active.lectureInk;
  static Color get tutorialTint => active.tutorialTint;
  static Color get tutorialEdge => active.tutorialEdge;
  static Color get tutorialInk => active.tutorialInk;
  static Color get labTint => active.labTint;
  static Color get labEdge => active.labEdge;
  static Color get labInk => active.labInk;

  // States
  static Color get danger => active.danger;
  static Color get dangerTint => active.dangerTint;
  static Color get dangerEdge => active.dangerEdge;
  static Color get success => active.success;
  static Color get successInk => active.successInk;
  static Color get successTint => active.successTint;
  static Color get successEdge => active.successEdge;

  // Shadows
  static Color get shadowCard => active.shadowCard;
  static Color get shadowPop => active.shadowPop;

  // Radii
  static const double rSm = 4;
  static const double r = 6;
  static const double rLg = 10;

  // Spacing scale
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  // Motion — cubic-bezier(0.22, 1, 0.36, 1) from DESIGN.md
  static const Duration tFast = Duration(milliseconds: 120);
  static const Duration tBase = Duration(milliseconds: 180);
  static const Duration tSlow = Duration(milliseconds: 280);
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);

  // Type scale (px @ 16px root)
  static const double fs10 = 10;
  static const double fs11 = 11;
  static const double fs12 = 12;
  static const double fs13 = 13;
  static const double fs14 = 14;
  static const double fs16 = 16;
  static const double fs18 = 18;
  static const double fs21 = 21;
  static const double fs26 = 26;
  static const double fs32 = 32;
  static const double fs44 = 44;
}
