import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/esim_profile.dart';

enum EsimReminderType { keepAliveConsumption }

class EsimReminder {
  const EsimReminder({
    required this.id,
    required this.profileId,
    required this.type,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  final int id;
  final String profileId;
  final EsimReminderType type;
  final DateTime fireAt;
  final String title;
  final String body;
}

abstract class EsimReminderNotifier {
  Future<void> initialize();
  Future<void> cancelAll();
  Future<void> schedule(EsimReminder reminder);
}

class NoopEsimReminderNotifier implements EsimReminderNotifier {
  const NoopEsimReminderNotifier();

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(EsimReminder reminder) async {}
}

class FlutterLocalEsimReminderNotifier implements EsimReminderNotifier {
  FlutterLocalEsimReminderNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionRequested = false;

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'esim_tool_keep_alive_reminders',
      'eSIM 保号提醒',
      channelDescription: 'eSIM 定期消费保号提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    if (_permissionRequested || kIsWeb) return;
    _permissionRequested = true;
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(EsimReminder reminder) async {
    await initialize();
    await _requestPermissions();
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      tz.TZDateTime.from(reminder.fireAt, tz.local),
      _notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.profileId,
    );
  }
}

class EsimReminderCoordinator {
  EsimReminderCoordinator({required EsimReminderNotifier notifier})
    : _notifier = notifier;

  final EsimReminderNotifier _notifier;

  Future<void> rescheduleAll(
    List<EsimProfile> profiles, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    await _notifier.initialize();
    await _notifier.cancelAll();
    for (final profile in profiles) {
      final reminders = EsimReminderPlanner.planForProfile(
        profile,
        now: current,
      );
      for (final reminder in reminders) {
        await _notifier.schedule(reminder);
      }
    }
  }
}

class EsimReminderPlanner {
  const EsimReminderPlanner._();

  static List<EsimReminder> planForProfile(
    EsimProfile profile, {
    required DateTime now,
  }) {
    if (profile.status == EsimProfileStatus.archived ||
        !profile.serviceReminderEnabled) {
      return const <EsimReminder>[];
    }
    final nextServiceDate = profile.nextServiceDate;
    final months = profile.serviceIntervalMonths;
    if (nextServiceDate == null || months == null) return const <EsimReminder>[];

    final scheduled = DateTime(
      nextServiceDate.year,
      nextServiceDate.month,
      nextServiceDate.day,
      9,
    );
    final overdue = scheduled.isBefore(now);
    final fireAt = overdue ? now : scheduled;
    return <EsimReminder>[
      EsimReminder(
        id: _notificationId(profile.id, EsimReminderType.keepAliveConsumption),
        profileId: profile.id,
        type: EsimReminderType.keepAliveConsumption,
        fireAt: fireAt,
        title: '${profile.name} 该消费保号了',
        body: overdue
            ? '这张 eSIM 已经到了保号消费时间。建议现在发短信、充值或产生一次消费，避免号码失效。'
            : '这张 eSIM 每 $months 个月需要消费一次用于保号。到时记得发短信、充值或产生一次消费。',
      ),
    ];
  }

  static int _notificationId(String profileId, EsimReminderType type) {
    var hash = type.index + 1;
    for (final codeUnit in profileId.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + codeUnit);
    }
    return hash;
  }
}
