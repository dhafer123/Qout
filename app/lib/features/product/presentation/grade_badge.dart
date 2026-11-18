import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart';

/// Fill colour per grade, green (A) to red (E): one ramp at equal lightness
/// (the Nocturne design), the same in both themes. Every fill takes the same
/// dark ink, and the letter is always printed, so colour is never the only
/// signal.
const Map<Grade, Color> gradeColors = {
  Grade.a: Color(0xFF72D48A),
  Grade.b: Color(0xFFAFCC5F),
  Grade.c: Color(0xFFE8C44E),
  Grade.d: Color(0xFFF6A14F),
  Grade.e: Color(0xFFF47D67),
};

/// The letter colour on every grade fill.
const Color gradeInk = Color(0xFF10131C);

/// The grades in order, best first.
const List<Grade> gradeScale = [Grade.a, Grade.b, Grade.c, Grade.d, Grade.e];

/// Whether [grade] is one of A to E.
bool isKnownGrade(Grade? grade) =>
    grade != null && gradeColors.containsKey(grade);

/// The grade as a coloured letter; a dashed "?" without a grade.
/// Qout's own badge, not the official Nutri-Score logo.
class GradeBadge extends StatelessWidget {
  const GradeBadge({required this.grade, this.size = 68, super.key});

  /// Null: no grade (insufficient data, not scored).
  final Grade? grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final known = isKnownGrade(grade);
    final radius = BorderRadius.circular(size * 0.19);
    final Widget badge;
    if (known) {
      badge = DecoratedBox(
        decoration: BoxDecoration(
          color: gradeColors[grade],
          borderRadius: radius,
        ),
        child: Center(
          child: Text(
            grade!.value,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: gradeInk,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      );
    } else {
      final muted = QoutPalette.of(context).muted;
      badge = CustomPaint(
        painter: _DashedBorderPainter(color: muted, radius: size * 0.19),
        child: Center(
          child: Text(
            '?',
            textScaler: TextScaler.noScaling,
            style: TextStyle(color: muted, fontSize: size * 0.41, height: 1),
          ),
        ),
      );
    }
    return Semantics(
      label: known ? 'Grade ${grade!.value}' : 'No grade',
      excludeSemantics: true,
      child: SizedBox.square(dimension: size, child: badge),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;
  static const double _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    final rect = (Offset.zero & size).deflate(_width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// The A to E track under the grade: five bars, the product's grade raised
/// and labelled in full colour. Decorative: the grade card says the grade.
class GradeTrack extends StatelessWidget {
  const GradeTrack({required this.grade, super.key});

  final Grade? grade;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, g) in gradeScale.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: ValueKey('grade-track-${g.value}'),
                    height: g == grade ? 12 : 5,
                    decoration: BoxDecoration(
                      color: gradeColors[g]!.withValues(
                        alpha: g == grade ? 1 : 0.4,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    g.value,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: g == grade ? onSurface : palette.muted,
                      fontWeight: g == grade
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
