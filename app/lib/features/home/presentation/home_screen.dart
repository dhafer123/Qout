import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/core/ui/fading_rule.dart';
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
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(scanHistoryProvider);
    final hasHistory = history.valueOrNull?.isNotEmpty ?? false;
    final auth = ref.watch(authStateProvider).valueOrNull;
    final dev = ref.watch(appEnvProvider).flavor == AppFlavor.dev;
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
        actions: [
          PopupMenuButton<void>(
            tooltip: 'More',
            icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => context.push(AppRoutes.profile),
                child: const Text('Your profile'),
              ),
              if (auth case SignedIn(:final email))
                PopupMenuItem(
                  onTap: () => unawaited(_signOut(context, ref)),
                  child: Text('Sign out ($email)'),
                )
              else
                PopupMenuItem(
                  onTap: () => context.push(AppRoutes.signIn),
                  child: const Text('Sign in'),
                ),
              if (hasHistory)
                PopupMenuItem(
                  onTap: () => unawaited(_confirmClear(context, ref)),
                  child: const Text('Clear history'),
                ),
              if (dev)
                PopupMenuItem(
                  onTap: () => context.push(AppRoutes.labelOcr),
                  child: const Text('Label OCR (dev)'),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: textTheme.titleSmall?.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      onPressed: () => context.push(AppRoutes.scan),
                      icon: const Icon(PhosphorIconsRegular.barcode, size: 24),
                      label: const Text('Scan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const SliverToBoxAdapter(child: SectionLabel('History')),
                    _HistoryList(entries),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authRepositoryProvider).signOut();
    messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
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
        return Dismissible(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HistoryTile(entry: entry),
              const FadingRule(),
            ],
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
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
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
