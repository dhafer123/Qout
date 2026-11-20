/// Weekly insights (T43): the week's diary in a few numbers. Pure Dart, no
/// Flutter imports. Shares are weighted by energy (what was eaten most
/// counts most); targets are the T38 daily needs, no new values.
library;

import 'package:freezed_annotation/freezed_annotation.dart' show immutable;
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/needs.dart';

/// The Monday (local midnight) of the week [day] falls in.
DateTime mondayOf(DateTime day) {
  final d = dayOf(day);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// Nutri-Score grades grouped for the week's picture.
enum GradeGroup {
  ab('A or B'),
  c('C'),
  de('D or E'),

  /// No grade: quick adds, products without one.
  notGraded('Not graded')
  ;

  const GradeGroup(this.label);

  final String label;

  static GradeGroup of(String? letter) => switch (letter) {
    'A' || 'B' => GradeGroup.ab,
    'C' => GradeGroup.c,
    'D' || 'E' => GradeGroup.de,
    _ => GradeGroup.notGraded,
  };
}

/// A product that gave much of a nutrient this week.
@immutable
class TopSource {
  const TopSource({required this.name, required this.grams});

  final String name;
  final double grams;

  @override
  bool operator ==(Object other) =>
      other is TopSource && other.name == name && other.grams == grams;

  @override
  int get hashCode => Object.hash(name, grams);

  @override
  String toString() => 'TopSource($name, $grams g)';
}

@immutable
class WeekInsights {
  const WeekInsights({
    required this.monday,
    required this.energyKjPerDay,
    required this.daysLogged,
    required this.energyShareByGrade,
    required this.nova4Share,
    required this.novaUnknownShare,
    required this.daysAboveSalt,
    required this.daysAboveSugars,
    required this.topSugars,
    required this.topSalt,
  });

  final DateTime monday;

  /// Monday to Sunday, in kJ (0 for a day without entries).
  final List<double> energyKjPerDay;

  /// Days with at least one entry.
  final int daysLogged;

  /// Share of the week's energy per grade group (sums to 1; empty when no
  /// energy was logged).
  final Map<GradeGroup, double> energyShareByGrade;

  /// Share of the week's energy from NOVA group 4 (ultra-processed), and
  /// from entries whose NOVA group isn't known; null when no energy.
  final double? nova4Share;
  final double? novaUnknownShare;

  /// Logged days whose salt / sugars went above the daily reference.
  final int daysAboveSalt;
  final int daysAboveSugars;

  /// Up to three products that gave the most sugars / salt this week.
  final List<TopSource> topSugars;
  final List<TopSource> topSalt;

  bool get isEmpty => daysLogged == 0;

  /// Average energy on the days something was logged (kJ).
  double get averageKjOnLoggedDays => daysLogged == 0
      ? 0
      : energyKjPerDay.fold<double>(0, (a, b) => a + b) / daysLogged;
}

/// The insights for the week starting [monday] from its [entries] (others
/// are ignored), against [needs].
WeekInsights weekInsights(
  Iterable<DiaryEntry> entries,
  DateTime monday,
  DailyNeeds needs,
) {
  final start = dayOf(monday);
  final days = [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
  final byDay = {for (final d in days) d: <DiaryEntry>[]};
  for (final entry in entries) {
    byDay[dayOf(entry.eatenAt)]?.add(entry);
  }
  final week = [for (final d in days) ...byDay[d]!];

  final energyPerDay = [
    for (final d in days) totalsOf(byDay[d]!).of(Nutrient.energy),
  ];
  final logged = [
    for (final d in days)
      if (byDay[d]!.isNotEmpty) d,
  ];

  var totalKj = 0.0;
  var nova4Kj = 0.0;
  var novaUnknownKj = 0.0;
  final byGroup = <GradeGroup, double>{};
  for (final entry in week) {
    final kj = entry.eaten[Nutrient.energy] ?? 0;
    totalKj += kj;
    final group = GradeGroup.of(entry.grade);
    byGroup[group] = (byGroup[group] ?? 0) + kj;
    switch (entry.novaGroup) {
      case 4:
        nova4Kj += kj;
      case null:
        novaUnknownKj += kj;
    }
  }

  int daysAbove(Nutrient nutrient) => logged
      .where(
        (d) => aboveReference(
          nutrient,
          totalsOf(byDay[d]!).of(nutrient),
          dailyAmount(needs, nutrient),
        ),
      )
      .length;

  return WeekInsights(
    monday: start,
    energyKjPerDay: energyPerDay,
    daysLogged: logged.length,
    energyShareByGrade: totalKj <= 0
        ? const {}
        : {
            for (final group in GradeGroup.values)
              if ((byGroup[group] ?? 0) > 0) group: byGroup[group]! / totalKj,
          },
    nova4Share: totalKj <= 0 ? null : nova4Kj / totalKj,
    novaUnknownShare: totalKj <= 0 ? null : novaUnknownKj / totalKj,
    daysAboveSalt: daysAbove(Nutrient.salt),
    daysAboveSugars: daysAbove(Nutrient.sugars),
    topSugars: _top(week, Nutrient.sugars),
    topSalt: _top(week, Nutrient.salt),
  );
}

/// The three products (by barcode, else name) that gave the most of
/// [nutrient]; ties keep the first logged.
List<TopSource> _top(List<DiaryEntry> week, Nutrient nutrient) {
  final grams = <String, double>{};
  final names = <String, String>{};
  for (final entry in week) {
    final value = entry.eaten[nutrient];
    if (value == null || value <= 0) continue;
    final key = entry.ean ?? 'name:${entry.name}';
    grams[key] = (grams[key] ?? 0) + value;
    names[key] ??= entry.name ?? entry.ean ?? 'Unnamed product';
  }
  // Most first; on a tie, the one logged first (sort isn't stable).
  final order = {for (final (i, key) in grams.keys.indexed) key: i};
  final keys = grams.keys.toList()
    ..sort((a, b) {
      final byGrams = grams[b]!.compareTo(grams[a]!);
      return byGrams != 0 ? byGrams : order[a]!.compareTo(order[b]!);
    });
  return [
    for (final key in keys.take(3))
      TopSource(name: names[key]!, grams: grams[key]!),
  ];
}
