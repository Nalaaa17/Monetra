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
  static bool _tzInitialized = false;

  /// Menginisialisasi database timezone dan mengatur `tz.local` sesuai zona waktu
  /// perangkat agar jadwal notifikasi tidak jatuh ke UTC (meleset ±7 jam di Indonesia).
  static String resolveAndSetLocalTimezone({
    DateTime? referenceNow,
    Duration? offsetOverride,
  }) {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }

    final offset =
        offsetOverride ?? (referenceNow ?? DateTime.now()).timeZoneOffset;
    String targetLocationName;

    if (offset == const Duration(hours: 7)) {
      targetLocationName = 'Asia/Jakarta';
    } else if (offset == const Duration(hours: 8)) {
      targetLocationName = 'Asia/Makassar';
    } else if (offset == const Duration(hours: 9)) {
      targetLocationName = 'Asia/Jayapura';
    } else {
      final offsetMs = offset.inMilliseconds;
      final matched = tz.timeZoneDatabase.locations.values.where(
        (loc) => loc.currentTimeZone.offset == offsetMs,
      );
      targetLocationName =
          matched.isNotEmpty ? matched.first.name : 'Asia/Jakarta';
    }

    try {
      tz.setLocalLocation(tz.getLocation(targetLocationName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      targetLocationName = 'Asia/Jakarta';
    }

    return targetLocationName;
  }

  static Future<void> initialize() async {
    resolveAndSetLocalTimezone();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    if (_initialized) return;

    try {
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

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

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
    String? profileKey,
  }) async {
    resolveAndSetLocalTimezone();

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // Pada desktop Windows / test, notifikasi native tidak dijalankan
      return;
    }

    try {
      await initialize();

      // Hitung H-3 jam 09:00 pagi waktu lokal
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
            profileKey: profileKey,
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

      final title = 'Pengingat Jatuh Tempo Monetra 🎯';
      final body =
          "Target '$goalName' jatuh tempo 3 hari lagi. Kurang ${CurrencyFormatter.format(remainingAmount)}.";

      final payloadTag = 'profile:${profileKey ?? 'default'};goalId:$goalId';

      try {
        await _notificationsPlugin.zonedSchedule(
          goalId,
          title,
          body,
          scheduledTz,
          notificationDetails,
          payload: payloadTag,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Fallback jika izin exact alarm Android 12+ belum diaktifkan pengguna
        await _notificationsPlugin.zonedSchedule(
          goalId,
          title,
          body,
          scheduledTz,
          notificationDetails,
          payload: payloadTag,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  static Future<void> showInstantGoalReminder({
    required int goalId,
    required String goalName,
    required int remainingAmount,
    String? profileKey,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

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

      final payloadTag = 'profile:${profileKey ?? 'default'};goalId:$goalId';

      await _notificationsPlugin.show(
        goalId,
        'Target Segera Jatuh Tempo! 🎯',
        "Target '$goalName' mendekati tenggat waktu. Kurang ${CurrencyFormatter.format(remainingAmount)}.",
        notificationDetails,
        payload: payloadTag,
      );
    } catch (e) {
      debugPrint('Error show notification: $e');
    }
  }

  static Future<void> cancelGoalReminder(int goalId) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      await _notificationsPlugin.cancel(goalId);
    } catch (_) {}
  }

  /// Menampilkan ringkasan notifikasi ketika transaksi berulang dicatat otomatis.
  static Future<void> showRecurringRecordedNotification({
    required int count,
    required List<String> titles,
  }) async {
    if (count <= 0 || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        'recurring_transactions_channel',
        'Transaksi Berulang Otomatis',
        channelDescription:
            'Pemberitahuan saat tagihan atau gaji rutin otomatis dicatat oleh Monetra',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final preview = titles.take(2).join(', ');
      final extra = titles.length > 2 ? ' +${titles.length - 2} lainnya' : '';
      await _notificationsPlugin.show(
        900001,
        'Monetra • $count Transaksi Rutin Dicatat',
        '$preview$extra otomatis masuk ke catatan & saldo Anda.',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error show recurring notification: $e');
    }
  }
}
