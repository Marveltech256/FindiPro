import 'package:uuid/uuid.dart';

class UuidUtils {
  static const Uuid _uuid = Uuid();

  /// Checks if a string is a valid UUID format.
  static bool isValidUuid(String str) {
    return Uuid.isValidUUID(fromString: str);
  }

  /// Converts a Firebase UID deterministically into a valid UUID string for Supabase PostgreSQL tables.
  static String firebaseUidToUuid(String firebaseUid) {
    if (firebaseUid.isEmpty) return _uuid.v4();
    // If it is already a valid UUID string format, return it directly.
    if (Uuid.isValidUUID(fromString: firebaseUid)) {
      return firebaseUid.toLowerCase();
    }
    // Deterministic v5 UUID from Firebase UID with standard URL namespace
    return _uuid.v5(Namespace.url.value, 'findipro:user:$firebaseUid');
  }
}
