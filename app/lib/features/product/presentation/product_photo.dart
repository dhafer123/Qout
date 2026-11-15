import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the image for a product photo URL. The URL points at Qout's own
/// storage (the backend copies Open Food Facts' photo; the app never calls
/// OFF). Overridden in tests, which never use the network.
final Provider<ImageProvider Function(String url)> productImageProvider =
    Provider<ImageProvider Function(String url)>(
      (ref) => NetworkImage.new,
    );

/// The product's front photo, above its name. Shows nothing when there is
/// no photo, and hides itself if the photo can't be loaded (e.g. offline):
/// the photo is a nice-to-have, never an error.
class ProductPhoto extends ConsumerWidget {
  const ProductPhoto({required this.imageUrl, this.name, super.key});

  /// Height of the photo area.
  static const double height = 180;

  final String? imageUrl;

  /// Product name, for screen readers.
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final image = ref.watch(productImageProvider)(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: image,
            height: height,
            fit: BoxFit.contain,
            semanticLabel: name == null ? 'Product photo' : 'Photo of $name',
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return const SizedBox(height: height);
            },
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(key: ProductPhoto.unavailableKey),
          ),
        ),
      ),
    );
  }

  /// Marks the empty space left by a photo that could not be loaded.
  static const Key unavailableKey = ValueKey('product-photo-unavailable');
}
