import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Serializa de forma DETERMINÍSTICA (chaves ordenadas recursivamente), para
/// que o checksum seja reproduzível no export e no import.
String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonicalize(value[k])};
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}

String sha256Of(Object? data) =>
    sha256.convert(utf8.encode(canonicalJson(data))).toString();

/// Checksum do bloco `data` no formato `sha256:<hex>`.
String buildChecksum(Map<String, Object?> data) => 'sha256:${sha256Of(data)}';

bool verifyChecksum(Map<String, Object?> data, String checksum) {
  final expected = checksum.split(':').last;
  return sha256Of(data) == expected;
}
