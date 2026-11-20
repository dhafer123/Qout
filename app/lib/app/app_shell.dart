import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';

/// The tabs, in the order of the shell's branches.
enum AppTab {
  today('Today', PhosphorIconsRegular.sun, PhosphorIconsFill.sun),
  diary('Diary', PhosphorIconsRegular.notebook, PhosphorIconsFill.notebook),
  progress(
    'Progress',
    PhosphorIconsRegular.chartLineUp,
    PhosphorIconsFill.chartLineUp,
  ),
  profile('Profile', PhosphorIconsRegular.user, PhosphorIconsFill.user)
  ;

  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The tabs with the bottom bar (T41). Back on another tab goes to Today
/// first; back on Today leaves the app.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: QoutNavBar(
          current: AppTab.values[shell.currentIndex],
          onTab: (tab) => _go(tab.index),
          onScan: () => context.push(AppRoutes.scan),
        ),
      ),
    );
  }
}

/// Today · Diary | raised Scan | Progress · Profile. The active tab is a
/// green pill with its label (`google_nav_bar`); the bar is two halves so
/// the Scan button stays in the middle whatever the pill's width.
class QoutNavBar extends StatelessWidget {
  const QoutNavBar({
    required this.current,
    required this.onTab,
    required this.onScan,
    super.key,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onScan;

  static const double scanSize = 60;
  static const double _iconSize = 22;

  /// Around each icon: 22 + 2 × 13 = 48 px, the smallest touch target.
  static const double _tabPadding = 13;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = QoutPalette.of(context);
    final dark = theme.brightness == Brightness.dark;

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onPrimary,
    );

    // Labels show when the widest one fits next to the other tab's icon;
    // on a narrow screen (or with large text) the pills keep only their
    // icons. Decided per half, whichever tab is active, so a pill shrinking
    // away never needs more room than the half has. Each tab stays at least
    // 48 px wide.
    Widget half(List<AppTab> tabs) => LayoutBuilder(
      builder: (context, constraints) {
        const iconBox = _iconSize + 2 * _tabPadding;
        var widest = 0.0;
        for (final tab in tabs) {
          final painter = TextPainter(
            text: TextSpan(text: tab.label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        final labels =
            iconBox * tabs.length + _gap + widest + 8 <= constraints.maxWidth;
        return GNav(
          selectedIndex: tabs.indexOf(current), // -1: none on this side
          onTabChange: (index) => onTab(tabs[index]),
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          gap: labels ? _gap : 0,
          iconSize: _iconSize,
          padding: const EdgeInsets.symmetric(
            horizontal: _tabPadding,
            vertical: _tabPadding,
          ),
          duration: const Duration(milliseconds: 250),
          tabBorderRadius: 24,
          color: palette.muted,
          activeColor: scheme.onPrimary,
          tabBackgroundColor: scheme.primary,
          rippleColor: palette.accent.withValues(alpha: 0.12),
          hoverColor: palette.accent.withValues(alpha: 0.08),
          textStyle: labelStyle,
          tabs: [
            for (final tab in tabs)
              GButton(
                key: ValueKey('tab-${tab.name}'),
                icon: tab.icon,
                // The package's own label sits outside the tappable node,
                // and an inactive tab hides its text: the icon names it.
                leading: Icon(
                  tab == current ? tab.activeIcon : tab.icon,
                  size: _iconSize,
                  color: tab == current ? scheme.onPrimary : palette.muted,
                  semanticLabel: tab == current && labels
                      ? null // the visible label reads it
                      : tab.label,
                ),
                text: labels ? tab.label : '',
                semanticLabel: '',
              ),
          ],
        );
      },
    );

    // Labels stay readable at large text sizes without pushing the bar
    // apart.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: dark ? Border(top: BorderSide(color: palette.edge)) : null,
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x1F17401C),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                Expanded(child: half(const [AppTab.today, AppTab.diary])),
                _ScanButton(onPressed: onScan),
                Expanded(
                  child: half(const [AppTab.progress, AppTab.profile]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised round button in the middle of the bar.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Tooltip(
          message: 'Scan a barcode',
          child: Semantics(
            button: true,
            label: 'Scan a barcode',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: QoutNavBar.scanSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('scan-button'),
                    onTap: onPressed,
                    child: Icon(
                      PhosphorIconsBold.barcode,
                      size: 28,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
