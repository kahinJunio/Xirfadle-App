/// Tolerant readers for API payloads, which may use camelCase or PascalCase
/// depending on the ASP.NET Core serializer configuration.
library;

Object? pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (json.containsKey(lower) && json[lower] != null) return json[lower];
    final upper = key[0].toUpperCase() + key.substring(1);
    if (json.containsKey(upper) && json[upper] != null) return json[upper];
  }
  return null;
}

String asString(Map<String, dynamic> json, List<String> keys,
    {String fallback = ''}) {
  final value = pick(json, keys);
  return value?.toString() ?? fallback;
}

String? asStringOrNull(Map<String, dynamic> json, List<String> keys) {
  final value = pick(json, keys);
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

int asInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  final value = pick(json, keys);
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? asDoubleOrNull(Map<String, dynamic> json, List<String> keys) {
  final value = pick(json, keys);
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double asDouble(Map<String, dynamic> json, List<String> keys,
        {double fallback = 0}) =>
    asDoubleOrNull(json, keys) ?? fallback;

bool asBool(Map<String, dynamic> json, List<String> keys,
    {bool fallback = false}) {
  final value = pick(json, keys);
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

DateTime? asDateOrNull(Map<String, dynamic> json, List<String> keys) {
  final value = pick(json, keys);
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
}

List<String> asStringList(Map<String, dynamic> json, List<String> keys) {
  final value = pick(json, keys);
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

/// Unwraps `{ "data": [...] }` / `{ "items": [...] }` envelopes as well as
/// bare arrays.
List<Map<String, dynamic>> asObjectList(Object? payload) {
  Object? list = payload;
  if (payload is Map<String, dynamic>) {
    list = pick(payload, ['data', 'items', 'results', 'value']) ?? payload;
  }
  if (list is List) {
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  return const [];
}

/// Unwraps a single object that may be wrapped in a `data` envelope.
Map<String, dynamic> asObject(Object? payload) {
  if (payload is Map) {
    final map = payload.cast<String, dynamic>();
    final inner = pick(map, ['data', 'result', 'value']);
    if (inner is Map) return inner.cast<String, dynamic>();
    return map;
  }
  return <String, dynamic>{};
}
