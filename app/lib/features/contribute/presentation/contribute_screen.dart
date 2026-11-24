import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/contribute/presentation/contribute_labels.dart';
import 'package:qout/features/contribute/presentation/contribution_controller.dart';
import 'package:qout/features/contribute/presentation/review_form.dart';

/// Adding an unknown product, or the missing values of a known one
/// (`/contribute/:ean`): photos, review, sent.
class ContributeScreen extends ConsumerWidget {
  const ContributeScreen({required this.ean, super.key});

  final String ean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contributionControllerProvider(ean);
    final step = ref.watch(provider.select((s) => s.step));
    final completing = ref.watch(provider.select((s) => s.existing != null));
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
            ContributionStep.photos =>
              completing ? 'Add the nutrition values' : 'Add a product',
            ContributionStep.review => 'Check the values',
            ContributionStep.sent => 'Sent',
            ContributionStep.saved => 'Saved',
          }),
        ),
        body: SafeArea(
          child: Column(
            children: [
              ContributionStepper(step: step),
              Expanded(child: _body(ref, step)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(WidgetRef ref, ContributionStep step) => switch (step) {
    ContributionStep.photos => _PhotosStep(ean: ean),
    ContributionStep.review => ReviewForm(ean: ean),
    ContributionStep.sent => const _Done(),
    ContributionStep.saved => _Done(
      savedReason: ref.watch(
        contributionControllerProvider(ean).select((s) => s.savedReason),
      ),
    ),
  };
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                switch (state.existing) {
                  null => 'Take three photos of the label.',
                  final existing =>
                    '${existing.name ?? 'Barcode $ean'} cannot be graded '
                        'yet: values are missing. Take three photos of the '
                        'label.',
                },
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: QoutPalette.of(context).muted,
                ),
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
                  Text(photoTitle(kind), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(status, style: theme.textTheme.bodySmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => onCapture(PhotoSource.camera),
                        icon: const Icon(PhosphorIconsRegular.camera, size: 20),
                        label: Text(path == null ? 'Camera' : 'Retake'),
                      ),
                      TextButton.icon(
                        onPressed: () => onCapture(PhotoSource.gallery),
                        icon: const Icon(PhosphorIconsRegular.images, size: 20),
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
    final palette = QoutPalette.of(context);
    const size = 72.0;
    final placeholder = Icon(
      PhosphorIconsRegular.cameraPlus,
      color: palette.muted,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: palette.track,
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
                        Icon(PhosphorIconsRegular.image, color: palette.muted),
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

/// After sending: received by the server, or kept on the phone
/// ([savedReason]) for the outbox to send later.
class _Done extends StatelessWidget {
  const _Done({this.savedReason});

  final String? savedReason;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: savedReason == null
          ? PhosphorIconsRegular.checkCircle
          : PhosphorIconsRegular.cloudArrowUp,
      veggie: VeggieFor.thanks,
      title: 'Thank you!',
      message: savedReason == null
          ? 'Sent for review.'
          : '$savedReason Saved on this phone. It will be sent '
                'automatically.',
      actions: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Where the contributor is: Photos, Check, Send, as three short bars.
class ContributionStepper extends StatelessWidget {
  const ContributionStepper({required this.step, super.key});

  final ContributionStep step;

  static const _labels = ['Photos', 'Check', 'Send'];

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final current = switch (step) {
      ContributionStep.photos => 0,
      ContributionStep.review => 1,
      ContributionStep.sent || ContributionStep.saved => 3,
    };
    return Semantics(
      label: current < 3
          ? 'Step ${current + 1} of 3: ${_labels[current]}'
          : 'All steps done',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Row(
          children: [
            for (final (i, label) in _labels.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= current ? palette.accent : palette.track,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: i == current
                            ? Theme.of(context).colorScheme.onSurface
                            : palette.muted,
                        fontWeight: i == current
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
