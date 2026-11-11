import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/env/app_env.dart';

extension PumpQoutApp on WidgetTester {
  /// Pumps the full app with a fixed [AppEnv] (no build flavor in tests).
  Future<void> pumpQoutApp({AppFlavor flavor = AppFlavor.dev}) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            AppEnv.resolve(flavorName: flavor.name),
          ),
        ],
        child: const QoutApp(),
      ),
    );
    await pumpAndSettle();
  }
}
