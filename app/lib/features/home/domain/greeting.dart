/// The Today header's greeting: by the time of day, varied from day to day
/// (the same all day, so it doesn't change on every rebuild), with the first
/// name when there is one.
({String title, String subtitle}) greetingFor(String? firstName, DateTime now) {
  final period = DayPeriod.of(now);
  final (titles, subtitles) = _lines[period]!;
  final day = _dayNumber(now);
  // Titles and subtitles turn over at different rates, so pairs mix too.
  final title = titles[day % titles.length];
  final subtitle = subtitles[(day ~/ titles.length) % subtitles.length];
  return (title: title(firstName), subtitle: subtitle);
}

/// The parts of the day the greeting follows.
enum DayPeriod {
  /// 5:00 to 11:59.
  morning,

  /// 12:00 to 16:59.
  afternoon,

  /// 17:00 to 21:59.
  evening,

  /// 22:00 to 4:59.
  night
  ;

  static DayPeriod of(DateTime now) => switch (now.hour) {
    >= 5 && < 12 => morning,
    >= 12 && < 17 => afternoon,
    >= 17 && < 22 => evening,
    _ => night,
  };
}

/// Days since a fixed date, for the day-to-day variety. Night after midnight
/// counts as the evening's day, so a late session doesn't switch greeting at
/// 00:00.
int _dayNumber(DateTime now) {
  final shifted = now.hour < 5 ? now.subtract(const Duration(hours: 5)) : now;
  return DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day,
  ).difference(DateTime.utc(2026)).inDays.abs();
}

String Function(String?) _hello(String words, {String end = ''}) =>
    (name) => name == null ? '$words$end' : '$words, $name$end';

final Map<DayPeriod, (List<String Function(String?)>, List<String>)> _lines = {
  DayPeriod.morning: (
    [_hello('Good morning'), _hello('Morning')],
    ["What's for breakfast?", 'Start the day well.', 'Ready for breakfast?'],
  ),
  DayPeriod.afternoon: (
    [_hello('Good afternoon'), _hello('Hey')],
    ["What's for lunch?", "How's your day going?", 'Time for a snack?'],
  ),
  DayPeriod.evening: (
    [_hello('Good evening'), _hello('Evening')],
    ["What's for dinner?", 'How did today go?', 'Winding down?'],
  ),
  DayPeriod.night: (
    [_hello('Still up', end: '?'), _hello('Hey there')],
    ['A late snack?', 'Rest well.', 'Log it before you sleep.'],
  ),
};
