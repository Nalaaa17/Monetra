import 'package:intl/intl.dart';

class DateFormatter {
  static const List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  static const List<String> _monthsFull = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  /// Format: "Senin, 23 Nov 2026"
  static String formatFull(DateTime date) {
    final dayName = _days[date.weekday - 1];
    final monthName = _months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  /// Nama singkat bulan dalam Bahasa Indonesia (`Jan`..`Des`)
  static String shortMonthName(int month) => _months[(month - 1).clamp(0, 11)];

  /// Format: "November 2026"
  static String formatMonthYear(DateTime date) {
    final monthName = _monthsFull[date.month - 1];
    return '$monthName ${date.year}';
  }

  /// Format: "23 Nov 2026"
  static String formatShort(DateTime date) {
    final monthName = _months[date.month - 1];
    return '${date.day} $monthName ${date.year}';
  }

  /// Format: "14:30"
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Label friendly: "Hari Ini", "Kemarin", atau "Senin, 23 Nov 2026"
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return 'Hari Ini, ${formatShort(date)}';
    } else if (target == today.subtract(const Duration(days: 1))) {
      return 'Kemarin, ${formatShort(date)}';
    } else {
      return formatFull(date);
    }
  }
}
