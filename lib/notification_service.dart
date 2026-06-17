import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Service singleton untuk menjadwalkan & membatalkan notifikasi
/// pengingat jadwal meeting secara lokal (tanpa server).
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'meeting_reminder_channel';
  static const String _channelName = 'Pengingat Jadwal Meeting';
  static const String _channelDesc =
      'Notifikasi pengingat sebelum jadwal meeting dimulai';

  /// Wajib dipanggil sekali sebelum aplikasi digunakan (di main.dart).
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      // fallback ke timezone default device jika gagal
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
  settings: const InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  ),
);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await requestPermissions();
    _initialized = true;
  }

  /// Meminta izin notifikasi & alarm presisi (Android 13+ dan iOS).
  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Menjadwalkan notifikasi pengingat sebelum [meetingDateTime].
  /// Contoh: reminderMinutesBefore = 30 -> notifikasi muncul 30 menit
  /// sebelum jadwal dimulai.
  Future<void> scheduleMeetingReminder({
    required int id,
    required String title,
    required String body,
    required DateTime meetingDateTime,
    int reminderMinutesBefore = 30,
  }) async {
    // Selalu batalkan jadwal lama dulu agar tidak dobel saat edit
    await cancelReminder(id);

    if (reminderMinutesBefore <= 0) return;

    final reminderTime =
        meetingDateTime.subtract(Duration(minutes: reminderMinutesBefore));

    // Jangan jadwalkan jika waktu pengingat sudah lewat dari sekarang
    if (reminderTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    await _plugin.zonedSchedule(
  id: id,
  title: title,
  body: body,
  scheduledDate: scheduledDate,
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  ),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);

    if (kDebugMode) {
      debugPrint('🔔 Reminder dijadwalkan pada $scheduledDate (id=$id)');
    }
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id :id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}