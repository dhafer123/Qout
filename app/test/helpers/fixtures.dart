import 'dart:convert';
import 'dart:io';

import 'package:qout/core/api/qout_api.dart';

/// A recorded API response from `test/fixtures/api/`, as decoded JSON.
Map<String, Object?> recordedProductJson(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync())
        as Map<String, Object?>;

/// A recorded API product response from `test/fixtures/api/`.
ProductDetail recordedProduct(String name) =>
    ProductDetail.fromJson(recordedProductJson(name));
