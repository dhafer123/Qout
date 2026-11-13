import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/product_labels.dart';
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
    final refreshing = switch (result.valueOrNull) {
      ProductFound(freshness: ProductFreshness.refreshing) => true,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
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
        error: (_, _) => _Message(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: 'The product could not be shown.',
          action: FilledButton(onPressed: retry, child: const Text('Retry')),
        ),
        data: (result) => switch (result) {
          final ProductFound found => _ProductView(found),
          ProductNotFound(:final ean) => _NotFound(ean: ean),
          InvalidBarcode(:final ean, :final message) => _Message(
            icon: Icons.qr_code_2,
            title: 'This barcode is not valid',
            message: '$ean: $message',
            action: const _ScanAgainButton(filled: true),
          ),
          final ProductUnavailable unavailable => _Message(
            icon: unavailable.isOffline ? Icons.cloud_off : Icons.dns_outlined,
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
            action: FilledButton(onPressed: retry, child: const Text('Retry')),
          ),
        },
      ),
    );
  }
}

class _ProductView extends StatelessWidget {
  const _ProductView(this.found);

  final ProductFound found;

  @override
  Widget build(BuildContext context) {
    final product = found.product;
    final explanation = explainScore(product);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (found.freshness == ProductFreshness.refreshFailed)
          _StaleBanner(found),
        ProductHeader(product: product, explanation: explanation),
        ScoreSection(explanation: explanation),
        AlternativesSection(
          ean: product.ean,
          grade: explanation.displayGrade,
        ),
        NutritionSection(nutrition: product.nutrition),
        ProcessingSection(novaGroup: product.novaGroup),
        AdditivesSection(additives: product.additives),
        SourceSection(product: product),
        OutlinedButton.icon(
          onPressed: () => showReportErrorSheet(
            context,
            ean: product.ean,
            productUpdatedAt: product.updatedAt,
          ),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Report an error'),
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
    final colors = Theme.of(context).colorScheme;
    final why = found.refreshError is ApiConnectionError
        ? 'You are offline.'
        : 'Qout could not be reached.';
    return Card(
      color: colors.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Icons.cloud_off, color: colors.onSecondaryContainer),
        title: Text(
          '$why Showing the version saved on '
          '${formatDateTime(context, found.fetchedAt)}.',
          style: TextStyle(color: colors.onSecondaryContainer),
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
    final messenger = ScaffoldMessenger.of(context);
    final state = await ref.read(authRepositoryProvider).current();
    if (state is! SignedIn) {
      if (!context.mounted) return;
      final signedIn = await context.push<bool>(
        AppRoutes.signIn,
        extra: 'Sign in to add products. Scanning works without an account.',
      );
      if (signedIn != true) return;
    }
    // The contribution flow comes in T29.
    messenger.showSnackBar(
      const SnackBar(content: Text('Adding products is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Message(
      icon: Icons.search_off,
      title: 'We do not know this product yet',
      message:
          'Barcode $ean. You can help by adding it from photos of its '
          'label.',
      action: Column(
        children: [
          FilledButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add this product'),
          ),
          const SizedBox(height: 8),
          const _ScanAgainButton(),
        ],
      ),
    );
  }
}

class _ScanAgainButton extends StatelessWidget {
  const _ScanAgainButton({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    void scan() => context.pushReplacement(AppRoutes.scan);
    const label = Text('Scan another barcode');
    return filled
        ? FilledButton(onPressed: scan, child: label)
        : TextButton(onPressed: scan, child: label);
  }
}

/// A centred icon, title, explanation and action.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            action,
          ],
        ),
      ),
    );
  }
}
