import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart'
    show Grade, NutritionBasis, ParserUsed;
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/domain/draft_values.dart';
import 'package:qout/features/contribute/presentation/contribute_labels.dart';
import 'package:qout/features/contribute/presentation/contribution_controller.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/scoring/scoring.dart' as scoring;

/// Most characters the backend takes for the name and the brand.
const productTextMaxLength = 200;

/// The values read from the label, for the contributor to check and send.
/// No logic here: the values, checks and score come from `draft_values.dart`
/// and every change goes through the [ContributionController].
class ReviewForm extends ConsumerWidget {
  const ReviewForm({required this.ean, super.key});

  final String ean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contributionControllerProvider(ean);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final draft = state.draft;
    final found = problems(draft, requireMandatory: state.showRequired);
    final drink = draft.category == scoring.Category.beverage;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReadingBanner(state: state, controller: controller),
              _ProvisionalGrade(draft: draft),
              const SizedBox(height: 16),
              _CategoryField(
                category: draft.category,
                onChanged: controller.setCategory,
              ),
              const SizedBox(height: 16),
              _BasisField(basis: draft.basis, onChanged: controller.setBasis),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: draft.name,
                maxLength: productTextMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Product name (optional)',
                ),
                onChanged: controller.setName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: draft.brand,
                maxLength: productTextMaxLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Brand (optional)',
                ),
                onChanged: controller.setBrand,
              ),
              const SizedBox(height: 8),
              Text(
                'Nutrition ${_basisText(draft.basis)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final field in NutrientField.values) ...[
                _AmountField(
                  // A new revision (values filled in by a parser) rebuilds
                  // the field with the new text.
                  key: ValueKey(('amount', field, draft.revision)),
                  field: field,
                  text: draft.values[field] ?? '',
                  unit: field == NutrientField.energy
                      ? (draft.energyUnit == EnergyUnit.kj ? 'kJ' : 'kcal')
                      : field == NutrientField.fvl
                      ? '%'
                      : 'g',
                  problem: found[field],
                  flagged: draft.flagged.contains(field),
                  onChanged: (text) => controller.setValue(field, text),
                ),
                if (field == NutrientField.energy)
                  _EnergyUnitField(
                    unit: draft.energyUnit,
                    onChanged: controller.setEnergyUnit,
                  ),
                if (field == NutrientField.fvl)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      label: const Text('None (0 %)'),
                      onPressed: controller.noFruitOrVegetables,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (drink)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contains sweeteners'),
                  subtitle: const Text(
                    'Sweeteners without sugar in the ingredients, like '
                    'aspartame, sucralose or stevia.',
                  ),
                  value: draft.sweeteners,
                  onChanged: (value) => controller.setSweeteners(value: value),
                ),
            ],
          ),
        ),
        _SendBar(
          state: state,
          hasProblems: found.isNotEmpty,
          onSend: controller.send,
        ),
      ],
    );
  }
}

String _basisText(NutritionBasis basis) =>
    basis == NutritionBasis.per100ml ? 'per 100 mL' : 'per 100 g';

/// Where reading the table stands, and the LLM's values when they came after
/// the contributor started editing.
class _ReadingBanner extends StatelessWidget {
  const _ReadingBanner({required this.state, required this.controller});

  final ContributionState state;
  final ContributionController controller;

