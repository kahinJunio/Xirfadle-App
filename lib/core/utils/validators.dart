/// Form validators shared by the auth and request screens.
class Validators {
  const Validators._();

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required';
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 7) return 'Enter a valid phone number';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? required(String? value, String label) {
    if ((value?.trim() ?? '').isEmpty) return '$label is required';
    return null;
  }

  static String? minLength(String? value, int min, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required';
    if (text.length < min) return '$label must be at least $min characters';
    return null;
  }
}
