import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/insets.dart';
import 'package:qout/core/ui/veggie.dart';

/// A whole-screen state (empty, offline, error, not found): a vegetable or an
/// icon, a title,
/// an explanation and its actions, flush left and scrollable so large text
/// never overflows. Used by every screen, so these states look the same
/// everywhere.
class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.icon,
    required this.title,
    this.message,
    this.veggie,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Shown instead of [icon]: the vegetable that goes with this state
  /// (see [VeggieFor]).
  final Veggie? veggie;

  /// Full-width buttons, the primary one first.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        16,
        32,
        16,
        24,
      ).clearOfNavigationBar(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (veggie case final veggie?)
            VeggieArt(veggie, size: 72)
          else
            Icon(icon, size: 44, color: QoutPalette.of(context).muted),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (message case final text?) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: QoutPalette.of(context).muted,
              ),
            ),
          ],
          if (actions.isNotEmpty) const SizedBox(height: 24),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}
