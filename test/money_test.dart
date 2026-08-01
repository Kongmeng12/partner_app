import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/money.dart';

/// The expected values are taken from `webadmin/src/lib/format.ts`. The two
/// clients show the same booking to the same people, so a partner and an admin
/// reading the same number must see the same string.
void main() {
  group('kip', () {
    test('groups thousands the way the admin panel does', () {
      expect(kip(1350000), '₭1,350,000');
      expect(kip(450000), '₭450,000');
      expect(kip(999), '₭999');
      expect(kip(0), '₭0');
    });

    test('renders a null amount as an em dash, not as zero', () {
      // Zero kip and "we do not know" are different facts.
      expect(kip(null), '—');
      expect(kipShort(null), '—');
    });

    test('handles negatives', () {
      expect(kip(-1234567), '₭-1,234,567');
    });
  });

  group('kipShort', () {
    test('abbreviates millions and thousands', () {
      expect(kipShort(18400000), '₭18.4M');
      expect(kipShort(628000), '₭628K');
      expect(kipShort(1000000), '₭1M');
      expect(kipShort(950), '₭950');
    });

    test('drops a trailing .0 rather than showing 12.0M', () {
      expect(kipShort(12000000), '₭12M');
    });
  });

  group('stars and initials', () {
    test('stars fills and pads to five', () {
      expect(stars(5), '★★★★★');
      expect(stars(3), '★★★☆☆');
      expect(stars(0), '☆☆☆☆☆');
      // Out-of-range input must not produce a ragged string.
      expect(stars(9), '★★★★★');
      expect(stars(-2), '☆☆☆☆☆');
    });

    test('initials takes the last name part, including Lao script', () {
      expect(initials('John Carter'), 'C');
      expect(initials('ນາງ ສຸດາ ວົງສາ'), 'ວ');
      expect(initials('  '), '?');
    });
  });

  group('deltaLabel', () {
    test('marks direction and reports no comparison when null', () {
      expect(deltaLabel(12).up, isTrue);
      expect(deltaLabel(-4).up, isFalse);
      expect(deltaLabel(0).up, isNull);
      expect(deltaLabel(null).text, contains('ບໍ່ມີຂໍ້ມູນ'));
    });
  });
}
