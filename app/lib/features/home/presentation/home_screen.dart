import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Qout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan a food barcode to see its nutrition score.',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.scan),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
