import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/insets.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/domain/profile_form.dart';
import 'package:qout/features/profile/presentation/profile_labels.dart';
import 'package:qout/health/profile.dart';

/// The profile form (`/profile/edit`). [firstRun]: opened from the welcome
/// screens; saving then goes home instead of back.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({this.firstRun = false, super.key});

  final bool firstRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final firstName = ref.watch(firstNameProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(firstRun ? 'Your profile' : 'Edit profile'),
      ),
      body: (firstName.isLoading ? const AsyncLoading<Profile?>() : profile)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const StateMessage(
              icon: PhosphorIconsRegular.warningCircle,
              veggie: VeggieFor.error,
              title: 'The profile could not be read',
              message: 'Try again later.',
            ),
            data: (profile) => _ProfileForm(
              initial: profile == null
                  ? ProfileFormValues.empty
                  : ProfileFormValues.of(profile),
              firstName: firstName.valueOrNull ?? '',
              firstRun: firstRun,
            ),
          ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    required this.initial,
    required this.firstName,
    required this.firstRun,
  });

  final ProfileFormValues initial;
  final String firstName;
  final bool firstRun;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _firstName = TextEditingController(text: widget.firstName);
  late final _age = TextEditingController(text: widget.initial.age);
  late final _height = TextEditingController(text: widget.initial.height);
  late final _weight = TextEditingController(text: widget.initial.weight);
  late SexChoice? _sex = widget.initial.sex;
  late ActivityLevel? _activity = widget.initial.activity;
  late final Set<Allergen> _allergens = {...widget.initial.allergens};
  Map<String, FormProblem> _problems = const {};
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  ProfileFormValues get _values => ProfileFormValues(
    sex: _sex,
    age: _age.text,
    height: _height.text,
    weight: _weight.text,
    activity: _activity,
    allergens: _allergens,
  );

  Future<void> _save() async {
    final (:profile, :problems) = readProfileForm(_values);
    setState(() => _problems = problems);
    if (profile == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.save(profile);
      await repository.saveFirstName(_firstName.text);
    } on Object {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('The profile could not be saved.')),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    if (widget.firstRun) {
      context.go(AppRoutes.home);
    } else {
      context.pop();
    }
  }

  String? _error(String field) => formProblemText(field, _problems[field]);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    const gutter = EdgeInsets.symmetric(horizontal: 16);
    return ListView(
      padding: const EdgeInsets.only(
        bottom: 24,
      ).clearOfNavigationBar(context),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Qout uses this to work out your daily needs. It stays on this '
            'phone and is never sent.',
            style: textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ),
        const SectionLabel('About you'),
        Padding(
          padding: gutter,
          child: TextField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            maxLength: maxFirstNameLength,
            decoration: const InputDecoration(
              labelText: 'First name (optional)',
              helperText: 'For the greeting on Today.',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: gutter,
          child: _ChoiceGroup(
            label: 'Sex',
            error: _error('sex'),
            children: [
              for (final choice in SexChoice.values)
                ChoiceChip(
                  label: Text(sexChoiceLabel(choice)),
                  selected: _sex == choice,
                  onSelected: (_) => setState(() => _sex = choice),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: gutter,
          child: Column(
            children: [
              _NumberField(
                controller: _age,
                label: 'Age',
                suffix: 'years',
                error: _error('age'),
                decimals: false,
              ),
              const SizedBox(height: 12),
              _NumberField(
                controller: _height,
                label: 'Height',
                suffix: 'cm',
                error: _error('height'),
              ),
              const SizedBox(height: 12),
              _NumberField(
                controller: _weight,
                label: 'Weight',
                suffix: 'kg',
                error: _error('weight'),
              ),
            ],
          ),
        ),
        const SectionLabel('Activity'),
        for (final level in ActivityLevel.values)
          _ActivityTile(
            level: level,
            selected: _activity == level,
            onTap: () => setState(() => _activity = level),
          ),
        if (_error('activity') case final error?)
          Padding(
            padding: gutter,
            child: _ErrorText(error),
          ),
        const SectionLabel('Allergies (optional)'),
        Padding(
          padding: gutter,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final allergen in Allergen.values)
                FilterChip(
                  label: Text(allergenLabel(allergen)),
                  selected: _allergens.contains(allergen),
                  onSelected: (on) => setState(
                    () => on
                        ? _allergens.add(allergen)
                        : _allergens.remove(allergen),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            "Pregnant or breastfeeding? Qout's advice is not tailored for "
            'that yet.',
            style: textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ),
      ],
    );
  }
}

/// A label, a row of chips that wraps, and the error under them.
class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.children,
    this.error,
  });

  final String label;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: children),
      if (error case final text?) _ErrorText(text),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.error,
    this.decimals = true,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? error;
  final bool decimals;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimals),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(decimals ? '[0-9.,]' : '[0-9]')),
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      errorText: error,
      errorMaxLines: 2,
    ),
  );
}

/// One of EFSA's activity levels, with an example; one can be chosen.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: ListTile(
        selected: selected,
        onTap: onTap,
        leading: Icon(
          selected
              ? PhosphorIconsFill.radioButton
              : PhosphorIconsRegular.circle,
          color: selected ? palette.accentText : palette.muted,
        ),
        title: Text(activityTitle(level)),
        subtitle: Text(activityExample(level)),
      ),
    );
  }
}
