import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/diary/presentation/day_summary.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/features/diary/presentation/diary_screen.dart';
import 'package:qout/features/diary/presentation/diary_sheets.dart';
import 'package:qout/features/diary/presentation/meal_veggie.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_photo.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/scan/domain/barcode.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';

/// "Hello, Dhafer", or a greeting for the time of day without a name.
String greeting(String? firstName, DateTime now) {
  if (firstName != null) return 'Hello, $firstName';
  return switch (now.hour) {
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };
}

/// The Today tab: the greeting, the day so far against the daily needs
/// (T42), ways to log food, a barcode to type and what was scanned lately.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(firstNameProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: EntranceScope(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Entrance(child: _Greeting(firstName: firstName)),
              ),
              const SliverToBoxAdapter(
                child: Entrance(index: 1, child: _TodaySummary()),
              ),
              const SliverToBoxAdapter(
                child: Entrance(index: 2, child: _LogActions()),
              ),
              const SliverToBoxAdapter(
                child: Entrance(index: 3, child: _TodayMeals()),
              ),
              const SliverToBoxAdapter(
                child: Entrance(index: 4, child: BarcodeField()),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: OutboxCard(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Entrance(index: 5, child: _RecentScans()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final name = firstName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.tag,
                ),
                child: Center(
                  child: name == null
                      ? Icon(PhosphorIconsRegular.user, color: palette.onTag)
                      : Text(
                          name.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: palette.onTag,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    greeting(name, DateTime.now()),
                    style: textTheme.titleLarge,
                  ),
                ),
                Text(
                  'What are you eating today?',
                  style: textTheme.bodyMedium?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Type a barcode instead of scanning it (when the camera can't read it):
/// checked like a scanned one, then the product opens.
class BarcodeField extends ConsumerStatefulWidget {
  const BarcodeField({super.key});

  @override
  ConsumerState<BarcodeField> createState() => _BarcodeFieldState();
}

class _BarcodeFieldState extends ConsumerState<BarcodeField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(String text) {
    if (text.trim().isEmpty) return;
    final ean = normalizeTypedBarcode(text);
    if (ean == null) {
      setState(
        () => _error =
            'Check the digits: 8, 12 or 13, the last one being the check '
            'digit.',
      );
      return;
    }
    setState(() => _error = null);
    _controller.clear();
    FocusScope.of(context).unfocus();
    // Like a scan: the history is a convenience, a failed write must not
    // block the result.
    unawaited(
      ref
          .read(scanHistoryRepositoryProvider)
          .record(ean)
          .catchError((Object _) {}),
    );
    unawaited(context.push(AppRoutes.product(ean)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.search,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9 -]')),
          LengthLimitingTextInputFormatter(20),
        ],
        onSubmitted: _open,
        decoration: InputDecoration(
          hintText: 'Type a barcode',
          errorText: _error,
          errorMaxLines: 2,
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            color: palette.muted,
          ),
          suffixIcon: IconButton(
            tooltip: 'Open this barcode',
            icon: const Icon(PhosphorIconsRegular.arrowRight),
            onPressed: () => _open(_controller.text),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: palette.edge),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: palette.edge),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: palette.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Today's totals against the daily needs.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(diaryDayProvider(dayOf(DateTime.now()))).valueOrNull ??
        const <DiaryEntry>[];
    final needs = ref.watch(dailyNeedsProvider).valueOrNull;
    if (needs == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DaySummaryCard(totals: totalsOf(entries), needs: needs),
    );
  }
}

/// Scan to log (the main way), or quick add.
class _LogActions extends StatelessWidget {
  const _LogActions();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.scan),
            icon: const Icon(PhosphorIconsBold.barcode, size: 20),
            label: const Text('Scan to log'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => showQuickAddSheet(context),
            icon: const Icon(PhosphorIconsRegular.plusCircle, size: 20),
            label: const Text('Quick add'),
          ),
        ),
      ],
    ),
  );
}

