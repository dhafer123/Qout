import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';
import 'package:qout/features/settings/presentation/theme_mode_provider.dart';

class QoutApp extends ConsumerWidget {
  const QoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(appEnvProvider);
    return MaterialApp.router(
      title: 'Qout',
      theme: buildQoutTheme(Brightness.light),
      darkTheme: buildQoutTheme(Brightness.dark),
      // System, light or dark, as chosen on the Profile tab (T43b).
      themeMode: ref.watch(themeModeProvider),
      // The debug banner marks non-prod builds.
      debugShowCheckedModeBanner: env.flavor != AppFlavor.prod,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // The navigation bar's look on every screen (app bars set the
        // status bar's).
        value: qoutSystemOverlayStyle(Theme.of(context).brightness),
        // Sends queued contributions and reports while the app runs (T30).
        child: OutboxSyncHost(child: child!),
      ),
    );
  }
}
