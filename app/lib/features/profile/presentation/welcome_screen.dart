import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/profile/presentation/welcome_art.dart';

/// First run (`/welcome`): what Qout is, what the grade means, that scanning
/// needs no account, and what happens to the user's data; then the profile,
/// which is required (T31e). "Skip" only jumps to the last page, whose one
/// action is setting up the profile.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = QoutPalette.of(context);
    final decoration = PageDecoration(
      pageColor: scheme.surface,
      imageFlex: 5,
      bodyFlex: 6,
      imagePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      titlePadding: const EdgeInsets.only(top: 8, bottom: 14),
      contentMargin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      bodyPadding: EdgeInsets.zero,
      pageMargin: const EdgeInsets.only(bottom: 72),
      safeArea: 0,
    );
    // The ground also fills the area under the status and navigation bars,
    // which the package leaves outside its own Scaffold.
    return ColoredBox(
      color: scheme.surface,
      child: IntroductionScreen(
        globalBackgroundColor: scheme.surface,
        safeAreaList: const [true, true, true, true],
        pages: [
          PageViewModel(
            titleWidget: const _Title('Welcome to Qout'),
            bodyWidget: const Column(
              children: [
                _Body(_welcomePage),
                SizedBox(height: 28),
                WelcomeFeatures(),
              ],
            ),
            image: const GreetingArt(),
            decoration: decoration,
          ),
          PageViewModel(
            titleWidget: const _Title('Know what you eat'),
            bodyWidget: const _Body(_gradePage),
            image: const GradeScaleArt(),
            decoration: decoration,
          ),
          PageViewModel(
            titleWidget: const _Title('No account needed'),
            bodyWidget: const _Body(_accountPage),
            image: const ScanArt(),
            decoration: decoration,
          ),
          PageViewModel(
            titleWidget: const _Title('Advice for you, kept on your phone'),
            bodyWidget: const _Body(_dataPage, note: _notMedical),
            image: const ShieldArt(),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: FilledButton.icon(
                onPressed: () => unawaited(
                  context.push(AppRoutes.profileEdit, extra: firstRunEdit),
                ),
                icon: const Icon(PhosphorIconsRegular.userCircle),
                label: const Text('Set up my profile'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            decoration: decoration.copyWith(
              imageFlex: 4,
              footerFit: FlexFit.tight,
            ),
          ),
        ],
        showSkipButton: true,
        skip: const Text('Skip'),
        skipStyle: TextButton.styleFrom(
          foregroundColor: palette.muted,
          minimumSize: const Size(64, 48),
        ),
        overrideNext: (context, onPressed) => Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onPressed,
            iconAlignment: IconAlignment.end,
            icon: const Icon(PhosphorIconsRegular.arrowRight, size: 18),
            label: const Text('Next'),
          ),
        ),
        // The last page's own button sets up the profile.
        showDoneButton: false,
        // Room for "Next" at twice the text size on a 360 dp wide phone.
        skipOrBackFlex: 3,
        dotsFlex: 3,
        nextFlex: 4,
        controlsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        curve: Curves.easeOutCubic,
        dotsDecorator: DotsDecorator(
          size: const Size(8, 8),
          activeSize: const Size(24, 8),
          color: scheme.outline,
          activeColor: palette.accent,
          spacing: const EdgeInsets.symmetric(horizontal: 4),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Passed as `extra` to the profile form on the first run: saving goes home.
const firstRunEdit = 'first-run';

/// The welcome page's three things Qout does, an icon and a few words each.
class WelcomeFeatures extends StatelessWidget {
  const WelcomeFeatures({super.key});

  static const List<(IconData, String)> features = [
    (PhosphorIconsRegular.barcode, 'Scan a barcode'),
    (PhosphorIconsRegular.sealCheck, 'See the grade and why'),
    (PhosphorIconsRegular.forkKnife, 'Track what you eat'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    // A block centred on the page, its rows aligned on their icons.
    return Center(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (icon, label)) in features.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.tag,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, size: 22, color: palette.onTag),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// A run of body text; strong runs are set in the accent, a step bolder.
typedef _Run = (String text, {bool strong});

/// A page's paragraphs (each a list of runs), centred, then an optional
/// small [note].
class _Body extends StatelessWidget {
  const _Body(this.paragraphs, {this.note});

  final List<List<_Run>> paragraphs;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final base = textTheme.bodyLarge?.copyWith(height: 1.5);
    final strong = base?.copyWith(
      color: palette.accentText,
      fontWeight: FontWeight.w600,
    );
    return Column(
      children: [
        for (final (i, paragraph) in paragraphs.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                for (final run in paragraph)
                  TextSpan(text: run.$1, style: run.strong ? strong : base),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (note case final note?) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.info, size: 16, color: palette.muted),
              const SizedBox(width: 6),
              Flexible(child: Text(note, style: textTheme.bodySmall)),
            ],
          ),
        ],
      ],
    );
  }
}

// The welcome texts.
const List<List<_Run>> _welcomePage = [
  [
    ('Qout', strong: true),
    (
      ' grades the food you buy, tells you why, and keeps track of what '
          'you eat.',
      strong: false,
    ),
  ],
];

const List<List<_Run>> _gradePage = [
  [
    ('Scan a food barcode and Qout grades it from ', strong: false),
    ('A (best) to E', strong: true),
    (', with the Nutri-Score.', strong: false),
  ],
  [
    ('Every grade comes with ', strong: false),
    ('the reasons', strong: true),
    (
      ': what counts against the food and what counts in its favour.',
      strong: false,
    ),
  ],
];

const List<List<_Run>> _accountPage = [
  [
    ('Scanning works ', strong: false),
    ('without an account', strong: true),
    (', and products you have seen stay ', strong: false),
    ('available offline', strong: true),
    ('.', strong: false),
  ],
  [
    ('You only sign in to ', strong: false),
    ('add a product', strong: true),
    (' Qout does not know yet.', strong: false),
  ],
];

const List<List<_Run>> _dataPage = [
  [
    ('A short profile lets Qout compare products with ', strong: false),
    ('your daily needs', strong: true),
    ('. It stays on this phone and is ', strong: false),
    ('never sent', strong: true),
    ('.', strong: false),
  ],
  [
    (
      'Photos are sent only when you add a product, for a moderator to '
          'check.',
      strong: false,
    ),
  ],
];

const _notMedical = 'Qout gives general information, not medical advice.';
