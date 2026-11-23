import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show ProductDetail;
import 'package:qout/core/ui/insets.dart';
import 'package:qout/features/contribute/domain/draft_values.dart'
    show parseAmount;
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/features/product/domain/product_facts.dart';
import 'package:qout/features/product/presentation/product_labels.dart'
    show formatAmount;
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';

/// Largest amount accepted in one entry (g or mL) and largest quick add
/// (kcal): typing limits, not nutrition values.
const maxEntryAmount = 5000.0;
const maxQuickAddKcal = 10000.0;

/// "I ate this": logs [product] in the diary. Shows "Added" with a way to
/// the diary when done.
Future<void> showLogFoodSheet(
  BuildContext context,
  ProductDetail product,
) async {
  final facts = productFacts(product);
  final unit = facts.basis ?? PortionUnit.gram;
  final serving = facts.servingUnit == facts.basis
      ? facts.servingQuantity
      : null;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EntrySheet(
      title: product.name ?? 'Unnamed product',
      unit: unit,
      serving: serving,
      per100Energy: facts.per100[Nutrient.energy],
      action: 'Add to diary',
      onSave: (ref, amount, meal, day) => ref
          .read(diaryRepositoryProvider)
          .logProduct(product, amount: amount, meal: meal, day: day),
    ),
  );
  if (added ?? false) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to your diary'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.go(AppRoutes.diary),
          ),
        ),
      );
  }
}

/// Changes the amount, meal or day of [entry], or removes it.
Future<void> showEditEntrySheet(BuildContext context, DiaryEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EntrySheet(
        title: entry.name ?? (entry.isQuickAdd ? 'Quick add' : 'Product'),
        unit: entry.unit ?? PortionUnit.gram,
        serving: entry.servingQuantity,
        per100Energy: entry.isQuickAdd ? null : entry.values[Nutrient.energy],
        quickAddKj: entry.isQuickAdd ? entry.values[Nutrient.energy] : null,
        initialAmount: entry.amount,
        initialMeal: entry.meal,
        initialDay: dayOf(entry.eatenAt),
        action: 'Save',
        onSave: (ref, amount, meal, day) {
          final local = entry.eatenAt.toLocal();
          return ref
              .read(diaryRepositoryProvider)
              .change(
                entry.copyWith(
                  amount: entry.isQuickAdd ? null : amount,
                  meal: meal,
                  eatenAt: DateTime(
                    day.year,
                    day.month,
                    day.day,
                    local.hour,
                    local.minute,
                    local.second,
                  ),
                ),
              );
        },
        onRemove: (ref) => ref.read(diaryRepositoryProvider).remove(entry),
      ),
    );

