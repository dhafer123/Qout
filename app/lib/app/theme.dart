import 'package:flutter/material.dart';

/// Placeholder brand color until the visual identity is defined.
const Color qoutSeedColor = Color(0xFF2E7D32);

/// Material 3 theme for [brightness], generated from [qoutSeedColor].
ThemeData buildQoutTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: qoutSeedColor,
    brightness: brightness,
  ),
);
