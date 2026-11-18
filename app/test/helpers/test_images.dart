import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/features/product/presentation/product_photo.dart';

/// A 1×1 PNG.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAj'
  'CB0C8AAAAASUVORK5CYII=',
);

/// Product photos from memory instead of the network.
Override memoryProductImages() =>
    productImageProvider.overrideWithValue((_) => MemoryImage(onePixelPng));
