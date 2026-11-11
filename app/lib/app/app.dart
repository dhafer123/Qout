import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/env/app_env.dart';

class QoutApp extends ConsumerWidget {
  const QoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(appEnvProvider);
    return MaterialApp.router(
      title: 'Qout',
      theme: buildQoutTheme(Brightness.light),
      darkTheme: buildQoutTheme(Brightness.dark),
      // The debug banner marks non-prod builds.
      debugShowCheckedModeBanner: env.flavor != AppFlavor.prod,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
