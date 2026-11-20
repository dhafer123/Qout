import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Qout's look: the "Nocturne" direction (Claude Design handoff, 2026-11-18).
/// A blue-grey ground, Inter at medium weight, 8 px corners, and one blurple
/// accent used as a line (outlines, focus, progress) rather than a fill.
/// Dark and light follow the phone's setting.

/// Font family bundled in `assets/fonts/inter` (SIL Open Font License).
const String qoutFontFamily = 'Inter';

/// Corner radii.
abstract final class QoutRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 14;
}

/// The colours Material's [ColorScheme] has no role for. Read with
/// `QoutPalette.of(context)`.
@immutable
class QoutPalette extends ThemeExtension<QoutPalette> {
  const QoutPalette({
    required this.muted,
    required this.edge,
    required this.divider,
    required this.track,
    required this.accent,
    required this.accentText,
    required this.accentTint,
    required this.tag,
    required this.onTag,
    required this.against,
    required this.inFavour,
    required this.photoStripeA,
    required this.photoStripeB,
    required this.doubt,
  });

  /// Secondary text: captions, barcodes, dates, section labels.
  final Color muted;

  /// The hairline around cards and other raised surfaces.
  final Color edge;

  /// Rules between rows (drawn fading at their ends, see `FadingRule`).
  final Color divider;

  /// The empty part of a bar.
  final Color track;

  /// The accent as a line: outlines, focus, progress.
  final Color accent;

  /// Text and icons in the accent (a lighter step on dark, so it reads as
  /// body text).
  final Color accentText;

  /// The faint accent wash inside outlined primary actions.
  final Color accentTint;

  /// Small labels such as "Verified".
  final Color tag;
  final Color onTag;

  /// Bars for points against the product and in its favour.
  final Color against;
  final Color inFavour;

  /// Stripes shown where a product photo is missing or still loading.
  final Color photoStripeA;
  final Color photoStripeB;

  /// Values a reader is unsure of ("check this one against the photo").
  final Color doubt;

  static const QoutPalette dark = QoutPalette(
    muted: Color(0xFF9EA2B6),
    edge: Color(0xFF3F424D),
    divider: Color(0x29E9E9ED),
    track: Color(0xFF2E3140),
    accent: Color(0xFF9184D9),
    accentText: Color(0xFFD2CEFD),
    accentTint: Color(0x149184D9),
    tag: Color(0xFF423A6A),
    onTag: Color(0xFFF5F4FF),
    against: Color(0xFFF47D67),
    inFavour: Color(0xFF72D48A),
    photoStripeA: Color(0xFF232532),
    photoStripeB: Color(0xFF2E3140),
    doubt: Color(0xFFF6A14F),
  );

  static const QoutPalette light = QoutPalette(
    muted: Color(0xFF595D6C),
    edge: Color(0xFFDFE2F0),
    divider: Color(0x241B1D2B),
    track: Color(0xFFE4E7F5),
    accent: Color(0xFF796CBF),
    accentText: Color(0xFF4F4589),
    accentTint: Color(0x0F796CBF),
    tag: Color(0xFFE7E5FE),
    onTag: Color(0xFF423A6A),
    against: Color(0xFFE05C45),
    inFavour: Color(0xFF399D57),
    photoStripeA: Color(0xFFFBFBFE),
    photoStripeB: Color(0xFFE4E7F5),
    doubt: Color(0xFF9A5400),
  );

  List<Color> get _values => [
    muted,
    edge,
    divider,
    track,
    accent,
    accentText,
    accentTint,
    tag,
    onTag,
    against,
    inFavour,
    photoStripeA,
    photoStripeB,
    doubt,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QoutPalette) return false;
    final mine = _values;
    final theirs = other._values;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);

  static QoutPalette of(BuildContext context) =>
      Theme.of(context).extension<QoutPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  QoutPalette copyWith({
    Color? muted,
    Color? edge,
    Color? divider,
    Color? track,
    Color? accent,
    Color? accentText,
    Color? accentTint,
    Color? tag,
    Color? onTag,
    Color? against,
    Color? inFavour,
    Color? photoStripeA,
    Color? photoStripeB,
    Color? doubt,
  }) => QoutPalette(
    muted: muted ?? this.muted,
    edge: edge ?? this.edge,
    divider: divider ?? this.divider,
    track: track ?? this.track,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentTint: accentTint ?? this.accentTint,
    tag: tag ?? this.tag,
    onTag: onTag ?? this.onTag,
    against: against ?? this.against,
    inFavour: inFavour ?? this.inFavour,
    photoStripeA: photoStripeA ?? this.photoStripeA,
    photoStripeB: photoStripeB ?? this.photoStripeB,
    doubt: doubt ?? this.doubt,
  );

  @override
  QoutPalette lerp(QoutPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return QoutPalette(
      muted: mix(muted, other.muted),
      edge: mix(edge, other.edge),
      divider: mix(divider, other.divider),
      track: mix(track, other.track),
      accent: mix(accent, other.accent),
      accentText: mix(accentText, other.accentText),
      accentTint: mix(accentTint, other.accentTint),
      tag: mix(tag, other.tag),
      onTag: mix(onTag, other.onTag),
      against: mix(against, other.against),
      inFavour: mix(inFavour, other.inFavour),
      photoStripeA: mix(photoStripeA, other.photoStripeA),
      photoStripeB: mix(photoStripeB, other.photoStripeB),
      doubt: mix(doubt, other.doubt),
    );
  }
}

