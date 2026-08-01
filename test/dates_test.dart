import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/dates.dart';

/// The date bug the backend README calls out as "ເຄີຍພາດມາແລ້ວ", guarded from
/// the client side.
///
/// PostgreSQL `date` columns arrive as UTC midnight. Lao time is UTC+7, so
/// reading `2026-08-13T00:00:00.000Z` with local getters on a machine east of
/// Greenwich still gives the 13th — but on a machine *west* of it gives the
/// 12th. These tests pin the UTC reading so the check-in date a partner sees is
/// the one the guest booked, wherever the phone happens to be.
void main() {
  group('date-only values', () {
    test('are recognised by their UTC-midnight suffix', () {
      expect(isDateOnly('2026-08-13T00:00:00.000Z'), isTrue);
      expect(isDateOnly('2026-08-13T00:00:00Z'), isTrue);
      // A real timestamp that merely happens to land on midnight local time.
      expect(isDateOnly('2026-08-13T00:00:00.000+07:00'), isFalse);
      expect(isDateOnly('2026-08-13T14:30:00.000Z'), isFalse);
    });

    test('keep their calendar day regardless of the device timezone', () {
      final day = parseDay('2026-08-13T00:00:00.000Z');
      expect(day!.year, 2026);
      expect(day.month, 8);
      expect(day.day, 13);
      expect(day.isUtc, isTrue);
    });

    test('format as the day the guest booked', () {
      expect(laoDate('2026-08-13T00:00:00.000Z'), '13 ສ.ຫ.');
      expect(laoDate('2026-01-01T00:00:00.000Z'), '1 ມ.ກ.');
      expect(laoDate(null), '—');
      expect(laoDate('not a date'), '—');
    });
  });

  group('laoDateRange', () {
    test('collapses the month when both ends share it', () {
      expect(
        laoDateRange('2026-07-12T00:00:00.000Z', '2026-07-15T00:00:00.000Z'),
        '12–15 ກ.ຄ.',
      );
    });

    test('spells both months when the stay crosses one', () {
      expect(
        laoDateRange('2026-07-30T00:00:00.000Z', '2026-08-02T00:00:00.000Z'),
        '30 ກ.ຄ. – 2 ສ.ຫ.',
      );
    });

    test('is an em dash when either end is missing', () {
      expect(laoDateRange(null, '2026-08-02T00:00:00.000Z'), '—');
    });
  });

  group('nightsBetween', () {
    test('does not charge the check-out day', () {
      expect(
        nightsBetween('2026-08-13T00:00:00.000Z', '2026-08-16T00:00:00.000Z'),
        3,
      );
    });

    test('counts a single night', () {
      expect(
        nightsBetween('2026-08-13T00:00:00.000Z', '2026-08-14T00:00:00.000Z'),
        1,
      );
    });
  });

  group('apiDay', () {
    test('renders the form every query parameter takes', () {
      expect(apiDay(DateTime.utc(2026, 8, 3)), '2026-08-03');
      expect(apiDay(DateTime.utc(2026, 12, 25)), '2026-12-25');
    });

    test('normalises a local DateTime to its calendar day', () {
      // What a date picker hands back: local midnight. It must not shift.
      expect(apiDay(DateTime(2026, 8, 3)), '2026-08-03');
    });
  });

  group('addDays', () {
    test('crosses month and year boundaries', () {
      expect(apiDay(addDays(DateTime.utc(2026, 8, 30), 3)), '2026-09-02');
      expect(apiDay(addDays(DateTime.utc(2026, 12, 31), 1)), '2027-01-01');
      expect(apiDay(addDays(DateTime.utc(2026, 3, 1), -1)), '2026-02-28');
    });
  });
}
