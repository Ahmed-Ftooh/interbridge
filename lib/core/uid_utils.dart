const int _kMaxAgoraUid = 0xFFFFFFFF;

/// Builds a stable Agora UID from a UUID-style user id.
///
/// Contract: strip separators, take the first 8 hex chars, parse as radix-16,
/// then normalize into the valid Agora uint32 range.
int uidFromUuid(String uuid, {int fallback = 1}) {
  if (uuid.isEmpty) {
    return _normalizeFallback(fallback);
  }

  final hex = uuid.replaceAll('-', '');
  final first8 = hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
  final parsed = int.tryParse(first8, radix: 16);

  return normalizeAgoraUid(parsed, fallback: fallback);
}

/// Normalizes any candidate UID into Agora's valid uint32 range.
int normalizeAgoraUid(int? uid, {int fallback = 1}) {
  final safeFallback = _normalizeFallback(fallback);
  final candidate = uid ?? safeFallback;

  if (candidate > 0 && candidate <= _kMaxAgoraUid) {
    return candidate;
  }

  final normalized = candidate.abs() % _kMaxAgoraUid;
  return normalized == 0 ? safeFallback : normalized;
}

int _normalizeFallback(int fallback) {
  if (fallback > 0 && fallback <= _kMaxAgoraUid) {
    return fallback;
  }
  final normalized = fallback.abs() % _kMaxAgoraUid;
  return normalized == 0 ? 1 : normalized;
}
