import 'package:intl/intl.dart';

final _dayFormat = DateFormat('d MMM yyyy');
final _dayTimeFormat = DateFormat('d MMM, HH:mm');

String formatDate(DateTime? date) =>
    date == null ? '—' : _dayFormat.format(date);

String formatDateTime(DateTime? date) =>
    date == null ? '—' : _dayTimeFormat.format(date);

/// "2 hours ago" style stamps for request feeds.
String formatRelative(DateTime? date) {
  if (date == null) return '—';
  final diff = DateTime.now().difference(date);
  if (diff.isNegative) return _dayTimeFormat.format(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _dayFormat.format(date);
}

/// Normalises local Somali numbers to E.164 where possible.
String normalisePhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('0')) return '+252${digits.substring(1)}';
  if (digits.length == 9) return '+252$digits';
  return digits;
}
