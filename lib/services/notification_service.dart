import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _restChannel =
      AndroidNotificationChannel(
    'rest_timer',
    'Satzpausen',
    description: 'Benachrichtigungen für Satzpausen',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      _restChannel,
    );

    await android?.requestNotificationsPermission();
  }

  static Future<void> scheduleRestFinished({
    required Duration duration,
  }) async {
    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(duration);

    await _notifications.zonedSchedule(
      id: 1001,
      title: '⏱️ Pause vorbei',
      body: 'Nächsten Satz starten!',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Satzpausen',
          channelDescription:
              'Benachrichtigungen für Satzpausen',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelRestFinished() async {
    await _notifications.cancel(
      id: 1001,
    );
  }
}