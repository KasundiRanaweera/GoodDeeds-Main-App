import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe type conversion utilities with fallback support.
class TypeConverters {
  /// Convert dynamic value to String
  static String asString(dynamic value, {String fallback = ''}) {
    if (value is String) return value.trim();
    if (value == null) return fallback;
    return value.toString().trim();
  }

  /// Convert dynamic value to int
  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Convert dynamic value to double
  static double asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Convert dynamic value to DateTime
  static DateTime? asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Convert dynamic value to List of strings
  static List<String> asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((x) => x.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Convert dynamic value to Map with string keys and dynamic values
  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return const {};
  }
}
