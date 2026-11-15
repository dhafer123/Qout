import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/product/presentation/product_photo.dart';

const _url = 'https://media.qout.example/products/619/front-0123456789.jpg';

/// A 1×1 transparent PNG.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAj'
  'CB0C8AAAAASUVORK5CYII=',
);

/// An image that fails to load, like a photo requested while offline.
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('offline')),
  );
}

void main() {
  late List<String> requested;

  Future<void> pumpPhoto(
    WidgetTester tester, {
    required String? imageUrl,
    String? name = 'Harissa',
    ImageProvider Function(String url)? images,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productImageProvider.overrideWithValue((url) {
            requested.add(url);
            return images?.call(url) ?? MemoryImage(_pixel);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ProductPhoto(imageUrl: imageUrl, name: name),
                const Text('Header'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => requested = []);

  testWidgets('no photo: nothing shown, nothing requested', (tester) async {
    await pumpPhoto(tester, imageUrl: null);

    expect(find.byType(Image), findsNothing);
    expect(requested, isEmpty);
    expect(find.text('Header'), findsOneWidget);
  });

  testWidgets('empty URL is no photo', (tester) async {
    await pumpPhoto(tester, imageUrl: '');

    expect(find.byType(Image), findsNothing);
    expect(requested, isEmpty);
  });

  testWidgets('photo from our storage, labelled for screen readers', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pumpPhoto(tester, imageUrl: _url);
      await precacheImage(
        MemoryImage(_pixel),
        tester.element(find.byType(ProductPhoto)),
      );
    });
    await tester.pump();

    expect(requested, [_url]);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
    expect(image.height, ProductPhoto.height);
    expect(image.semanticLabel, 'Photo of Harissa');
    expect(find.byKey(ProductPhoto.unavailableKey), findsNothing);
  });

  testWidgets('unnamed product gets a generic label', (tester) async {
    await pumpPhoto(tester, imageUrl: _url, name: null);

    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Product photo',
    );
  });

  testWidgets('space is kept while the photo loads', (tester) async {
    final pending = Completer<ImageInfo>();
    addTearDown(() async {
      final image = await tester.runAsync(
        () => decodeImageFromList(_pixel),
      );
      pending.complete(ImageInfo(image: image!));
    });
    await pumpPhoto(
      tester,
      imageUrl: _url,
      images: (_) => _PendingImage(pending.future),
    );

    final placeholder = find.descendant(
      of: find.byType(Image),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(placeholder.first).height, ProductPhoto.height);
  });

  testWidgets('a photo that fails to load is hidden, not an error', (
    tester,
  ) async {
    await pumpPhoto(
      tester,
      imageUrl: _url,
      images: (_) => const _FailingImage(),
    );
    await tester.pump();

    expect(find.byKey(ProductPhoto.unavailableKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Header'), findsOneWidget);
  });

  test('the app loads photos over the network by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final image = container.read(productImageProvider)(_url);

    expect(image, isA<NetworkImage>());
    expect((image as NetworkImage).url, _url);
  });
}

/// An image that loads when [image] completes.
class _PendingImage extends ImageProvider<_PendingImage> {
  _PendingImage(this.image);

  final Future<ImageInfo> image;

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(image);
}
