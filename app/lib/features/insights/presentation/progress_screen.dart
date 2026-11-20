import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/core/ui/state_message.dart';

/// The Progress tab: the week, from what was logged in the diary.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progress')),
    body: const StateMessage(
      icon: PhosphorIconsRegular.chartLineUp,
      title: 'Your week will show here',
      message:
          'Once you log what you eat, your week appears here: grades, '
          'processing, salt and sugars.',
    ),
  );
}
