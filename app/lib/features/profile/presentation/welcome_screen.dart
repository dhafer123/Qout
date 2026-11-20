import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show Grade;
import 'package:qout/features/product/presentation/grade_badge.dart';

/// First run (`/welcome`): what the grade means, that scanning needs no
/// account, and what happens to the user's data; then the profile, which is
/// required (T31e).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == _count - 1;

  void _next() => unawaited(
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ),
  );

  void _setUp() =>
      unawaited(context.push(AppRoutes.profileEdit, extra: firstRunEdit));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [_GradePage(), _AccountPage(), _DataPage()],
              ),
            ),
            _Dots(count: _count, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _last ? _setUp : _next,
                    child: Text(_last ? 'Set up my profile' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Passed as `extra` to the profile form on the first run: saving goes home.
const firstRunEdit = 'first-run';

/// One welcome page: an illustration, a title and a few lines.
class _Page extends StatelessWidget {
  const _Page({
    required this.illustration,
    required this.title,
    required this.lines,
  });

  final Widget illustration;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          illustration,
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(title, style: textTheme.headlineSmall),
          ),
          for (final line in lines) ...[
            const SizedBox(height: 12),
            Text(line, style: textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

class _GradePage extends StatelessWidget {
  const _GradePage();

  @override
  Widget build(BuildContext context) => _Page(
    illustration: ExcludeSemantics(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final grade in [Grade.a, Grade.b, Grade.c, Grade.d, Grade.e])
            GradeBadge(grade: grade, size: 48),
        ],
      ),
    ),
    title: 'Know what you eat',
    lines: const [
      _gradeScale,
      _gradeReasons,
    ],
  );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();

  @override
  Widget build(BuildContext context) => const _Page(
    illustration: _Icon(PhosphorIconsRegular.barcode),
    title: 'No account needed',
    lines: [
      _noAccount,
      'You only sign in to add a product Qout does not know yet.',
    ],
  );
}

class _DataPage extends StatelessWidget {
  const _DataPage();

  @override
  Widget build(BuildContext context) => const _Page(
    illustration: _Icon(PhosphorIconsRegular.lockSimple),
    title: 'Advice for you, kept on your phone',
    lines: [
      _profileStays,
      _photosSent,
      'Qout gives general information, not medical advice.',
    ],
  );
}

class _Icon extends StatelessWidget {
  const _Icon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(icon, size: 56, color: QoutPalette.of(context).accentText),
  );
}

/// Which page is shown: one dot per page.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = QoutPalette.of(context);
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == current ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == current ? palette.accentText : scheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Welcome texts that span lines (kept out of the list literals).
const _gradeScale =
    'Scan a food barcode and Qout grades it from A (best) to E, with the '
    'Nutri-Score.';
const _gradeReasons =
    'Every grade comes with the reasons: what counts against the food and '
    'what counts in its favour.';
const _noAccount =
    'Scanning works without an account, and products you have seen stay '
    'available offline.';
const _profileStays =
    'A short profile lets Qout compare products with your daily needs. It '
    'stays on this phone and is never sent.';
const _photosSent =
    'Photos are sent only when you add a product, for a moderator to '
    'check.';
