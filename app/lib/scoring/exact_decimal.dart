import 'package:freezed_annotation/freezed_annotation.dart' show immutable;

/// Exact decimal numbers for threshold comparisons.
///
/// Mirrors the Python engine, which compares `Decimal(repr(value))`: a double
/// is taken as the shortest decimal that round-trips to it (`4.1` is 41/10,
/// not 4.0999...), so a value written on a threshold stays on it.
@immutable
final class ExactDecimal implements Comparable<ExactDecimal> {
  /// `unscaled / 10^scale`, stored without trailing zeros.
  factory ExactDecimal._(BigInt unscaled, int scale) {
    var n = unscaled;
    var s = scale;
    while (s > 0 && n % _ten == BigInt.zero) {
      n ~/= _ten;
      s--;
    }
    return ExactDecimal._raw(n, s);
  }

  const ExactDecimal._raw(this._unscaled, this._scale);

  /// The value `n`.
  factory ExactDecimal.fromInt(int n) => ExactDecimal._(BigInt.from(n), 0);

  /// The shortest decimal that round-trips to [value] (Dart's `toString`).
  factory ExactDecimal.fromDouble(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return ExactDecimal.parse(value.toString());
  }

  /// Parses `-12`, `4.1`, `1e-7`, `2.5E+3`.
  factory ExactDecimal.parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) throw FormatException('not a decimal number', text);
    final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final exponent = int.parse(match.group(4) ?? '0');
    final digits = BigInt.parse('$whole$fraction') * sign;
    final scale = fraction.length - exponent;
    return scale >= 0
        ? ExactDecimal._(digits, scale)
        : ExactDecimal._(digits * _ten.pow(-scale), 0);
  }

  static final _pattern = RegExp(
    r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
  );
  static final _ten = BigInt.from(10);

  /// value = _unscaled / 10^_scale; _unscaled has no trailing zero digit
  /// unless _scale is 0 (so zero is always 0 / 10^0).
  final BigInt _unscaled;
  final int _scale;

  /// This value's and [other]'s unscaled digits at a common scale.
  (BigInt, BigInt, int) _aligned(ExactDecimal other) {
    final scale = _scale > other._scale ? _scale : other._scale;
    return (
      _unscaled * _ten.pow(scale - _scale),
      other._unscaled * _ten.pow(scale - other._scale),
      scale,
    );
  }

  ExactDecimal operator +(ExactDecimal other) {
    final (a, b, scale) = _aligned(other);
    return ExactDecimal._(a + b, scale);
  }

  ExactDecimal operator -(ExactDecimal other) {
    final (a, b, scale) = _aligned(other);
    return ExactDecimal._(a - b, scale);
  }

  ExactDecimal operator *(ExactDecimal other) =>
      ExactDecimal._(_unscaled * other._unscaled, _scale + other._scale);

  bool get isZero => _unscaled == BigInt.zero;

  bool get isNegative => _unscaled.isNegative;

  @override
  int compareTo(ExactDecimal other) {
    final (a, b, _) = _aligned(other);
    return a.compareTo(b);
  }

  bool operator <(ExactDecimal other) => compareTo(other) < 0;
  bool operator <=(ExactDecimal other) => compareTo(other) <= 0;
  bool operator >(ExactDecimal other) => compareTo(other) > 0;
  bool operator >=(ExactDecimal other) => compareTo(other) >= 0;

  /// Rounded to an integer, halves away from zero (Excel `ROUND(x, 0)`).
  int roundHalfAwayFromZero() {
    if (_scale == 0) return _unscaled.toInt();
    final divisor = _ten.pow(_scale);
    final magnitude = _unscaled.abs();
    var whole = magnitude ~/ divisor;
    if ((magnitude % divisor) * BigInt.two >= divisor) whole += BigInt.one;
    return (_unscaled.isNegative ? -whole : whole).toInt();
  }

  /// The nearest double (correctly rounded by `double.parse`).
  double toDouble() => double.parse(toString());

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal &&
      other._unscaled == _unscaled &&
      other._scale == _scale;

  @override
  int get hashCode => Object.hash(_unscaled, _scale);

  @override
  String toString() {
    if (_scale == 0) return _unscaled.toString();
    final digits = _unscaled.abs().toString().padLeft(_scale + 1, '0');
    final point = digits.length - _scale;
    final sign = _unscaled.isNegative ? '-' : '';
    return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
  }
}
