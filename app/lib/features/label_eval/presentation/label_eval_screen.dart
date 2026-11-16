import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/label_eval/presentation/label_eval_controller.dart';

/// Dev builds only: photographs nutrition labels for the parser evaluation
/// set (`eval/labels/README.md`) and shows what ML Kit read.
class LabelEvalScreen extends ConsumerWidget {
  const LabelEvalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelEvalControllerProvider);
    final controller = ref.read(labelEvalControllerProvider.notifier);
    final working = state is LabelEvalWorking;
    return Scaffold(
      appBar: AppBar(title: const Text('Label OCR (dev)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Photograph a nutrition table as a user would: phone straight, '
            'table filling the frame, no glare. Take each label once. The '
            'text ML Kit reads is saved with the photo for the parser '
            'evaluation.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: working
                    ? null
                    : () => unawaited(controller.capture(PhotoSource.camera)),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: working
                    ? null
                    : () => unawaited(controller.capture(PhotoSource.gallery)),
                icon: const Icon(Icons.photo_library),
                label: const Text('From gallery'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          switch (state) {
            LabelEvalIdle() => const SizedBox.shrink(),
            LabelEvalWorking() => const Center(
              child: CircularProgressIndicator(),
            ),
            LabelEvalFailed(:final message) => Text(
              'Not saved: $message',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            LabelEvalSaved(:final label) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved as ${label.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'Folder: ${label.directory}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (label.ocrText.trim().isEmpty)
                  const Text('ML Kit read no text in this photo.')
                else
                  SelectableText(
                    label.ocrText,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
