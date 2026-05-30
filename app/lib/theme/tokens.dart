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

/// Design tokens ported from `src/index.css` (`:root`) and `DESIGN.md`.
class T {
  T._();

  // Paper / surfaces
  static final Color paper = oklch(0.985, 0.008, 83);
  static final Color paper2 = oklch(0.975, 0.01, 83);
  static final Color surface = oklch(0.995, 0.005, 83);
  static final Color surfaceSunk = oklch(0.97, 0.012, 83);

  // Ink
  static final Color ink = oklch(0.27, 0.02, 60);
  static final Color ink2 = oklch(0.48, 0.018, 60);
  static final Color ink3 = oklch(0.62, 0.015, 60);
  static final Color ink4 = oklch(0.74, 0.012, 75);

  // Lines
  static final Color line = oklch(0.90, 0.012, 80);
  static final Color lineStrong = oklch(0.84, 0.014, 80);

  // Accent
  static final Color accent = oklch(0.52, 0.085, 195);
  static final Color accentInk = oklch(0.36, 0.075, 195);
  static final Color accentTint = oklch(0.94, 0.035, 195);
  static final Color accentEdge = oklch(0.80, 0.06, 195);
  static final Color accentHover = oklch(0.46, 0.09, 195);
  static final Color accentFg = oklch(0.99, 0.01, 195);

  // Session tints
  static final Color lectureTint = oklch(0.94, 0.035, 195);
  static final Color lectureEdge = oklch(0.78, 0.06, 195);
  static final Color lectureInk = oklch(0.34, 0.07, 200);
  static final Color tutorialTint = oklch(0.94, 0.05, 80);
  static final Color tutorialEdge = oklch(0.80, 0.07, 80);
  static final Color tutorialInk = oklch(0.38, 0.07, 75);
  static final Color labTint = oklch(0.93, 0.045, 40);
  static final Color labEdge = oklch(0.80, 0.07, 40);
  static final Color labInk = oklch(0.40, 0.08, 35);

  // States
  static final Color danger = oklch(0.55, 0.13, 30);
  static final Color dangerTint = oklch(0.94, 0.04, 30);
  static final Color dangerEdge = oklch(0.80, 0.10, 30);
  static final Color success = oklch(0.48, 0.11, 145);
  static final Color successInk = oklch(0.34, 0.09, 145);
  static final Color successTint = oklch(0.94, 0.04, 145);
  static final Color successEdge = oklch(0.78, 0.08, 145);

  // Shadows
  static final Color shadowCard = oklch(0.5, 0.02, 60, 0.06);
  static final Color shadowPop = oklch(0.4, 0.02, 60, 0.08);

  // Radii
  static const double rSm = 4;
  static const double r = 6;
  static const double rLg = 10;

  // Type scale (px @ 16px root)
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
