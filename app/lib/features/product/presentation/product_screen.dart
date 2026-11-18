import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/ui/fading_rule.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/product_labels.dart';
import 'package:qout/features/product/presentation/product_photo.dart';
import 'package:qout/features/product/presentation/product_providers.dart';
import 'package:qout/features/product/presentation/product_sections.dart';
import 'package:qout/features/product/presentation/report_error_sheet.dart';

/// The result of a scan: the product with its score explained, or why there
/// is none.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({required this.ean, super.key});

  final String ean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(productResultProvider(ean));
    void retry() => ref.invalidate(productResultProvider(ean));
    final found = switch (result.valueOrNull) {
      final ProductFound found => found,
      _ => null,
    };
    final refreshing = found?.freshness == ProductFreshness.refreshing;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (found != null)
            IconButton(
              tooltip: 'Report an error',
              icon: const Icon(PhosphorIconsRegular.flag),
              onPressed: () => _report(context, found.product),
            ),
          const SizedBox(width: 4),
        ],
        bottom: refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Checking for updates',
                ),
              )
            : null,
      ),
      body: result.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Something went wrong',
          message: 'The product could not be shown.',
          actions: [
            FilledButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
        data: (result) => switch (result) {
          final ProductFound found => _ProductView(found),
          ProductNotFound(:final ean) => _NotFound(ean: ean),
          InvalidBarcode(:final ean, :final message) => StateMessage(
            icon: PhosphorIconsRegular.barcode,
            title: 'This barcode is not valid',
            message: '$ean: $message',
            actions: const [_ScanAgainButton(primary: true)],
          ),
          final ProductUnavailable unavailable => StateMessage(
            icon: unavailable.isOffline
                ? PhosphorIconsRegular.wifiSlash
                : PhosphorIconsRegular.cloudSlash,
            title: unavailable.isOffline
                ? 'You are offline'
                : 'Qout is unavailable right now',
            message: unavailable.isOffline
                ? 'This product is not saved on your phone yet. Connect to '
                      'the internet and try again.'
                : switch (unavailable.retryAfter) {
                    final wait? => 'Try again in ${wait.inSeconds} seconds.',
                    null => 'Try again in a moment.',
                  },
            actions: [
              FilledButton(onPressed: retry, child: const Text('Retry')),
            ],
          ),
        },
      ),
    );
  }
}

void _report(BuildContext context, ProductDetail product) =>
    showReportErrorSheet(
      context,
      ean: product.ean,
      productUpdatedAt: product.updatedAt,
    );

class _ProductView extends StatelessWidget {
  const _ProductView(this.found);

  final ProductFound found;

  @override
  Widget build(BuildContext context) {
    final product = found.product;
    final explanation = explainScore(product);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (found.freshness == ProductFreshness.refreshFailed)
          _StaleBanner(found),
        ProductPhoto(imageUrl: product.imageUrl, name: product.name),
        ProductHeader(product: product),
        GradeCard(explanation: explanation),
        ScoreSection(explanation: explanation, nutrition: product.nutrition),
        AlternativesSection(
          ean: product.ean,
          grade: explanation.displayGrade,
        ),
        NutritionSection(nutrition: product.nutrition),
        ProcessingSection(novaGroup: product.novaGroup),
        AdditivesSection(additives: product.additives),
        SourceSection(product: product),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: FadingRule(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => _report(context, product),
                icon: const Icon(PhosphorIconsRegular.flag, size: 20),
                label: const Text('Report an error'),
              ),
              const SizedBox(height: 8),
              const _ScanAgainButton(),
            ],
          ),
        ),
      ],
    );
  }
}

/// A cached product whose refresh failed.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner(this.found);

  final ProductFound found;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final why = found.refreshError is ApiConnectionError
        ? 'You are offline.'
        : 'Qout could not be reached.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.cloudSlash, color: palette.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$why Showing the version saved on '
                  '${formatDateTime(context, found.fetchedAt)}.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends ConsumerWidget {
  const _NotFound({required this.ean});

  final String ean;

  /// Adding a product needs an account: sign in first if needed.
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final state = await ref.read(authRepositoryProvider).current();
    if (state is! SignedIn) {
      if (!context.mounted) return;
      final signedIn = await context.push<bool>(
        AppRoutes.signIn,
        extra: 'Sign in to add products. Scanning works without an account.',
      );
      if (signedIn != true) return;
    }
    if (context.mounted) unawaited(context.push(AppRoutes.contribute(ean)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StateMessage(
      icon: PhosphorIconsRegular.magnifyingGlass,
      title: 'We do not know this product yet',
      message:
          'Barcode $ean. You can help by adding it from photos of its '
          'label.',
      actions: [
        FilledButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(PhosphorIconsRegular.cameraPlus, size: 20),
          label: const Text('Add this product'),
        ),
        const _ScanAgainButton(),
      ],
    );
  }
}

class _ScanAgainButton extends StatelessWidget {
  const _ScanAgainButton({this.primary = false});

  final bool primary;

  @override
  Widget build(BuildContext context) {
    void scan() => context.pushReplacement(AppRoutes.scan);
    const label = Text('Scan another barcode');
    return primary
        ? FilledButton(onPressed: scan, child: label)
        : TextButton(onPressed: scan, child: label);
  }
}
