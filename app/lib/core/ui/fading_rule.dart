import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';

/// A 1 px rule that fades to transparent over 48 px at each end, the way
/// Nocturne draws the lines between rows.
class FadingRule extends StatelessWidget {
  const FadingRule({this.indent = 0, super.key});

  /// Space before and after the rule.
  final double indent;

  /// Length of each fade.
  static const double fade = 48;

  @override
  Widget build(BuildContext context) {
    final color = QoutPalette.of(context).divider;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stop = width.isFinite && width > 2 * fade ? fade / width : 0.5;
          return SizedBox(
            height: 1,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0),
                    color,
                    color,
                    color.withValues(alpha: 0),
                  ],
                  stops: [0, stop, 1 - stop, 1],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
