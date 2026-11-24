import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/home/domain/greeting.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

void main() {
  group('the part of the day', () {
    test('morning from 5, afternoon from 12, evening from 17, night '
        'from 22', () {
      expect(DayPeriod.of(at(24, 4, 59)), DayPeriod.night);
      expect(DayPeriod.of(at(24, 5)), DayPeriod.morning);
      expect(DayPeriod.of(at(24, 11, 59)), DayPeriod.morning);
      expect(DayPeriod.of(at(24, 12)), DayPeriod.afternoon);
      expect(DayPeriod.of(at(24, 17)), DayPeriod.evening);
      expect(DayPeriod.of(at(24, 22)), DayPeriod.night);
      expect(DayPeriod.of(at(24, 0)), DayPeriod.night);
    });
  });

  group('greetingFor', () {
    const morningTitles = {'Good morning, Dhafer', 'Morning, Dhafer'};
    const nightTitles = {'Still up, Dhafer?', 'Hey there, Dhafer'};

    test('follows the time of day', () {
      expect(morningTitles, contains(greetingFor('Dhafer', at(24, 8)).title));
      expect(
        {'Good afternoon, Dhafer', 'Hey, Dhafer'},
        contains(greetingFor('Dhafer', at(24, 14)).title),
      );
      expect(
        {'Good evening, Dhafer', 'Evening, Dhafer'},
        contains(greetingFor('Dhafer', at(24, 19)).title),
      );
      expect(nightTitles, contains(greetingFor('Dhafer', at(24, 23)).title));
    });

    test('without a name, the greeting alone', () {
      final title = greetingFor(null, at(24, 8)).title;
      expect({'Good morning', 'Morning'}, contains(title));
      expect(
        {'Still up?', 'Hey there'},
        contains(greetingFor(null, at(24, 23)).title),
      );
    });

    test('the same all day long (no change on a rebuild)', () {
      final first = greetingFor('Dhafer', at(24, 8));
      for (final minute in [1, 17, 42, 59]) {
        expect(greetingFor('Dhafer', at(24, 9, minute)), first);
      }
      expect(greetingFor('Dhafer', at(24, 11, 59)), first);
    });

    test('a late night keeps the evening day: no switch at midnight', () {
      expect(
        greetingFor('Dhafer', at(25, 1)),
        greetingFor('Dhafer', at(24, 23)),
      );
    });

    test('mixed up from day to day (regression: always "Hello, Dhafer")', () {
      final titles = <String>{};
      final subtitles = <String>{};
      for (var day = 1; day <= 14; day++) {
        final (:title, :subtitle) = greetingFor('Dhafer', at(day, 8));
        titles.add(title);
        subtitles.add(subtitle);
      }
      expect(titles, morningTitles);
      expect(subtitles, hasLength(3));
      expect(titles, isNot(contains('Hello, Dhafer')));
    });
  });
}
