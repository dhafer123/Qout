import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/core/ui/fading_rule.dart';
import 'package:qout/core/ui/insets.dart';
import 'package:qout/core/ui/section_card.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/product/presentation/product_labels.dart'
    show formatAmount, kjPerKcalForDisplay;
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/domain/profile_form.dart';
import 'package:qout/features/profile/presentation/profile_avatar.dart';
import 'package:qout/features/profile/presentation/profile_labels.dart';
import 'package:qout/features/profile/presentation/welcome_screen.dart';
import 'package:qout/features/settings/presentation/appearance_card.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The account, the profile and the daily needs worked out from it
/// (`/profile`).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final dev = ref.watch(appEnvProvider).flavor == AppFlavor.dev;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          veggie: VeggieFor.error,
          title: 'The profile could not be read',
          message: 'Try again later.',
        ),
        data: (profile) => EntranceScope(
          child: ListView(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 24,
            ).clearOfNavigationBar(context),
            children: [
              for (final (i, section) in [
                _Header(profile),
                if (profile == null) const _NoProfile(),
                _Needs(computeNeeds(profile)),
                if (profile != null) _About(profile),
                const _AvoidedAdditives(),
                const AppearanceCard(),
                const _DeleteDiary(),
                if (profile != null) const _DeleteProfile(),
                if (dev) const _Developer(),
                // Signing in or out, last (T43d).
                const _Account(),
              ].indexed)
                Entrance(index: i, child: section),
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's initial, name and a summary on a green banner.
class _Header extends ConsumerWidget {
  const _Header(this.profile);

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final palette = QoutPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    final name = ref.watch(firstNameProvider).valueOrNull;
    final profile = this.profile;
    final colors = dark
        ? [
            palette.tag,
            Color.lerp(palette.tag, theme.colorScheme.surface, 0.5)!,
          ]
        : [palette.accent, Color.lerp(palette.accent, Colors.black, 0.3)!];
    final onBanner = dark ? palette.onTag : Colors.white;
    final summary = profile == null
        ? 'Add your details below.'
        : [
            '${profile.age} years',
            sexChoiceLabel(SexChoiceX.of(profile.sex)),
            activityTitle(profile.activity),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              EditableProfileAvatar(
                firstName: name,
                background: Color.alphaBlend(
                  onBanner.withValues(alpha: 0.18),
                  colors.first,
                ),
                foreground: onBanner,
                border: Border.all(color: onBanner.withValues(alpha: 0.6)),
                badgeBackground: onBanner,
                badgeForeground: colors.first,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        name ?? 'Your profile',
                        style: textTheme.titleLarge?.copyWith(color: onBanner),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: textTheme.bodyMedium?.copyWith(color: onBanner),
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

/// Who is signed in, with sign out; or why and where to sign in.
class _Account extends ConsumerWidget {
  const _Account();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final email = switch (auth) {
      SignedIn(:final email) => email,
      _ => null,
    };
    return SectionCard(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(email: email),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email == null ? 'Not signed in' : 'Signed in as',
                      style: email == null
                          ? textTheme.titleSmall
                          : textTheme.bodySmall,
                    ),
                    Text(
                      email ??
                          'Scanning needs no account. Sign in to add '
                              'products.',
                      style: email == null
                          ? textTheme.bodySmall
                          : textTheme.titleSmall,
                      maxLines: email == null ? null : 2,
                      overflow: email == null ? null : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (email == null)
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.signIn),
              icon: const Icon(PhosphorIconsRegular.signIn, size: 20),
              label: const Text('Sign in'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: palette.muted),
              onPressed: () => unawaited(_signOut(context, ref)),
              icon: const Icon(PhosphorIconsRegular.signOut, size: 20),
              label: const Text('Sign out'),
            ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Scanning keeps working. Adding products needs you to sign in '
          'again; anything waiting to be sent waits until then.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (!(signOut ?? false)) return;
    await ref.read(authRepositoryProvider).signOut();
    messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final email = this.email;
    final initial = email == null || email.isEmpty
        ? null
        : email.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: initial == null ? palette.track : palette.tag,
            border: Border.all(
              color: initial == null ? palette.edge : palette.accent,
            ),
          ),
          child: Center(
            child: initial == null
                ? Icon(PhosphorIconsRegular.user, color: palette.muted)
                : Text(
                    initial,
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
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile();

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'No profile yet',
    icon: PhosphorIconsRegular.userCircle,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

/// What the user entered, the BMI in neutral words, and the way to edit it.
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
    return SectionCard(
      title: 'About you',
      icon: PhosphorIconsRegular.identificationCard,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row('Sex', sexChoiceLabel(SexChoiceX.of(profile.sex))),
          _Row('Age', '${profile.age} years'),
          _Row('Height', '${formatAmount(profile.heightCm, decimals: 1)} cm'),
          _Row('Weight', '${formatAmount(profile.weightKg, decimals: 1)} kg'),
          _Row('Activity', activityTitle(profile.activity)),
          _Row('Allergies', allergens),
          _Row('BMI', '${bmi.display}, ${bmiText(bmi)}', last: true),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.profileEdit),
              icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
              label: const Text('Edit profile'),
            ),
          ),
        ],
      ),
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
    final palette = QoutPalette.of(context);
    final kj = needs.energyKj;
    final kcal = formatAmount(kj / kjPerKcalForDisplay, decimals: 0);
    final energySpoken = '$kcal kilocalories, $kj kilojoules a day';
    return SectionCard(
      title: personal ? 'Your daily needs' : 'Daily reference',
      icon: PhosphorIconsRegular.target,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Energy: $energySpoken',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  '$kcal kcal',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabular,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '$kj kJ a day',
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _NeedTiles(
            tiles: [
              ('Fat', 'up to', '${needs.fatG} g'),
              ('Saturated fat', 'up to', '${needs.saturatesG} g'),
              ('Sugars (reference)', null, '${needs.sugarsG} g'),
              ('Salt', personal ? 'under' : null, '${needs.saltG} g'),
            ],
          ),
          const SizedBox(height: 4),
          Theme(
            // No lines above and below the opened tile.
            data: Theme.of(
              context,
            ).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 14),
              expandedAlignment: Alignment.centerLeft,
              iconColor: palette.muted,
              collapsedIconColor: palette.muted,
              title: Text(
                personal ? 'How these are worked out' : 'Where these come from',
                style: textTheme.bodySmall,
              ),
              children: [
                Text(
                  personal
                      ? 'Energy to keep your current weight: EFSA (2013). '
                            'Fat: up to 35 % of energy (EFSA). Saturated '
                            'fat: 10 % of energy (WHO, 2023). Salt: WHO '
                            '(2012). Sugars: the EU reference intake for '
                            'total sugars; WHO advises keeping free sugars '
                            '(added sugars, honey, syrups, fruit juices) '
                            'under 10 % of energy.'
                      : '${referenceReasonText(needs.referenceReason!)} '
                            'Regulation (EU) 1169/2011, Annex XIII.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two tiles per row; one per row when text is large.
class _NeedTiles extends StatelessWidget {
  const _NeedTiles({required this.tiles});

  /// Label, the word before the amount (or none), the amount.
  final List<(String, String?, String)> tiles;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = large
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, qualifier, amount) in tiles)
              SizedBox(
                width: width,
                child: _NeedTile(
                  label: label,
                  qualifier: qualifier,
                  amount: amount,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({
    required this.label,
    required this.qualifier,
    required this.amount,
  });

  final String label;
  final String? qualifier;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final qualifier = this.qualifier;
    final spoken = [label, ?qualifier, amount].join(', ');
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.track.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(QoutRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodySmall),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    if (qualifier != null)
                      TextSpan(
                        text: '$qualifier ',
                        style: textTheme.bodySmall,
                      ),
                    TextSpan(
                      text: amount,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: _tabular,
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

/// The additives the user marked to avoid on product screens (T40).
class _AvoidedAdditives extends ConsumerWidget {
  const _AvoidedAdditives();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes =
        (ref.watch(avoidedAdditivesProvider).valueOrNull ?? const {}).toList()
          ..sort();
    if (codes.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Additives you avoid',
      icon: PhosphorIconsRegular.prohibit,
      iconColor: Theme.of(context).colorScheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final code in codes)
            ListTile(
              title: Text(code),
              trailing: TextButton(
                onPressed: () => ref
                    .read(profileRepositoryProvider)
                    .setAvoided(code, avoid: false),
                child: Text('Remove', semanticsLabel: 'Stop avoiding $code'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Deletes everything logged in the diary (T42), after asking.
class _DeleteDiary extends ConsumerWidget {
  const _DeleteDiary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error.withValues(alpha: 0.5)),
        ),
        onPressed: () => unawaited(_confirm(context, ref)),
        icon: const Icon(PhosphorIconsRegular.notebook, size: 20),
        label: const Text('Delete my diary'),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your diary?'),
        content: const Text(
          'Everything you logged is removed from this phone. Your scans and '
          'your profile stay.',
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
    if (!(delete ?? false)) return;
    await ref.read(diaryRepositoryProvider).clear();
    messenger.showSnackBar(const SnackBar(content: Text('Diary deleted')));
  }
}

class _DeleteProfile extends ConsumerWidget {
  const _DeleteProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error.withValues(alpha: 0.5)),
        ),
        onPressed: () => unawaited(_confirmDelete(context, ref)),
        icon: const Icon(PhosphorIconsRegular.trash, size: 20),
        label: const Text('Delete my profile'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your profile?'),
        content: const Text(
          'Your age, height, weight, activity, allergies, the additives you '
          'avoid and your photo are removed from this phone. Qout then asks '
          'for a new profile.',
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
    if (!(delete ?? false)) return;
    await ref.read(profileRepositoryProvider).delete();
    // The profile is required (T31e): straight back to its form.
    if (context.mounted) {
      context.go(AppRoutes.profileEdit, extra: firstRunEdit);
    }
  }
}

/// Dev flavor only: tools for building the app.
class _Developer extends StatelessWidget {
  const _Developer();

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Developer',
    icon: PhosphorIconsRegular.wrench,
    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: ListTile(
      title: const Text('Label OCR (dev)'),
      subtitle: const Text('Photograph labels for the parser evaluation'),
      trailing: const Icon(PhosphorIconsRegular.caretRight, size: 18),
      onTap: () => context.push(AppRoutes.labelOcr),
    ),
  );
}

/// A label and its value; the value moves under the label when space is
/// short (large text).
class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

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
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
          if (!last) const FadingRule(),
        ],
      ),
    );
  }
}
