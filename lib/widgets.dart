import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'models.dart';
import 'theme.dart';

/// Bottom padding for footers: the design's value on a phone with a home
/// indicator, with a sensible minimum on phones without one.
double footerInset(BuildContext context, {double extra = 2, double min = 16}) {
  return math.max(MediaQuery.paddingOf(context).bottom + extra, min);
}

/// A tappable area exposing its pressed state, for the design's active styles.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.label,
    this.pressedScale = 1,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final String? label;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}

/// The pill button used throughout the app.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 56,
    this.fontSize = 16,
    this.background = AppColors.accent,
    this.pressedBackground = AppColors.accentPress,
    this.foreground = AppColors.onAccent,
    this.border,
    this.padding = EdgeInsets.zero,
    this.opacity = 1,
  });

  /// White-outlined, transparent variant.
  const PillButton.outline({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 48,
    this.fontSize = 14,
    this.foreground = AppColors.text,
    this.border = const BorderSide(color: AppColors.line),
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.opacity = 1,
  }) : background = Colors.transparent,
       pressedBackground = const Color(0x0DFFFFFF);

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Color background;
  final Color pressedBackground;
  final Color foreground;
  final BorderSide? border;
  final EdgeInsets padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: label,
      builder: (context, pressed) => Opacity(
        opacity: opacity,
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: pressed ? pressedBackground : background,
            borderRadius: BorderRadius.circular(999),
            border: border == null ? null : Border.fromBorderSide(border!),
          ),
          // Hugs the label unless the parent forces a width.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon button (back, close, etc).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = 44,
    this.iconSize = 20,
    this.strokeWidth = 2.25,
    this.background = AppColors.card,
    this.foreground = AppColors.text,
    this.border,
    this.pressedScale = 1,
    this.shadow,
  });

  final String icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final double iconSize;
  final double strokeWidth;
  final Color background;
  final Color foreground;
  final BorderSide? border;
  final double pressedScale;
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: label,
      pressedScale: pressedScale,
      builder: (context, _) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: border == null ? null : Border.fromBorderSide(border!),
          boxShadow: shadow == null ? null : [shadow!],
        ),
        child: AppIcon(
          icon,
          color: foreground,
          size: iconSize,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

/// The Cormorant heading with its muted italic tail: "Your *craft.*"
class Heading extends StatelessWidget {
  const Heading(
    this.text, {
    super.key,
    this.em,
    required this.size,
    this.emColor = AppColors.muted,
    this.height = 1,
    this.letterSpacing = -0.5,
    this.textAlign,
  });

  final String text;
  final String? em;
  final double size;
  final Color emColor;
  final double height;
  final double letterSpacing;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (em != null)
            TextSpan(
              text: em,
              style: TextStyle(fontStyle: FontStyle.italic, color: emColor),
            ),
        ],
      ),
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: AppFonts.heading,
        fontWeight: FontWeight.w700,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        color: AppColors.text,
      ),
    );
  }
}

/// The "Creya" wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Heading('Cre', em: 'ya', size: size);
}

/// A circular gradient avatar showing initials.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.person,
    required this.size,
    required this.fontSize,
  });

  final Person person;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GradientBox(
        gradient: person.bg,
        borderRadius: BorderRadius.circular(size),
        child: Center(
          child: Text(
            person.initials,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A small rounded label.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.height = 26,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    this.background = AppColors.accentSoft,
    this.foreground = AppColors.accent,
    this.dot = false,
  });

  final String label;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final Color background;
  final Color foreground;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-way segmented control.
class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        label: label,
        builder: (context, _) => Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.card2 : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _segment(left, leftSelected, onLeft),
          _segment(right, !leftSelected, onRight),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  String? hint,
  required EdgeInsets padding,
  required double radius,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.placeholder),
    filled: true,
    fillColor: AppColors.card,
    isDense: true,
    contentPadding: padding,
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.accent),
    counterText: '',
  );
}

/// A single-line input. Its controller is seeded once from [initialValue].
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.initialValue = '',
    this.hint,
    this.onChanged,
    this.maxLength,
    this.keyboardType,
  });

  final String initialValue;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: const TextStyle(fontSize: 16, height: 1.375),
      decoration: _fieldDecoration(
        hint: widget.hint,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}

/// A multi-line input.
class AppTextArea extends StatefulWidget {
  const AppTextArea({
    super.key,
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    required this.maxLength,
    required this.rows,
  });

  final String initialValue;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLength;
  final int rows;

  @override
  State<AppTextArea> createState() => _AppTextAreaState();
}

class _AppTextAreaState extends State<AppTextArea> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: widget.rows,
      maxLines: widget.rows,
      inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
      style: const TextStyle(fontSize: 15, height: 1.45),
      decoration: _fieldDecoration(
        hint: widget.hint,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// A dropdown styled like the text fields.
class AppSelect extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 360,
          dropdownColor: AppColors.card2,
          borderRadius: BorderRadius.circular(16),
          iconEnabledColor: AppColors.muted,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 16,
            color: AppColors.text,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

/// A small field caption, with an optional counter on the right.
class FieldLabel extends StatelessWidget {
  const FieldLabel({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final Widget label;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: label),
              if (trailing != null) Text(trailing!),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Paints the design's dashed outline around [child].
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.background,
  });

  final Color color;
  final double radius;
  final Color? background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color, radius, background),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.color, this.radius, this.background);

  final Color color;
  final double radius;
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      Radius.circular(radius),
    );
    if (background != null) {
      canvas.drawRRect(rrect, Paint()..color = background!);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.background != background;
}

/// Centered heading, body text and optional button, for empty and error states.
class MessageBlock extends StatelessWidget {
  const MessageBlock({
    super.key,
    required this.title,
    required this.em,
    required this.body,
    this.action,
    this.vertical = 56,
    this.icon,
  });

  final String title;
  final String em;
  final String body;
  final Widget? action;
  final double vertical;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(height: 16)],
          Heading(title, em: em, size: 30, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// The shared "Couldn't load." state.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageBlock(
      title: "Couldn't ",
      em: 'load.',
      body: 'Check your connection and try again.',
      action: PillButton.outline(label: 'Retry', onTap: onRetry, fontSize: 16),
    );
  }
}

/// A placeholder card shown while a list loads.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, required this.height, this.opacity = 1});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
