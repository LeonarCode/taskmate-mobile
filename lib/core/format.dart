import 'package:intl/intl.dart';

final _hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Parses a timestamp from the API into local time. A timestamp without a
/// zone is treated as UTC (the backend stores everything in UTC).
DateTime parseServerTime(String value) {
  final s = value.trim();
  return DateTime.parse(_hasZone.hasMatch(s) ? s : '${s}Z').toLocal();
}

DateTime? parseServerTimeOrNull(Object? value) =>
    value is String && value.isNotEmpty ? parseServerTime(value) : null;

/// The backend requires timezone-aware datetimes, so always send UTC.
String toServerTime(DateTime value) => value.toUtc().toIso8601String();

/// First letter of [name] for avatar placeholders.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty
      ? '?'
      : String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Compact relative label for conversation lists: 5m, 3h, 10/21.
String shortTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${dt.month}/${dt.day}';
}

String clockLabel(DateTime dt) => DateFormat('h:mm a').format(dt);

String dayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(dt.year == now.year ? 'MMM d' : 'MMM d, y').format(dt);
}
