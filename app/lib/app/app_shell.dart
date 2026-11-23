import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

/// Today · Diary | raised Scan | Progress · Profile. Every tab shows its
/// icon and label; the active one has a soft tinted pill behind its icon
/// (T43f). Solid green is kept for the Scan button alone.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = QoutPalette.of(context);
    final dark = theme.brightness == Brightness.dark;

    Widget tab(AppTab tab) => Expanded(
      child: _Tab(
        tab: tab,
        active: tab == current,
        onTap: () => onTab(tab),
      ),
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
                    color: Color(0x1F3A2A14),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              children: [
                tab(AppTab.today),
                tab(AppTab.diary),
                _ScanButton(onPressed: onScan),
                tab(AppTab.progress),
                tab(AppTab.profile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab: its icon (on a tinted pill when active) and its label under it.
class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = QoutPalette.of(context);
    final color = active ? palette.accentText : palette.muted;
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('tab-${tab.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                key: ValueKey('tab-pill-${tab.name}'),
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? palette.tag : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  active ? tab.activeIcon : tab.icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
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