/// What was logged today, per meal; opens the Diary on today.
class _TodayMeals extends ConsumerWidget {
  const _TodayMeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayOf(DateTime.now());
    final entries =
        ref.watch(diaryDayProvider(today)).valueOrNull ?? const <DiaryEntry>[];
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    void openDiary() {
      ref.read(selectedDiaryDayProvider.notifier).state = today;
      context.go(AppRoutes.diary);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openDiary,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          "Today's meals",
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ),
                    Icon(
                      PhosphorIconsRegular.caretRight,
                      size: 18,
                      color: palette.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (entries.isEmpty)
                  Row(
                    children: [
                      const VeggieArt(VeggieFor.emptyDay, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nothing logged yet. Scan a product and tap "I ate '
                          'this", or quick add.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                else
                  for (final meal in Meal.values)
                    if (entries.where((e) => e.meal == meal).toList()
                        case final ofMeal when ofMeal.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            VeggieArt(mealVeggie(meal), size: 28, pop: false),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${meal.label} · ${ofMeal.length} '
                                '${ofMeal.length == 1 ? 'item' : 'items'}',
                              ),
                            ),
                            // Wraps under large text rather than overflow.
                            Flexible(
                              child: Text(
                                _kcalOf(ofMeal),
                                textAlign: TextAlign.end,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The latest scans as a row of cards, with "See all" (the Diary tab).
class _RecentScans extends ConsumerWidget {
  const _RecentScans();

  static const int _shown = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(scanHistoryProvider);
    final textTheme = Theme.of(context).textTheme;
    final entries = history.valueOrNull ?? const <HistoryEntry>[];
    final scale = MediaQuery.textScalerOf(context);
    // The photo, two lines of name, one of brand, and the padding.
    final cardHeight =
        RecentScanCard.photoHeight +
        scale.scale(15) * 1.45 * 2 +
        scale.scale(13) * 1.45 +
        30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Recently scanned', style: textTheme.titleMedium),
                ),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () => context.go(AppRoutes.diary),
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        if (history.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (history.hasError)
          const _RecentMessage(
            'The history could not be read.',
            veggie: VeggieFor.error,
          )
        else if (entries.isEmpty)
          const _RecentMessage(
            'No scans yet. Scanned products appear here, also offline.',
            veggie: VeggieFor.noScans,
          )
        else
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length.clamp(0, _shown),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  RecentScanCard(entry: entries[index]),
            ),
          ),
      ],
    );
  }
}

class _RecentMessage extends StatelessWidget {
  const _RecentMessage(this.text, {required this.veggie});

  final String text;
  final Veggie veggie;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: [
        VeggieArt(veggie, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

/// A scanned product as a small card: photo with its grade, name, brand.
class RecentScanCard extends ConsumerWidget {
  const RecentScanCard({required this.entry, super.key});

  final HistoryEntry entry;

  static const double width = 152;
  static const double photoHeight = 108;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final product = entry.product;
    final name = product?.name;
    final photo = product?.imageUrl;
    final grade = product == null ? null : explainScore(product).displayGrade;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.product(entry.ean)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: photoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photo != null && photo.isNotEmpty)
                      Image(
                        image: ref.watch(productImageProvider)(photo),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const PhotoStripes(),
                        frameBuilder: (context, child, frame, sync) =>
                            sync || frame != null
                            ? ColoredBox(
                                color: palette.photoStripeA,
                                child: child,
                              )
                            : const PhotoStripes(),
                      )
                    else
                      const PhotoStripes(),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: GradeBadge(grade: grade, size: 32),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Unnamed product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      product?.brand ?? entry.ean,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
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

/// The energy of [entries] as "123 kcal".
String _kcalOf(List<DiaryEntry> entries) =>
    '${kcalOf(totalsOf(entries).of(Nutrient.energy))} kcal';
