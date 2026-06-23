import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/services/esim_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EsimReminderPlanner', () {
    test('plans keep-alive consumption reminder every configured months', () {
      final now = DateTime(2026, 6, 22, 9);
      final profile = _profile(
        lastServiceDate: DateTime(2026, 1, 15),
        serviceIntervalMonths: 6,
      );

      final reminders = EsimReminderPlanner.planForProfile(profile, now: now);

      expect(reminders, hasLength(1));
      expect(reminders.single.type, EsimReminderType.keepAliveConsumption);
      expect(reminders.single.fireAt, DateTime(2026, 7, 15, 9));
      expect(reminders.single.title, '日本保号卡 该消费保号了');
      expect(reminders.single.body, contains('每 6 个月'));
    });

    test('plans immediate keep-alive reminder when consumption is overdue', () {
      final now = DateTime(2026, 8, 1, 10, 30);
      final profile = _profile(
        lastServiceDate: DateTime(2026, 1, 15),
        serviceIntervalMonths: 6,
      );

      final reminders = EsimReminderPlanner.planForProfile(profile, now: now);

      expect(reminders, hasLength(1));
      expect(reminders.single.fireAt, now);
      expect(reminders.single.body, contains('已经到了保号消费时间'));
    });

    test('does not plan reminders when keep-alive is disabled or archived', () {
      final now = DateTime(2026, 8, 1, 9);
      final disabled = _profile(serviceReminderEnabled: false);
      final archived = _profile(status: EsimProfileStatus.archived);

      expect(EsimReminderPlanner.planForProfile(disabled, now: now), isEmpty);
      expect(EsimReminderPlanner.planForProfile(archived, now: now), isEmpty);
    });
  });

  group('EsimReminderCoordinator', () {
    test('reschedules all reminders after profile list changes', () async {
      final notifier = RecordingEsimReminderNotifier();
      final coordinator = EsimReminderCoordinator(notifier: notifier);
      final profiles = <EsimProfile>[
        _profile(
          id: 'keep-a',
          lastServiceDate: DateTime(2026, 1, 15),
          serviceIntervalMonths: 6,
        ),
        _profile(
          id: 'keep-b',
          lastServiceDate: DateTime(2026, 2, 1),
          serviceIntervalMonths: 6,
        ),
      ];

      await coordinator.rescheduleAll(profiles, now: DateTime(2026, 6, 22, 9));

      expect(notifier.cancelled, isTrue);
      expect(notifier.scheduled.map((reminder) => reminder.profileId), <String>[
        'keep-a',
        'keep-b',
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
  DateTime? lastServiceDate,
  int? serviceIntervalMonths = 6,
  bool serviceReminderEnabled = true,
  EsimProfileStatus status = EsimProfileStatus.installed,
}) {
  return EsimProfile(
    id: id,
    name: '日本保号卡',
    carrierName: 'Ubigi',
    countryOrRegion: 'JP',
    phoneNumber: null,
    iccid: null,
    rawActivationCode: null,
    smdpAddress: null,
    matchingId: null,
    lastServiceDate: lastServiceDate,
    serviceIntervalMonths: serviceIntervalMonths,
    serviceReminderEnabled: serviceReminderEnabled,
    status: status,
    source: EsimProfileSource.manualInstalled,
    isCurrentlyActive: false,
    note: null,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );
}
