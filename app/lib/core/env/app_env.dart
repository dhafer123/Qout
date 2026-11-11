import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_env.freezed.dart';

/// Build flavors. Names must match `productFlavors` in
/// `android/app/build.gradle.kts`.
enum AppFlavor {
  dev,
  staging,
  prod
  ;

  /// Parses a flavor name, failing loudly instead of guessing.
  static AppFlavor parse(String? name) {
    for (final flavor in values) {
      if (flavor.name == name) return flavor;
    }
    throw UnsupportedFlavorException(name);
  }
}

/// Default API base URL per flavor.
///
/// `dev` targets the backend on the host machine as seen from the Android
/// emulator. Staging and prod hosts don't exist yet: `.invalid` placeholders
/// until deployment (see TASKS.md, T32).
const Map<AppFlavor, String> defaultApiBaseUrls = {
  AppFlavor.dev: 'http://10.0.2.2:8000',
  AppFlavor.staging: 'https://api.staging.qout.invalid',
  AppFlavor.prod: 'https://api.qout.invalid',
};

/// Runtime environment of the app, fixed for the lifetime of the process.
@freezed
abstract class AppEnv with _$AppEnv {
  const factory AppEnv({
    required AppFlavor flavor,
    required Uri apiBaseUrl,
  }) = _AppEnv;

  /// Resolves the environment for [flavorName].
  ///
  /// A non-empty [apiBaseUrlOverride] (e.g. `--dart-define=API_BASE_URL=...`,
  /// needed on a physical device) replaces the flavor's default URL.
  factory AppEnv.resolve({
    required String? flavorName,
    String? apiBaseUrlOverride,
  }) {
    final flavor = AppFlavor.parse(flavorName);
    final rawUrl = (apiBaseUrlOverride == null || apiBaseUrlOverride.isEmpty)
        ? defaultApiBaseUrls[flavor]!
        : apiBaseUrlOverride;
    return AppEnv(flavor: flavor, apiBaseUrl: _parseHttpUrl(rawUrl));
  }

  /// Resolves the environment from the build: `--flavor` and the optional
  /// `API_BASE_URL` dart-define.
  factory AppEnv.fromBuild() => AppEnv.resolve(
    flavorName: appFlavor,
    apiBaseUrlOverride: const String.fromEnvironment('API_BASE_URL'),
  );
}

Uri _parseHttpUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    throw FormatException('API base URL must be an absolute http(s) URL', raw);
  }
  return uri;
}

/// Thrown when the app runs with a missing or unknown build flavor.
class UnsupportedFlavorException implements Exception {
  const UnsupportedFlavorException(this.name);

  final String? name;

  @override
  String toString() =>
      'UnsupportedFlavorException: unknown flavor "$name". '
      'Run with --flavor ${AppFlavor.values.map((f) => f.name).join('|')}.';
}

/// The resolved [AppEnv]. Overridden in `main()` (and in tests), so a missing
/// override is a programming error.
final appEnvProvider = Provider<AppEnv>(
  (ref) => throw UnimplementedError('appEnvProvider must be overridden'),
);
