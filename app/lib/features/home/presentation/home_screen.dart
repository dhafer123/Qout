import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_labels.dart';
import 'package:qout/features/product/presentation/product_photo.dart';

/// Scan button, then the products scanned so far (works offline).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(scanHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/brand/qout_icon.png',
                width: 28,
                height: 28,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Qout'),
          ],
        ),
        actions: const [ProfileButton(), SizedBox(width: 8)],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _ScanCard()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: OutboxCard(),
            ),
          ),
          ...history.when(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HistoryMessage(
                  icon: PhosphorIconsRegular.warningCircle,
                  title: 'The history could not be read.',
                ),
              ),
            ],
            data: (entries) => entries.isEmpty
                ? const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _HistoryMessage(
                        icon: PhosphorIconsRegular.clockCounterClockwise,
                        title: 'No scans yet',
                        message: 'Scanned products appear here, also offline.',
                      ),
                    ),
                  ]
                : [
                    SliverToBoxAdapter(
                      child: SectionLabel(
                        'History',
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 2),
                        action: TextButton(
                          onPressed: () =>
                              unawaited(_confirmClear(context, ref)),
                          child: const Text(
                            'Clear',
                            semanticsLabel: 'Clear history',
                          ),
                        ),
                      ),
                    ),
                    _HistoryList(entries),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 16 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This removes every scan from this list. Products already seen stay '
          'available offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear ?? false) await ref.read(scanHistoryRepositoryProvider).clear();
  }
}

/// Opens the profile: the account's initial when signed in, else a person.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final palette = QoutPalette.of(context);
    final initial = switch (auth) {
      SignedIn(:final email) when email.isNotEmpty =>
        email.characters.first.toUpperCase(),
      _ => null,
    };
    return IconButton(
      tooltip: 'Your profile',
      onPressed: () => context.push(AppRoutes.profile),
      icon: SizedBox.square(
        dimension: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: initial == null ? null : palette.tag,
            border: Border.all(
              color: initial == null ? palette.edge : palette.accent,
            ),
          ),
          child: Center(
            child: initial == null
                ? Icon(
                    PhosphorIconsRegular.user,
                    size: 19,
                    color: palette.muted,
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: palette.onTag,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The prompt and the scan button, on a card washed with the accent.
class _ScanCard extends StatelessWidget {
  const _ScanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final palette = QoutPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(QoutRadius.lg),
          border: Border.all(color: palette.edge),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.accent.withValues(alpha: dark ? 0.24 : 0.16),
              theme.colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(QoutRadius.lg),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -14,
                top: -14,
                child: ExcludeSemantics(
                  child: Icon(
                    PhosphorIconsLight.barcode,
                    size: 112,
                    color: palette.accent.withValues(alpha: 0.09),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 290),
                      child: Text(
                        'Scan a food barcode to see its nutrition score.',
                        style: textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No account needed. Scanned products stay on this '
                      'phone, also offline.',
                      // Not the muted grey: too faint on the wash.
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          // The deeper accent in light mode, for the
                          // contrast of its label.
                          backgroundColor: dark
                              ? palette.accent
                              : palette.accentText,
                          foregroundColor: theme.colorScheme.surface,
                          textStyle: textTheme.titleSmall?.copyWith(
                            fontSize: 17,
                          ),
                        ),
                        onPressed: () => context.push(AppRoutes.scan),
                        icon: const Icon(
                          PhosphorIconsRegular.barcode,
                          size: 24,
                        ),
                        label: const Text('Scan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty or failed history: an icon and a line or two, flush left.
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: QoutPalette.of(context).muted),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleSmall),
          if (message case final text?) ...[
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList(this.entries);

  final List<HistoryEntry> entries;

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  /// Swiped away but maybe not yet gone from the database stream: a dismissed
  /// row must leave the list at once.
  final _dismissed = <int>{};

  void _remove(HistoryEntry entry) {
    setState(() => _dismissed.add(entry.id));
    final repository = ref.read(scanHistoryRepositoryProvider);
    unawaited(repository.remove(entry));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from history'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(repository.restore(entry)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in widget.entries)
        if (!_dismissed.contains(entry.id)) entry,
    ];
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Dismissible(
              key: ValueKey(entry.id),
              direction: DismissDirection.endToStart,
              background: ColoredBox(
                color: scheme.errorContainer,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(
                      PhosphorIconsRegular.trash,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              onDismissed: (_) => _remove(entry),
              child: HistoryTile(entry: entry),
            ),
          ),
        );
      },
    );
  }
}

/// One scanned product: grade, name, brand (or barcode), when it was
/// scanned, and its photo when there is one.
class HistoryTile extends StatelessWidget {
  const HistoryTile({required this.entry, super.key});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final product = entry.product;
    final scanned = formatDateTime(context, entry.scannedAt);
    final brand = product?.brand;
    final name = product?.name;
    final photo = product?.imageUrl;
    return InkWell(
      onTap: () => context.push(AppRoutes.product(entry.ean)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
          child: Row(
            children: [
              GradeBadge(
                grade: product == null
                    ? null
                    : explainScore(product).displayGrade,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Unnamed product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: name == null
                          ? textTheme.titleSmall?.copyWith(
                              color: palette.muted,
                              fontStyle: FontStyle.italic,
                            )
                          : textTheme.titleSmall,
                    ),
                    Text(
                      brand != null
                          ? '$brand · $scanned'
                          : '${entry.ean} · $scanned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (photo != null && photo.isNotEmpty) ...[
                const SizedBox(width: 10),
                ProductThumbnail(url: photo),
              ],
              const SizedBox(width: 6),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 18,
                color: palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
