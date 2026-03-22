/// DateTime Extensions for ZSWatch App
///
/// Provides convenient methods for date/time formatting,
/// comparison, and manipulation used throughout the app.
library;

import 'package:intl/intl.dart';

/// Extension methods for DateTime
extension DateTimeExtensions on DateTime {
  /// Check if this date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if this date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if this date is this week (Sunday-Saturday)
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Check if this date is this month
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Get the start of the day (00:00:00)
  DateTime get startOfDay => DateTime(year, month, day);

  /// Get the end of the day (23:59:59.999)
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Get the start of the week (Sunday at 00:00:00)
  DateTime get startOfWeek {
    final daysFromSunday = weekday % 7;
    return subtract(Duration(days: daysFromSunday)).startOfDay;
  }

  /// Get the start of the month
  DateTime get startOfMonth => DateTime(year, month);

  /// Get the end of the month
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Get days ago from now
  int get daysAgo {
    final now = DateTime.now().startOfDay;
    final thisDate = startOfDay;
    return now.difference(thisDate).inDays;
  }

  /// Format as time (HH:mm)
  String get timeString => DateFormat('HH:mm').format(this);

  /// Format as short time (H:mm a)
  String get shortTimeString => DateFormat('h:mm a').format(this);

  /// Format as date (yyyy-MM-dd)
  String get dateString => DateFormat('yyyy-MM-dd').format(this);

  /// Format as short date (MMM d)
  String get shortDateString => DateFormat('MMM d').format(this);

  /// Format as full date (MMMM d, yyyy)
  String get fullDateString => DateFormat('MMMM d, yyyy').format(this);

  /// Format as date and time (MMM d, HH:mm)
  String get dateTimeString => DateFormat('MMM d, HH:mm').format(this);

  /// Format as relative string (Today, Yesterday, or date)
  String get relativeString {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    if (isThisWeek) return DateFormat('EEEE').format(this);
    if (isThisMonth) return DateFormat('MMM d').format(this);
    if (year == DateTime.now().year) return DateFormat('MMM d').format(this);
    return DateFormat('MMM d, yyyy').format(this);
  }

  /// Format as relative time string (5m ago, 2h ago, etc.)
  String get relativeTimeString {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return shortDateString;
    }
  }

  /// Format for Gadgetbridge protocol (Unix timestamp in seconds)
  int get unixTimestamp => millisecondsSinceEpoch ~/ 1000;

  /// Format for Gadgetbridge protocol (Unix timestamp in milliseconds)
  int get unixTimestampMs => millisecondsSinceEpoch;

  /// Create DateTime from Unix timestamp (seconds)
  static DateTime fromUnixTimestamp(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Create DateTime from Unix timestamp (milliseconds)
  static DateTime fromUnixTimestampMs(int timestampMs) {
    return DateTime.fromMillisecondsSinceEpoch(timestampMs);
  }

  /// Check if the date is within the last N days
  bool isWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return isAfter(cutoff);
  }

  /// Get the hour of the day as a string (00-23)
  String get hourString => hour.toString().padLeft(2, '0');

  /// Get the day of the week (1 = Monday, 7 = Sunday)
  int get dayOfWeek => weekday;

  /// Get the week number of the year
  int get weekOfYear {
    final firstDayOfYear = DateTime(year);
    final days = difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  /// Copy with modified fields
  DateTime copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  }) {
    return DateTime(
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
      millisecond ?? this.millisecond,
      microsecond ?? this.microsecond,
    );
  }
}

/// Extension methods for Duration
extension DurationExtensions on Duration {
  /// Format as human-readable string (1h 23m)
  String get humanReadable {
    if (inDays > 0) {
      final hours = inHours % 24;
      if (hours > 0) {
        return '${inDays}d ${hours}h';
      }
      return '${inDays}d';
    } else if (inHours > 0) {
      final minutes = inMinutes % 60;
      if (minutes > 0) {
        return '${inHours}h ${minutes}m';
      }
      return '${inHours}h';
    } else if (inMinutes > 0) {
      return '${inMinutes}m';
    } else {
      return '${inSeconds}s';
    }
  }

  /// Format as mm:ss (for DFU progress, etc.)
  String get mmss {
    final mins = inMinutes;
    final secs = inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format as hh:mm:ss
  String get hhmmss {
    final hours = inHours;
    final mins = inMinutes % 60;
    final secs = inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Extension methods for int timestamps
extension IntTimestampExtensions on int {
  /// Convert Unix timestamp (seconds) to DateTime
  DateTime get toDateTime => DateTime.fromMillisecondsSinceEpoch(this * 1000);

  /// Convert Unix timestamp (milliseconds) to DateTime
  DateTime get toDateTimeMs => DateTime.fromMillisecondsSinceEpoch(this);
}
