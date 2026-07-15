import 'dart:math';

/// Generates stable-enough unique IDs for local-only storage.
///
/// We intentionally avoid external dependencies (e.g. uuid) for Phase 1/2.
class IdGenerator {
  IdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String newId({String prefix = ''}) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    // IMPORTANT (web): Avoid `(1 << 32)`.
    // In JavaScript, bit-shifts are limited to 32 bits, so `1 << 32` becomes 0,
    // which would cause `nextInt(0)` and crash.
    const maxUint32Exclusive = 0x100000000; // 2^32
    final r = _random.nextInt(maxUint32Exclusive).toRadixString(16).padLeft(8, '0');
    return prefix.isEmpty ? '${ts}_$r' : '${prefix}_${ts}_$r';
  }

  /// Deterministic IDs for (attempt, item) results so upserts are easy.
  String checklistItemResultId({required String attemptId, required String itemId}) => '${attemptId}::${itemId}';
}
