import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Colour tokens from the Creya design.
abstract final class AppColors {
  static const bg = Color(0xFF0A0A0A);
  static const card = Color(0xFF111111);
  static const card2 = Color(0xFF1C1C1C);
  static const line = Color(0x1AFFFFFF);
  static const text = Color(0xFFF5F4F0);
  static const muted = Color(0xFF9A9A9A);
  static const placeholder = Color(0xFF6E6B7A);
  static const accent = Color(0xFFFFFFFF);
  static const accentPress = Color(0xFFE2E2E2);
  static const accentSoft = Color(0x1AFFFFFF);
  static const onAccent = Color(0xFF000000);
  static const pending = Color(0xFFF5B544);
  static const accepted = Color(0xFF3FCF8E);
  static const declined = Color(0xFFF26D6D);
  static const navBg = Color(0xF50E0E12);
}

abstract final class AppFonts {
  static const body = 'DMSans';
  static const heading = 'Cormorant';
  static const mono = 'DMMono';
}

/// The 12px uppercase mono label used for eyebrows and group titles.
const eyebrowStyle = TextStyle(
  fontFamily: AppFonts.mono,
  fontSize: 12,
  letterSpacing: 0.96,
  color: AppColors.muted,
);

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.declined,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x55FFFFFF),
      selectionHandleColor: AppColors.accent,
    ),
  );
}

/// A CSS-style two-stop linear gradient. The end points are resolved at paint
/// time so it renders like the design's `linear-gradient(<deg>, ...)` at any
/// aspect ratio.
class CssGradient {
  const CssGradient(this.degrees, this.from, this.to);

  final double degrees;
  final Color from;
  final Color to;

  /// The design's placeholder artwork, `grad(hue, angleOffset)`: a neutral
  /// oklch ramp whose start lightness varies with the hue.
  factory CssGradient.fromHue(int hue, [double angleOffset = 0]) {
    return CssGradient(
      160 + angleOffset,
      _oklchGray(0.38 + (hue % 60) / 600),
      _oklchGray(0.16),
    );
  }

  ui.Gradient shaderFor(Size size) {
    final radians = degrees * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final length =
        (size.width * math.sin(radians)).abs() +
        (size.height * math.cos(radians)).abs();
    final center = size.center(Offset.zero);
    final half = direction * (length / 2);
    return ui.Gradient.linear(center - half, center + half, [from, to]);
  }

  /// Converts a neutral oklch lightness to its sRGB grey.
  static Color _oklchGray(double lightness) {
    final linear = math.pow(lightness, 3).toDouble();
    final encoded = linear <= 0.0031308
        ? 12.92 * linear
        : 1.055 * math.pow(linear, 1 / 2.4) - 0.055;
    final channel = (encoded * 255).round().clamp(0, 255);
    return Color.fromARGB(255, channel, channel, channel);
  }

  @override
  bool operator ==(Object other) =>
      other is CssGradient &&
      other.degrees == degrees &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(degrees, from, to);
}

/// Fills its area with a [CssGradient], behind [child].
class GradientBox extends StatelessWidget {
  const GradientBox({
    super.key,
    required this.gradient,
    this.borderRadius = BorderRadius.zero,
    this.child,
  });

  final CssGradient gradient;
  final BorderRadius borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: CustomPaint(
        painter: _GradientPainter(gradient),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  const _GradientPainter(this.gradient);

  final CssGradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = gradient.shaderFor(size));
  }

  @override
  bool shouldRepaint(_GradientPainter old) => old.gradient != gradient;
}
