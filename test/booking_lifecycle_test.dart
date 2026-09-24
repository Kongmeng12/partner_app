import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/models/models.dart';
import 'package:partner_app/theme/tokens.dart';

BookingDetail _booking(String status, List<String> nextStatus) =>
    BookingDetail({'status': status, 'nextStatus': nextStatus});

void main() {
  group('front-desk actions follow what the API says is open today', () {
    test('a confirmed booking can be checked in only when the API allows it', () {
      expect(_booking('confirmed', ['staying', 'no_show']).canCheckIn, isTrue);
      // Arrival is still in the future: the API returns no moves at all.
      expect(_booking('confirmed', []).canCheckIn, isFalse);
    });

    test('a staying guest can be checked out, or have the check-in undone', () {
      final b = _booking('staying', ['completed', 'confirmed']);
      expect(b.canCheckOut, isTrue);
      expect(b.canUndoCheckIn, isTrue);
      expect(b.canCheckIn, isFalse);
    });

    test('an unpaid booking offers nothing by hand — payment confirms it', () {
      // An older backend still lists `confirmed` here; it must not become a
      // check-in button or a manual "confirm".
      final b = _booking('pending', ['confirmed']);
      expect(b.awaitingPayment, isTrue);
      expect(b.canCheckIn, isFalse);
      expect(b.canCheckOut, isFalse);
    });

    test('a finished, cancelled or no-show booking has nowhere to go', () {
      for (final s in ['completed', 'cancelled', 'no_show']) {
        final b = _booking(s, []);
        expect(b.canCheckIn || b.canCheckOut || b.canUndoCheckIn, isFalse, reason: s);
      }
    });
  });

  test('every status the API can send has its own Lao label, not the raw word', () {
    for (final s in ['pending', 'confirmed', 'staying', 'completed', 'cancelled', 'no_show']) {
      expect(pillFor(bookingStatusPill, s).label, isNot(s), reason: s);
    }
  });
}
