import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/theme.dart';

/// Builds the image for a product photo URL. The URL points at Qout's own
/// storage (the backend copies Open Food Facts' photo; the app never calls
/// OFF). Overridden in tests, which never use the network.
final Provider<ImageProvider Function(String url)> productImageProvider =
    Provider<ImageProvider Function(String url)>(
      (ref) => NetworkImage.new,
    );

/// The product's front photo across the top of the result. Shows nothing
/// when there is no photo, stripes while it loads, and hides itself if it
/// can't be loaded (e.g. offline): the photo is a nice-to-have, never an
/// error.
class ProductPhoto extends ConsumerWidget {
  const ProductPhoto({required this.imageUrl, this.name, super.key});

  /// Height of the photo area.
  static const double height = 200;

  final String? imageUrl;

  /// Product name, for screen readers.
  final String? name;

  /// Marks the empty space left by a photo that could not be loaded.
  static const Key unavailableKey = ValueKey('product-photo-unavailable');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final image = ref.watch(productImageProvider)(url);
    final palette = QoutPalette.of(context);
    return Image(
      image: image,
      height: height,
      width: double.infinity,
      fit: BoxFit.contain,
      semanticLabel: name == null ? 'Product photo' : 'Photo of $name',
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return ColoredBox(color: palette.photoStripeA, child: child);
        }
        return const SizedBox(
          height: height,
          width: double.infinity,
          child: PhotoStripes(),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          const SizedBox.shrink(key: unavailableKey),
    );
  }
}

/// A small square photo for list rows; stripes while loading or when it
/// can't be loaded, so the row keeps its shape.
class ProductThumbnail extends ConsumerWidget {
  const ProductThumbnail({required this.url, this.size = 44, super.key});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(productImageProvider)(url);
    final palette = QoutPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(QoutRadius.md),
      child: SizedBox.square(
        dimension: size,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              wasSynchronouslyLoaded || frame != null
              ? ColoredBox(color: palette.photoStripeA, child: child)
              : const PhotoStripes(),
          errorBuilder: (context, error, stackTrace) => const PhotoStripes(),
        ),
      ),
    );
  }
}

/// Diagonal stripes standing in for a photo.
class PhotoStripes extends StatelessWidget {
  const PhotoStripes({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    return CustomPaint(
      painter: _StripesPainter(palette.photoStripeA, palette.photoStripeB),
      child: const SizedBox.expand(),
    );
  }
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter(this.base, this.stripe);

  final Color base;
  final Color stripe;

  static const double _band = 8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..clipRect(Offset.zero & size)
      ..drawColor(base, BlendMode.src);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = _band;
    // 45° lines every two bands, covering the whole box.
    for (var x = -size.height; x < size.width; x += 2 * _band) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) =>
      old.base != base || old.stripe != stripe;
}
