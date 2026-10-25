import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/validation/validators.dart';

void main() {
  group('personName', () {
    test('accepts letters, spaces, hyphens, apostrophes, periods', () {
      expect(PsValidators.personName('Juan', 'First name'), isNull);
      expect(PsValidators.personName("Dela Cruz-O'Neil Jr.", 'Last name'), isNull);
      expect(PsValidators.personName('Niño', 'First name'), isNull);
    });

    test('rejects empty and digits', () {
      expect(PsValidators.personName('  ', 'First name'), 'First name is required.');
      expect(PsValidators.personName('J0hn', 'First name'), isNotNull);
    });
  });

  test('email', () {
    expect(PsValidators.email('john.doe@gmail.com'), isNull);
    expect(PsValidators.email('a+tag@mail.co.ph'), isNull);
    expect(PsValidators.email('john@'), isNotNull);
    expect(PsValidators.email(''), 'Email is required.');
  });

  test('PH mobile is 10 digits starting with 9', () {
    expect(PsValidators.phMobile('9171234567'), isNull);
    expect(PsValidators.phMobile('8171234567'), isNotNull);
    expect(PsValidators.phMobile('917123456'), isNotNull);
  });

  group('birthDate', () {
    final today = DateTime(2026, 10, 20);

    test('exactly 18 today passes, one day short fails', () {
      expect(PsValidators.birthDate(DateTime(2008, 10, 20), today: today), isNull);
      expect(
        PsValidators.birthDate(DateTime(2008, 10, 21), today: today),
        'You must be at least 18 years old to register.',
      );
    });

    test('future and missing dates fail', () {
      expect(PsValidators.birthDate(DateTime(2027, 1, 1), today: today), isNotNull);
      expect(PsValidators.birthDate(null, today: today), 'Date of birth is required.');
    });
  });

  group('password', () {
    test('needs every rule', () {
      expect(PsValidators.password('Password123'), contains('special character'));
      expect(PsValidators.password('Password123!'), isNull);
    });

    test('checklist rules match the Figma example', () {
      const value = 'Password123';
      final met = PasswordRule.values.where((r) => r.isMetBy(value)).toSet();
      expect(met, {PasswordRule.minLength, PasswordRule.uppercase, PasswordRule.lowercase, PasswordRule.number});
    });

    test('confirmation must match', () {
      expect(PsValidators.confirmPassword('abc', 'abd'), 'Passwords don’t match.');
      expect(PsValidators.confirmPassword('abc', 'abc'), isNull);
    });
  });

  test('otp', () {
    expect(PsValidators.otp('428059'), isNull);
    expect(PsValidators.otp('42805'), isNotNull);
    expect(PsValidators.otp('42805a'), isNotNull);
  });
}
