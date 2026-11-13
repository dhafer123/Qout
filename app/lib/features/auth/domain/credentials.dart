/// Sign-in and account form rules, the same as the backend's
/// (`modules/auth/passwords.py`): checked here for quick feedback, enforced
/// there.
library;

const minPasswordLength = 10;
const maxPasswordLength = 128;
const maxEmailLength = 254;

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Trimmed and lower-cased, as the backend compares emails.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Why [email] can't be used, or null.
String? emailProblem(String email) {
  final cleaned = normalizeEmail(email);
  if (cleaned.isEmpty) return 'Enter your email address.';
  if (cleaned.length > maxEmailLength || !_email.hasMatch(cleaned)) {
    return 'This is not a valid email address.';
  }
  return null;
}

/// Why [password] can't be used, or null. Only a new account's password must
/// be long enough; signing in only needs one.
String? passwordProblem(String password, {required bool newAccount}) {
  if (password.isEmpty) return 'Enter your password.';
  if (password.length > maxPasswordLength) {
    return 'Use at most $maxPasswordLength characters.';
  }
  if (newAccount && password.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters.';
  }
  return null;
}
