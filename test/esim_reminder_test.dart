import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/services/esim_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EsimReminderPlanner', () {
    test('plans configurable expiry reminder before expiry', () {
      final now = DateTime(2026, 6, 22, 9);
      final profile = _profile(
        expiryDate: DateTime(2026, 6, 25),
        dataLimitMb: 10240,
        usedDataMb: 1000,
      );

      final reminders = EsimReminderPlanner.planForProfile(profile, now: now);

      expect(reminders.map((reminder) => reminder.type), <EsimReminderType>[
        EsimReminderType.expiryThreeDays,
      ]);
      expect(reminders.single.fireAt, DateTime(2026, 6, 22, 9));
      expect(reminders.single.title, '日本 7 天卡 3 天后到期');
    });

    test('does not plan reminders in the past or for archived profiles', () {
      final now = DateTime(2026, 6, 22, 9);
      final expired = _profile(expiryDate: DateTime(2026, 6, 20));
      final archived = _profile(
        expiryDate: DateTime(2026, 6, 25),
        status: EsimProfileStatus.archived,
      );

      expect(EsimReminderPlanner.planForProfile(expired, now: now), isEmpty);
      expect(EsimReminderPlanner.planForProfile(archived, now: now), isEmpty);
    });

    test('plans low data reminder once when usage reaches 90 percent', () {
      final now = DateTime(2026, 6, 22, 9);
      final profile = _profile(dataLimitMb: 10240, usedDataMb: 9300);

      final reminders = EsimReminderPlanner.planForProfile(profile, now: now);

      expect(reminders, hasLength(1));
      expect(reminders.single.type, EsimReminderType.lowData);
      expect(reminders.single.fireAt, now);
      expect(reminders.single.body, contains('剩余不足 10%'));
    });
  });

  group('EsimReminderCoordinator', () {
    test('reschedules all reminders after profile list changes', () async {
      final notifier = RecordingEsimReminderNotifier();
      final coordinator = EsimReminderCoordinator(notifier: notifier);
      final profiles = <EsimProfile>[
        _profile(
          id: 'trip-a',
          expiryDate: DateTime(2026, 6, 25),
          dataLimitMb: 10240,
          usedDataMb: 9500,
        ),
        _profile(id: 'trip-b', expiryDate: DateTime(2026, 7, 1)),
      ];

      await coordinator.rescheduleAll(profiles, now: DateTime(2026, 6, 22, 9));

      expect(notifier.cancelled, isTrue);
      expect(notifier.scheduled.map((reminder) => reminder.profileId), <String>[
        'trip-a',
        'trip-a',
        'trip-b',
      ]);
    });
  });
}

class RecordingEsimReminderNotifier implements EsimReminderNotifier {
  bool cancelled = false;
  final List<EsimReminder> scheduled = <EsimReminder>[];

  @override
  Future<void> cancelAll() async {
    cancelled = true;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(EsimReminder reminder) async {
    scheduled.add(reminder);
  }
}

EsimProfile _profile({
  String id = 'manual-1',
  DateTime? expiryDate,
  int? dataLimitMb,
  int? usedDataMb,
  EsimProfileStatus status = EsimProfileStatus.installed,
}) {
  return EsimProfile(
    id: id,
    name: '日本 7 天卡',
    carrierName: 'Ubigi',
    countryOrRegion: 'JP',
    phoneNumber: null,
    iccid: null,
    rawActivationCode: null,
    smdpAddress: null,
    matchingId: null,
    dataLimitMb: dataLimitMb,
    usedDataMb: usedDataMb,
    activationDate: null,
    expiryDate: expiryDate,
    status: status,
    source: EsimProfileSource.manualInstalled,
    isCurrentlyActive: false,
    deviceName: null,
    devicePlatform: null,
    note: null,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );
}
