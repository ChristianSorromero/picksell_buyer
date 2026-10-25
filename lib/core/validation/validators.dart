/// Client-side validation that mirrors the Laravel rules in
/// MobileAuthController so users see the same message before and after
/// a round trip. The server stays the source of truth.
class PsValidators {
  PsValidators._();

  static final RegExp _name = RegExp(r"^[\p{L}\s.'-]+$", unicode: true);
  static final RegExp _email = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)*\.[A-Za-z]{2,}$');

  /// Ten digits after +63, starting with 9 (e.g. 917 123 4567).
  static final RegExp _phMobile = RegExp(r'^9\d{9}$');

  static const int minimumAge = 18;

  static String? requiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  static String? personName(String? value, String fieldName) {
    final missing = requiredText(value, fieldName);
    if (missing != null) return missing;
    final v = value!.trim();
    if (v.length > 100) return '$fieldName is too long.';
    if (!_name.hasMatch(v)) return 'Use letters, spaces, hyphens or apostrophes only.';
    return null;
  }

  static String? email(String? value) {
    final missing = requiredText(value, 'Email');
    if (missing != null) return missing;
    if (!_email.hasMatch(value!.trim())) return 'Enter a valid email address.';
    return null;
  }

  /// [digits] is the national number without +63 or spaces.
  static String? phMobile(String? digits) {
    if (digits == null || digits.isEmpty) return 'Mobile number is required.';
    if (!_phMobile.hasMatch(digits)) {
      return 'Enter a valid PH mobile number (e.g. 917 123 4567).';
    }
    return null;
  }

  static String? birthDate(DateTime? value, {DateTime? today}) {
    if (value == null) return 'Date of birth is required.';
    final now = today ?? DateTime.now();
    if (value.isAfter(now)) return 'Date of birth can’t be in the future.';
    if (value.year < 1900) return 'Enter a valid date of birth.';
    if (ageOn(value, now) < minimumAge) {
      return 'You must be at least $minimumAge years old to register.';
    }
    return null;
  }

  static int ageOn(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    final unmet = PasswordRule.values.where((r) => !r.isMetBy(value));
    if (unmet.isNotEmpty) return 'Password must include: ${unmet.first.label.toLowerCase()}.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != password) return 'Passwords don’t match.';
    return null;
  }

  static String? otp(String value, {int length = 6}) {
    if (value.length != length || int.tryParse(value) == null) {
      return 'Enter the $length-digit code from your email.';
    }
    return null;
  }
}

/// Password checklist shown under the Password field (Figma step 3).
enum PasswordRule {
  minLength('At least 8 characters'),
  uppercase('One uppercase letter'),
  lowercase('One lowercase letter'),
  number('One number'),
  special('One special character (!@#\$%^&*)');

  const PasswordRule(this.label);

  final String label;

  bool isMetBy(String value) {
    switch (this) {
      case PasswordRule.minLength:
        return value.length >= 8;
      case PasswordRule.uppercase:
        return value.contains(RegExp(r'[A-Z]'));
      case PasswordRule.lowercase:
        return value.contains(RegExp(r'[a-z]'));
      case PasswordRule.number:
        return value.contains(RegExp(r'[0-9]'));
      case PasswordRule.special:
        // Laravel's symbols() accepts any non-letter, non-number character.
        return value.contains(RegExp(r'[^A-Za-z0-9\s]'));
    }
  }
}
