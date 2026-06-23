import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/esim_profile.dart';

enum EsimReminderType { expiryThreeDays, expiryOneDay, lowData }

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
      'esim_tool_reminders',
      'eSIM 提醒',
      channelDescription: 'eSIM 到期和流量不足提醒',
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
    await _plugin.initialize(settings: settings);
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
    try {
      await _plugin.cancelAllPendingNotifications();
    } on UnimplementedError {
      await _plugin.cancelAll();
    }
  }

  @override
  Future<void> schedule(EsimReminder reminder) async {
    await initialize();
    await _requestPermissions();
    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
      notificationDetails: _notificationDetails,
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
        profile.effectiveStatus(now) == EsimProfileStatus.expired) {
      return const <EsimReminder>[];
    }

    final reminders = <EsimReminder>[];
    final expiryDate = profile.expiryDate;
    final reminderDaysBefore = profile.reminderDaysBefore;
    if (expiryDate != null && reminderDaysBefore != null) {
      final fireAt = _reminderTime(expiryDate, daysBefore: reminderDaysBefore);
      if (!fireAt.isBefore(now)) {
        reminders.add(
          EsimReminder(
            id: _notificationId(profile.id, EsimReminderType.expiryThreeDays),
            profileId: profile.id,
            type: EsimReminderType.expiryThreeDays,
            fireAt: fireAt,
            title:
                '${profile.name} ${_expiryReminderLabel(reminderDaysBefore)}',
            body: '这张 eSIM 即将到期，出行前记得续费、切换套餐或准备备用网络。',
          ),
        );
      }
    }

    if (profile.isDataLow) {
      reminders.add(
        EsimReminder(
          id: _notificationId(profile.id, EsimReminderType.lowData),
          profileId: profile.id,
          type: EsimReminderType.lowData,
          fireAt: now,
          title: '${profile.name} 流量快用完了',
          body: '当前套餐流量剩余不足 10%，建议及时充值或切换备用 eSIM。',
        ),
      );
    }

    reminders.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return reminders;
  }

  static String _expiryReminderLabel(int daysBefore) {
    return switch (daysBefore) {
      0 => '今天到期',
      1 => '明天到期',
      _ => '$daysBefore 天后到期',
    };
  }

  static DateTime _reminderTime(
    DateTime expiryDate, {
    required int daysBefore,
  }) {
    final dateOnly = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return dateOnly
        .subtract(Duration(days: daysBefore))
        .add(const Duration(hours: 9));
  }

  static int _notificationId(String profileId, EsimReminderType type) {
    var hash = type.index + 1;
    for (final codeUnit in profileId.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + codeUnit);
    }
    return hash;
  }
}
