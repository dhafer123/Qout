import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/section_card.dart';
import 'package:qout/features/settings/presentation/theme_mode_provider.dart';

/// System, light or dark (T43b), on the Profile tab.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = QoutPalette.of(context);
    return SectionCard(
      title: 'Appearance',
      icon: PhosphorIconsRegular.palette,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'System follows the dark mode of your phone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(PhosphorIconsRegular.deviceMobile, size: 18),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(PhosphorIconsRegular.sun, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(PhosphorIconsRegular.moon, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selected) =>
                unawaited(_choose(context, ref, selected.single)),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(themeModeProvider.notifier).choose(mode);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('The appearance could not be saved')),
      );
    }
  }
}