  @override
  Widget build(BuildContext context) {
    final readByParser = state.draft.parserUsed != ParserUsed.manual;
    final (icon, text) = switch (state.reading) {
      LabelReadingStatus.none => (
        PhosphorIconsRegular.pencilSimpleLine,
        'Type the values from the nutrition table.',
      ),
      LabelReadingStatus.reading => (
        PhosphorIconsRegular.hourglassMedium,
        'Reading the nutrition table…',
      ),
      LabelReadingStatus.askingAi => (
        PhosphorIconsRegular.hourglassMedium,
        readByParser
            ? 'Some values could not be read. Reading the table again, more '
                  'carefully…'
            : 'Reading the table again, more carefully…',
      ),
      LabelReadingStatus.aiOffered => (
        PhosphorIconsRegular.sparkle,
        'A second reading found values. Use them instead of yours?',
      ),
      LabelReadingStatus.aiApplied => (
        PhosphorIconsRegular.sparkle,
        'Read by AI from the nutrition table. Check every value against the '
            'photo.',
      ),
      LabelReadingStatus.done when readByParser => (
        PhosphorIconsRegular.listChecks,
        'Read from the nutrition table. Check every value against the photo.',
      ),
      LabelReadingStatus.done || LabelReadingStatus.failed => (
        PhosphorIconsRegular.pencilSimpleLine,
        'The table could not be read. Type the values from the photo.',
      ),
    };
    final busy =
        state.reading == LabelReadingStatus.reading ||
        state.reading == LabelReadingStatus.askingAi;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: QoutPalette.of(context).accentText),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (state.reading == LabelReadingStatus.aiOffered)
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: controller.dismissAiOffer,
                    child: const Text('Keep mine'),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.useAiOffer,
                    child: const Text('Use these values'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The Dart engine's grade for the values as they stand, marked unverified.
class _ProvisionalGrade extends StatelessWidget {
  const _ProvisionalGrade({required this.draft});

  final ContributionDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = provisionalScore(draft);
    final (grade, text) = switch (result) {
      scoring.NutriScore(:final grade) => (
        Grade.fromJson(grade.letter),
        'Provisional grade from these values. A moderator checks them '
            'against your photos before it is published.',
      ),
      scoring.InsufficientData(:final missing) => (
        null,
        missingForGrade(missing),
      ),
      null => (null, 'Correct the values marked in red to see the grade.'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            GradeBadge(grade: grade, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    avatar: Icon(
                      PhosphorIconsRegular.hourglass,
                      size: 16,
                      color: theme.chipTheme.labelStyle?.color,
                    ),
                    label: const Text('Unverified'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.category, required this.onChanged});

  final scoring.Category category;
  final void Function(scoring.Category) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<scoring.Category>(
      initialValue: category,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Kind of product',
        helperText: categoryHint(category),
      ),
      items: [
        for (final option in scoring.Category.values)
          DropdownMenuItem(value: option, child: Text(categoryLabel(option))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _BasisField extends StatelessWidget {
  const _BasisField({required this.basis, required this.onChanged});

  final NutritionBasis basis;
  final void Function(NutritionBasis) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('The table shows values'),
        const SizedBox(height: 8),
        SegmentedButton<NutritionBasis>(
          segments: const [
            ButtonSegment(
              value: NutritionBasis.per100g,
              label: Text('per 100 g'),
            ),
            ButtonSegment(
              value: NutritionBasis.per100ml,
              label: Text('per 100 mL'),
            ),
          ],
          selected: {basis},
          showSelectedIcon: false,
          onSelectionChanged: (selected) => onChanged(selected.single),
        ),
      ],
    );
  }
}

class _EnergyUnitField extends StatelessWidget {
  const _EnergyUnitField({required this.unit, required this.onChanged});

  final EnergyUnit unit;
  final void Function(EnergyUnit) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<EnergyUnit>(
          segments: const [
            ButtonSegment(value: EnergyUnit.kj, label: Text('kJ')),
            ButtonSegment(value: EnergyUnit.kcal, label: Text('kcal')),
          ],
          selected: {unit},
          showSelectedIcon: false,
          onSelectionChanged: (selected) => onChanged(selected.single),
        ),
      ),
    );
  }
}

/// One amount, typed with a decimal comma or point.
class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.field,
    required this.text,
    required this.unit,
    required this.problem,
    required this.flagged,
    required this.onChanged,
    super.key,
  });

  final NutrientField field;

  /// The text when the field is built; then the field owns what is typed.
  final String text;
  final String unit;
  final ValueProblem? problem;
  final bool flagged;
  final void Function(String) onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.problem;
    final doubt = QoutPalette.of(context).doubt;
    final doubtBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(QoutRadius.md),
      borderSide: BorderSide(color: doubt, width: 1.5),
    );
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
      decoration: InputDecoration(
        labelText: fieldLabel(widget.field),
        suffixText: widget.unit,
        errorText: problem == null ? null : problemText(problem),
        helperText: widget.flagged ? 'Check this one against the photo' : null,
        helperStyle: widget.flagged ? TextStyle(color: doubt) : null,
        enabledBorder: widget.flagged ? doubtBorder : null,
        prefixIcon: widget.flagged
            ? Icon(PhosphorIconsRegular.warning, color: doubt)
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.state,
    required this.hasProblems,
    required this.onSend,
  });

  final ContributionState state;
  final bool hasProblems;
  final Future<bool> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final message =
        state.sendError ??
        (state.showRequired && hasProblems
            ? 'Some values are missing or wrong: see the fields in red.'
            : null);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(message, style: TextStyle(color: error)),
            ),
          FilledButton(
            onPressed: state.sending ? null : onSend,
            child: state.sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    state.sendError == null ? 'Send for review' : 'Try again',
                  ),
          ),
        ],
      ),
    );
  }
}
