import 'package:flutter_test/flutter_test.dart';
import 'package:xirfadle_app/core/utils/formatters.dart';
import 'package:xirfadle_app/core/utils/validators.dart';

void main() {
  group('normalisePhone', () {
    test('expands a local number to E.164', () {
      expect(normalisePhone('0611234567'), '+252611234567');
      expect(normalisePhone('611234567'), '+252611234567');
    });

    test('keeps an already international number', () {
      expect(normalisePhone('+252611234567'), '+252611234567');
      expect(normalisePhone('00252611234567'), '+252611234567');
    });

    test('strips separators', () {
      expect(normalisePhone('061 123-4567'), '+252611234567');
    });
  });

  group('formatRelative', () {
    test('reports minutes and hours for recent timestamps', () {
      final now = DateTime.now();
      expect(formatRelative(now.subtract(const Duration(seconds: 20))),
          'Just now');
      expect(formatRelative(now.subtract(const Duration(minutes: 42))),
          '42m ago');
      expect(formatRelative(now.subtract(const Duration(hours: 5))), '5h ago');
      expect(formatRelative(now.subtract(const Duration(days: 3))), '3d ago');
    });

    test('handles a null date', () {
      expect(formatRelative(null), '—');
      expect(formatDate(null), '—');
      expect(formatDateTime(null), '—');
    });
  });

  group('Validators', () {
    test('phone requires at least seven digits', () {
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.phone('0611234567'), isNull);
    });

    test('password requires six characters', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('minLength reports the field name', () {
      expect(Validators.minLength('hi', 10, 'Description'),
          'Description must be at least 10 characters');
      expect(Validators.minLength('   ', 10, 'Description'),
          'Description is required');
    });
  });
}
