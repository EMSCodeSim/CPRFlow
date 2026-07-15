import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic checksum helper for Phase 3 archived snapshots.
class SnapshotChecksum {
  static String sha256HexFromUtf8(String utf8String) {
    final bytes = utf8.encode(utf8String);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