ColorScheme _scheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? QoutPalette.dark : QoutPalette.light;
  final ground = dark ? const Color(0xFF161826) : const Color(0xFFF3F5FE);
  final surface = dark ? const Color(0xFF232532) : const Color(0xFFFBFBFE);
  final text = dark ? const Color(0xFFE9E9ED) : const Color(0xFF1B1D2B);
  return ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: ground,
    primaryContainer: p.tag,
    onPrimaryContainer: p.onTag,
    secondary: p.accent,
    onSecondary: ground,
    secondaryContainer: p.tag,
    onSecondaryContainer: p.onTag,
    tertiary: p.accent,
    onTertiary: ground,
    error: dark ? const Color(0xFFF47D67) : const Color(0xFFB4372A),
    onError: dark ? const Color(0xFF161826) : const Color(0xFFFFFFFF),
    errorContainer: dark ? const Color(0xFF4A2621) : const Color(0xFFFBE3DF),
    onErrorContainer: dark ? const Color(0xFFFFDAD3) : const Color(0xFF5C1A12),
    surface: ground,
    onSurface: text,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: ground,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: p.track,
    outline: p.edge,
    outlineVariant: p.divider,
    inverseSurface: text,
    onInverseSurface: ground,
    inversePrimary: p.accentText,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );
}

TextTheme _textTheme(Color text, Color muted) {
  TextStyle style(
    double size,
    FontWeight weight, {
    double height = 1.45,
    double spacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: qoutFontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color ?? text,
  );
  return TextTheme(
    displaySmall: style(35, FontWeight.w600, height: 1),
    headlineMedium: style(28, FontWeight.w500, height: 1.15, spacing: -0.4),
    // Home's prompt.
    headlineSmall: style(26, FontWeight.w500, height: 1.15, spacing: -0.4),
    // Product name, screen headings.
    titleLarge: style(24, FontWeight.w500, height: 1.15, spacing: -0.36),
    // Section headings ("Why this score").
    titleMedium: style(19, FontWeight.w500, height: 1.3),
    titleSmall: style(15, FontWeight.w500),
    bodyLarge: style(15, FontWeight.w400),
    bodyMedium: style(15, FontWeight.w400),
    bodySmall: style(13, FontWeight.w400, color: muted),
    labelLarge: style(14, FontWeight.w500, height: 1.2),
    labelMedium: style(13, FontWeight.w500, height: 1.2),
    // Uppercase section labels ("HISTORY").
    labelSmall: style(12, FontWeight.w500, spacing: 0.96, color: muted),
  );
}

/// The system bars over the app in [brightness]: transparent, the app's
/// ground showing through, icons in the theme's contrast. Android's
/// contrast scrim (a dark band behind the 3-button navigation) is off: the
/// ground already gives the icons enough contrast.
SystemUiOverlayStyle qoutSystemOverlayStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS: the brightness of the bar's background, not of its icons.
    statusBarBrightness: brightness,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// The theme for [brightness].
ThemeData buildQoutTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? QoutPalette.dark : QoutPalette.light;
  final scheme = _scheme(brightness);
  final text = _textTheme(scheme.onSurface, p.muted);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(QoutRadius.md),
  );
  final edged = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(QoutRadius.md),
    side: BorderSide(color: p.edge),
  );
  // Primary actions are an accent outline with a faint wash, never a fill.
  final primaryAction = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    shape: WidgetStatePropertyAll(shape),
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.transparent
          : p.accentTint,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? p.muted.withValues(alpha: 0.6)
          : p.accentText,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled) ? p.edge : p.accent,
      ),
    ),
    overlayColor: WidgetStatePropertyAll(p.accent.withValues(alpha: 0.12)),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(QoutRadius.md),
    borderSide: BorderSide(color: p.divider),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: qoutFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: p.divider,
    splashFactory: InkSparkle.splashFactory,
    extensions: [p],
    iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) =>
          const Icon(PhosphorIconsRegular.arrowLeft),
      closeButtonIconBuilder: (context) => const Icon(PhosphorIconsRegular.x),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      systemOverlayStyle: qoutSystemOverlayStyle(brightness),
      titleTextStyle: text.titleLarge?.copyWith(
        fontSize: 20,
        letterSpacing: -0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryAction),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryAction),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? p.muted.withValues(alpha: 0.6)
              : scheme.onSurface,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.divider)),
        overlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        foregroundColor: WidgetStatePropertyAll(p.accentText),
        overlayColor: WidgetStatePropertyAll(p.accent.withValues(alpha: 0.1)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.onSurface,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        side: WidgetStatePropertyAll(BorderSide(color: p.divider)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accentTint
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accentText
              : scheme.onSurface,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: edged,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      textColor: scheme.onSurface,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: DividerThemeData(color: p.divider, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: text.bodyMedium?.copyWith(color: p.muted),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: p.accentText),
      hintStyle: text.bodyMedium?.copyWith(color: p.muted),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.3),
      selectionHandleColor: p.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.track,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.surface : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.track,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.transparent : p.edge,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.surface),
      side: BorderSide(color: p.muted, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QoutRadius.sm),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.muted,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.tag,
      labelStyle: text.labelMedium?.copyWith(color: p.onTag),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: p.accent,
      textColor: scheme.surface,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QoutRadius.lg),
        side: BorderSide(color: p.muted.withValues(alpha: 0.5)),
      ),
      titleTextStyle: text.titleMedium?.copyWith(fontSize: 20),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.85),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainer,
      showDragHandle: true,
      dragHandleColor: p.edge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(QoutRadius.lg),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainer,
      contentTextStyle: text.bodyMedium,
      actionTextColor: p.accentText,
      elevation: 0,
      shape: edged,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium,
      shape: edged,
      elevation: 2,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(QoutRadius.sm),
      ),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
  );
}
