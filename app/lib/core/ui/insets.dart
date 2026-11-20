import 'package:flutter/widgets.dart';

/// The app draws behind the system bars (edge to edge, enforced from
/// Android 15). Content that scrolls passes under the navigation bar, but its
/// end must stop above it, or the last buttons can't be reached.
extension ClearOfNavigationBar on EdgeInsets {
  /// This padding with the system navigation bar's height added at the
  /// bottom. Zero while the keyboard is open (it covers the bar), so the
  /// gap doesn't double.
  EdgeInsets clearOfNavigationBar(BuildContext context) =>
      copyWith(bottom: bottom + MediaQuery.paddingOf(context).bottom);
}
