class TolerantReader {
  /// Reads a value as a boolean. Accepts true/false, 0/1, '0'/'1', 'true'/'false'.
  static bool? readBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v == 1 || v == '1' || v == 'true' || v == 'True') return true;
    if (v == 0 || v == '0' || v == 'false' || v == 'False') return false;
    return null;
  }

  /// Reads a value as an integer. Accepts int, double (rounded or truncated), String.
  static int? readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
    return null;
  }

  /// Reads a value as a double. Accepts double, int, String.
  static double? readDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Safely prepares a value for SQLite insertion.
  /// Booleans are converted to 1/0.
  /// Nulls, nums, and Strings pass through.
  /// Other types (like Maps/Lists) are passed through (but should be handled externally via jsonEncode).
  static dynamic toSqliteValue(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v ? 1 : 0;
    if (v is num || v is String) return v;
    return v.toString(); // Fallback
  }
}
