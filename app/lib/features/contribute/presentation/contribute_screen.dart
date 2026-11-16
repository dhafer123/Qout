import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/contribute/presentation/contribute_labels.dart';
import 'package:qout/features/contribute/presentation/contribution_controller.dart';
import 'package:qout/features/contribute/presentation/review_form.dart';

/// Adding an unknown product (`/contribute/:ean`): photos, review, sent.
class ContributeScreen extends ConsumerWidget {
  const ContributeScreen({required this.ean, super.key});

  final String ean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contributionControllerProvider(ean);
    final step = ref.watch(provider.select((s) => s.step));
    final controller = ref.read(provider.notifier);
    return PopScope(
      // Back from the review goes to the photos, not out of the flow.
      canPop: step != ContributionStep.review,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.toPhotos();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (step) {
            ContributionStep.photos => 'Add a product',
            ContributionStep.review => 'Check the values',
            ContributionStep.sent => 'Sent',
          }),
        ),
        body: SafeArea(
          child: switch (step) {
            ContributionStep.photos => _PhotosStep(ean: ean),
            ContributionStep.review => ReviewForm(ean: ean),
            ContributionStep.sent => const _Sent(),
          },
        ),
      ),
    );
  }
}

class _PhotosStep extends ConsumerWidget {
  const _PhotosStep({required this.ean});

  final String ean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contributionControllerProvider(ean);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Barcode $ean. Take three photos; the values are read from '
                'the nutrition table and you check them next.',
              ),
              const SizedBox(height: 16),
              for (final kind in const [
                PhotoKind.front,
                PhotoKind.nutrition,
                PhotoKind.ingredients,
              ])
                _PhotoTile(
                  kind: kind,
                  path: state.draft.photos[kind],
                  reading: state.readingPhotos.contains(kind),
                  textRead: state.draft.ocrText.containsKey(kind),
                  onCapture: (source) => controller.capture(kind, source),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.hasRequiredPhotos ? controller.toReview : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.kind,
    required this.path,
    required this.reading,
    required this.textRead,
    required this.onCapture,
  });

  final PhotoKind kind;
  final String? path;
  final bool reading;
  final bool textRead;
  final void Function(PhotoSource source) onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = path == null
        ? photoHint(kind)
        : reading
        ? 'Reading the text…'
        : textRead
        ? 'Text read.'
        : 'No text found on this photo.';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Thumbnail(path: path, reading: reading),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(photoTitle(kind), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(status, style: theme.textTheme.bodySmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => onCapture(PhotoSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(path == null ? 'Camera' : 'Retake'),
                      ),
                      TextButton.icon(
                        onPressed: () => onCapture(PhotoSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.reading});

  final String? path;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 72.0;
    final placeholder = Icon(
      Icons.add_a_photo_outlined,
      color: scheme.onSurfaceVariant,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: path == null
            ? placeholder
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(path!),
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.image_outlined, color: scheme.primary),
                  ),
                  if (reading)
                    const Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Thank you!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Your product is waiting for review. It appears in the app once '
              'a moderator has checked it against your photos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
