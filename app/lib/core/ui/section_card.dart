import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';

/// A titled group on a screen: a card with an icon and a title, then the
/// content. Rows inside keep their own 16 px side padding, which lines them
/// up with the title.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    this.padding = const EdgeInsets.only(bottom: 8),
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;

  /// The icon's colour; the accent when null.
  final Color? iconColor;

  /// At the end of the title row (e.g. a count).
  final Widget? trailing;

  final EdgeInsetsGeometry margin;

  /// Around [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: margin,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              _Header(
                title: title,
                icon: icon,
                iconColor: iconColor,
                trailing: trailing,
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final icon = this.icon;
    final color = iconColor ?? palette.accentText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: IconTile(icon: icon, color: color),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// An icon on a faint wash of its own colour, in a rounded square.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    required this.color,
    this.size = 32,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(QoutRadius.md),
      ),
      child: Icon(icon, size: size * 0.56, color: color),
    ),
  );
}
