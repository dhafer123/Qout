import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/fading_rule.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/features/product/presentation/product_labels.dart'
    show formatAmount, formatEnergy;
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/domain/profile_form.dart';
import 'package:qout/features/profile/presentation/profile_labels.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

/// The profile and the daily needs worked out from it (`/profile`).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'The profile could not be read',
          message: 'Try again later.',
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (profile == null) const _NoProfile() else _About(profile),
            _Needs(computeNeeds(profile)),
            if (profile != null) const _Actions(),
          ],
        ),
      ),
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No profile yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Add your age, height, weight and activity to compare products '
          'with your own daily needs. It stays on this phone.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.profileEdit),
          icon: const Icon(PhosphorIconsRegular.userPlus, size: 20),
          label: const Text('Set up my profile'),
        ),
      ],
    ),
  );
}

/// What the user entered, and the BMI in neutral words.
class _About extends StatelessWidget {
  const _About(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final bmi = bmiOf(heightCm: profile.heightCm, weightKg: profile.weightKg);
    final allergens = profile.allergens.isEmpty
        ? 'None'
        : [
            for (final allergen in Allergen.values)
              if (profile.allergens.contains(allergen)) allergenLabel(allergen),
          ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('About you'),
        _Row('Sex', sexChoiceLabel(SexChoiceX.of(profile.sex))),
        _Row('Age', '${profile.age} years'),
        _Row('Height', '${formatAmount(profile.heightCm, decimals: 1)} cm'),
        _Row('Weight', '${formatAmount(profile.weightKg, decimals: 1)} kg'),
        _Row('Activity', activityTitle(profile.activity)),
        _Row('Allergies', allergens),
        _Row('BMI', '${bmi.display}, ${bmiText(bmi)}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            'BMI does not tell muscle from fat; it is shown for information '
            'only.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// The daily amounts advice compares products with, and where they come
/// from.
class _Needs extends StatelessWidget {
  const _Needs(this.needs);

  final DailyNeeds needs;

  @override
  Widget build(BuildContext context) {
    final personal = needs.basis == NeedsBasis.personal;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(personal ? 'Your daily needs' : 'Daily reference'),
        _Row('Energy', formatEnergy(needs.energyKj.toDouble())),
        _Row('Fat', 'up to ${needs.fatG} g'),
        _Row('Saturated fat', 'up to ${needs.saturatesG} g'),
        _Row('Sugars', '${needs.sugarsG} g (reference)'),
        _Row('Salt', personal ? 'under ${needs.saltG} g' : '${needs.saltG} g'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            personal
                ? 'Energy to keep your current weight: EFSA (2013). Fat: up '
                      'to 35 % of energy (EFSA). Saturated fat: 10 % of energy '
                      '(WHO, 2023). Salt: WHO (2012). Sugars: the EU reference '
                      'intake for total sugars; WHO advises keeping free '
                      'sugars (added sugars, honey, syrups, fruit juices) '
                      'under 10 % of energy.'
                : '${referenceReasonText(needs.referenceReason!)} '
                      'Regulation (EU) 1169/2011, Annex XIII.',
            style: textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.profileEdit),
          icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
          label: const Text('Edit profile'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => unawaited(_confirmDelete(context, ref)),
          icon: const Icon(PhosphorIconsRegular.trash, size: 20),
          label: const Text('Delete my profile'),
        ),
      ],
    ),
  );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your profile?'),
        content: const Text(
          'Your age, height, weight, activity and allergies are removed from '
          'this phone. Advice then uses the EU reference intakes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete ?? false) await ref.read(profileRepositoryProvider).delete();
  }
}

/// A label and its value; the value moves under the label when space is
/// short (large text).
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(color: palette.muted),
                ),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const FadingRule(),
        ],
      ),
    );
  }
}