/// Food without a barcode: a name and its kcal; [meal] chosen at first
/// (else the one for the time of day).
Future<void> showQuickAddSheet(
  BuildContext context, {
  DateTime? day,
  Meal? meal,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _QuickAddSheet(initialDay: day, initialMeal: meal),
);

enum _PortionChoice { serving, hundred, other }

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({
    required this.title,
    required this.unit,
    required this.serving,
    required this.per100Energy,
    required this.action,
    required this.onSave,
    this.quickAddKj,
    this.initialAmount,
    this.initialMeal,
    this.initialDay,
    this.onRemove,
  });

  final String title;
  final PortionUnit unit;
  final double? serving;
  final double? per100Energy;

  /// Set when editing a quick add: no amount to choose.
  final double? quickAddKj;
  final double? initialAmount;
  final Meal? initialMeal;
  final DateTime? initialDay;
  final String action;
  final Future<void> Function(
    WidgetRef ref,
    double amount,
    Meal meal,
    DateTime day,
  )
  onSave;
  final Future<void> Function(WidgetRef ref)? onRemove;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late _PortionChoice _choice;
  late final TextEditingController _other;
  late Meal _meal = widget.initialMeal ?? guessMeal(DateTime.now());
  late DateTime _day = widget.initialDay ?? dayOf(DateTime.now());
  String? _error;
  bool _saving = false;

  bool get _quickAdd => widget.quickAddKj != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    final serving = widget.serving;
    _choice = switch (initial) {
      null when serving != null => _PortionChoice.serving,
      null => _PortionChoice.hundred,
      final a when a == serving => _PortionChoice.serving,
      100 => _PortionChoice.hundred,
      _ => _PortionChoice.other,
    };
    _other = TextEditingController(
      text: _choice == _PortionChoice.other ? formatAmount(initial!) : '',
    );
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  /// The amount chosen, or null when "Other" isn't a usable number.
  double? get _amount => switch (_choice) {
    _PortionChoice.serving => widget.serving,
    _PortionChoice.hundred => 100,
    _PortionChoice.other => _parsed(_other.text),
  };

  static double? _parsed(String text) {
    try {
      final value = parseAmount(text);
      return value == null || value <= 0 || value > maxEntryAmount
          ? null
          : value;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save() async {
    final amount = _quickAdd ? 0.0 : _amount;
    if (amount == null) {
      setState(
        () => _error =
            'Type an amount above 0, up to ${maxEntryAmount.round()} '
            '${unitLabel(widget.unit)}.',
      );
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(ref, amount, _meal, _day);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final unit = unitLabel(widget.unit);
    final serving = widget.serving;
    final amount = _amount;
    final per100 = widget.per100Energy;
    final preview = _quickAdd
        ? '${kcalOf(widget.quickAddKj!)} kcal'
        : per100 == null
        ? 'No energy value on the label: it is logged without counting '
              'toward your energy.'
        : amount == null
        ? null
        : '≈ ${kcalOf(per100 * amount / 100)} kcal';
    return _SheetFrame(
      children: [
        Text(widget.title, style: textTheme.titleLarge),
        if (!_quickAdd) ...[
          const _Heading('How much?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (serving != null)
                ChoiceChip(
                  label: Text('1 serving (${formatAmount(serving)} $unit)'),
                  selected: _choice == _PortionChoice.serving,
                  onSelected: (_) =>
                      setState(() => _choice = _PortionChoice.serving),
                ),
              ChoiceChip(
                label: Text('100 $unit'),
                selected: _choice == _PortionChoice.hundred,
                onSelected: (_) =>
                    setState(() => _choice = _PortionChoice.hundred),
              ),
              ChoiceChip(
                label: const Text('Other amount'),
                selected: _choice == _PortionChoice.other,
                onSelected: (_) =>
                    setState(() => _choice = _PortionChoice.other),
              ),
            ],
          ),
          if (_choice == _PortionChoice.other) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _other,
              autofocus: widget.initialAmount == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: unit,
                errorText: _error,
                errorMaxLines: 2,
              ),
            ),
          ],
        ],
        const _Heading('Meal'),
        _MealChoice(
          selected: _meal,
          onChanged: (meal) => setState(() => _meal = meal),
        ),
        const _Heading('Day'),
        _DayChoice(
          selected: _day,
          onChanged: (day) => setState(() => _day = day),
        ),
        if (preview != null) ...[
          const SizedBox(height: 16),
          Text(
            preview,
            style: per100 == null && !_quickAdd
                ? textTheme.bodySmall
                : textTheme.titleMedium?.copyWith(color: palette.accentText),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.action),
        ),
        if (widget.onRemove case final remove?) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await remove(ref);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: const Text('Remove from diary'),
          ),
        ],
      ],
    );
  }
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({this.initialDay, this.initialMeal});

  final DateTime? initialDay;
  final Meal? initialMeal;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  late Meal _meal = widget.initialMeal ?? guessMeal(DateTime.now());
  late DateTime _day = widget.initialDay ?? dayOf(DateTime.now());
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    double? kcal;
    try {
      kcal = parseAmount(_kcal.text);
    } on FormatException {
      kcal = null;
    }
    if (kcal == null || kcal <= 0 || kcal > maxQuickAddKcal) {
      setState(
        () => _error =
            'Type the kcal, above 0 and up to ${maxQuickAddKcal.round()}.',
      );
      return;
    }
    setState(() => _saving = true);
    final name = _name.text.trim();
    await ref
        .read(diaryRepositoryProvider)
        .quickAdd(
          kcal: kcal,
          meal: _meal,
          day: _day,
          name: name.isEmpty ? null : name,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _SheetFrame(
      children: [
        Text('Quick add', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'For food without a barcode. Only its energy counts toward your '
          'day.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What (optional)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kcal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Energy',
            suffixText: 'kcal',
            errorText: _error,
            errorMaxLines: 2,
          ),
        ),
        const _Heading('Meal'),
        _MealChoice(
          selected: _meal,
          onChanged: (meal) => setState(() => _meal = meal),
        ),
        const _Heading('Day'),
        _DayChoice(
          selected: _day,
          onChanged: (day) => setState(() => _day = day),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Add to diary'),
        ),
      ],
    );
  }
}

/// A sheet's content: scrollable, above the keyboard and the navigation
/// bar.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16,
      ).clearOfNavigationBar(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _MealChoice extends StatelessWidget {
  const _MealChoice({required this.selected, required this.onChanged});

  final Meal selected;
  final ValueChanged<Meal> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final meal in Meal.values)
        ChoiceChip(
          label: Text(meal.label),
          selected: meal == selected,
          onSelected: (_) => onChanged(meal),
        ),
    ],
  );
}

/// Today, yesterday, or another day of the last year.
class _DayChoice extends StatelessWidget {
  const _DayChoice({required this.selected, required this.onChanged});

  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final other = selected != today && selected != yesterday;
    final l10n = MaterialLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: selected == today,
          onSelected: (_) => onChanged(today),
        ),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: selected == yesterday,
          onSelected: (_) => onChanged(yesterday),
        ),
        ChoiceChip(
          label: Text(other ? l10n.formatMediumDate(selected) : 'Other day'),
          selected: other,
          onSelected: (_) => unawaited(() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: DateTime(today.year - 1, today.month, today.day),
              lastDate: today,
            );
            if (picked != null) onChanged(dayOf(picked));
          }()),
        ),
      ],
    );
  }
}
