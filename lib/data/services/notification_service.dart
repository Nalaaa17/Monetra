import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/utils/currency_formatter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Notification service initialization note: $e');
    }
  }

  /// Jadwalkan pengingat H-3 sebelum jatuh tempo (PRD §4.4)
  static Future<void> scheduleGoalReminder({
    required int goalId,
    required String goalName,
    required DateTime deadline,
    required int remainingAmount,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // Pada desktop Windows / test, notifikasi native tidak dijalankan
      return;
    }

    try {
      await initialize();

      // Hitung H-3 jam 09:00 pagi
      final reminderDate = deadline.subtract(const Duration(days: 3));
      final targetDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        9,
        0,
      );

      final now = DateTime.now();
      if (targetDateTime.isBefore(now)) {
        // Jika H-3 sudah lewat tapi deadline belum lewat, ingatkan sekarang
        if (deadline.isAfter(now)) {
          await showInstantGoalReminder(
            goalId: goalId,
            goalName: goalName,
            remainingAmount: remainingAmount,
          );
        }
        return;
      }

      final scheduledTz = tz.TZDateTime.from(targetDateTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'goal_reminders_channel',
        'Pengingat Target Tabungan',
        channelDescription: 'Notifikasi jatuh tempo target finansial Monetra',
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        goalId,
        'Pengingat Jatuh Tempo Monetra 🎯',
        "Target '$goalName' jatuh tempo 3 hari lagi. Kurang ${CurrencyFormatter.format(remainingAmount)}.",
        scheduledTz,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  static Future<void> showInstantGoalReminder({
    required int goalId,
    required String goalName,
    required int remainingAmount,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'goal_reminders_channel',
        'Pengingat Target Tabungan',
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(
        goalId,
        'Target Segera Jatuh Tempo! 🎯',
        "Target '$goalName' mendekati tenggat waktu. Kurang ${CurrencyFormatter.format(remainingAmount)}.",
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error show notification: $e');
    }
  }

  static Future<void> cancelGoalReminder(int goalId) async {
    try {
      await _notificationsPlugin.cancel(goalId);
    } catch (_) {}
  }
}

