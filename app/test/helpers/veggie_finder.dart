import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/ui/veggie.dart';

/// Finds the sticker of [veggie].
Finder findVeggie(Veggie veggie) => find.byWidgetPredicate(
  (widget) => widget is VeggieArt && widget.veggie == veggie,
);
