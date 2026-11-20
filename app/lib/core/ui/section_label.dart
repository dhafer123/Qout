import 'package:flutter/material.dart';

/// A small uppercase label above a group of rows ("HISTORY"), with an
/// optional value at the end ("17 PTS") or an [action] (a small button).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    this.trailing,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 6),
    super.key,
  });

  final String text;
  final String? trailing;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: style),
            ),
          ),
          if (trailing case final value?)
            Text(value.toUpperCase(), style: style),
          ?action,
        ],
      ),
    );
  }
}
