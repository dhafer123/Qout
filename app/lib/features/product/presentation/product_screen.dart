import 'package:flutter/material.dart';

/// Placeholder destination of a scan: shows the barcode. The result screen
/// (score, breakdown, nutrients) replaces it in T20.
class ProductScreen extends StatelessWidget {
  const ProductScreen({required this.ean, super.key});

  final String ean;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barcode', style: textTheme.labelLarge),
              SelectableText(ean, style: textTheme.headlineSmall),
              const SizedBox(height: 16),
              const Text(
                'Product details are coming soon.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
