import 'package:flutter/material.dart';
import 'package:qout/core/api/qout_api.dart';

/// The grade as a coloured letter, green (A) to red (E); "?" without a grade.
/// Qout's own badge, not the official Nutri-Score logo.
class GradeBadge extends StatelessWidget {
  const GradeBadge({required this.grade, this.size = 72, super.key});

  /// Null: no grade (insufficient data, not scored).
  final Grade? grade;
  final double size;

  /// Background and letter colour per grade.
  static const Map<Grade, (Color, Color)> _colors = {
    Grade.a: (Color(0xFF1B7F43), Colors.white),
    Grade.b: (Color(0xFF7CB342), Colors.black),
    Grade.c: (Color(0xFFF9C80E), Colors.black),
    Grade.d: (Color(0xFFEF7D00), Colors.black),
    Grade.e: (Color(0xFFD7301F), Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = grade != null && grade != Grade.unrecognized;
    final (background, foreground) =
        _colors[grade] ?? (scheme.surfaceContainerHighest, scheme.onSurface);
    return Semantics(
      label: known ? 'Grade ${grade!.value}' : 'No grade',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size / 5),
        ),
        child: Text(
          known ? grade!.value : '?',
          style: TextStyle(
            color: foreground,
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
