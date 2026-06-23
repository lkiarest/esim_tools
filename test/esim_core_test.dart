import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/services/installed_esim_discovery.dart';
import 'package:esim_tool/services/lpa_activation_code_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LpaActivationCodeParser', () {
    test('parses LPA activation code into SM-DP+ address and matching ID', () {
      final parsed = LpaActivationCodeParser.parse(
        r'LPA:1$smdp.example.com$MATCHING-ID',
      );

      expect(parsed.version, '1');
      expect(parsed.smdpAddress, 'smdp.example.com');
      expect(parsed.matchingId, 'MATCHING-ID');
      expect(parsed.raw, r'LPA:1$smdp.example.com$MATCHING-ID');
    });

    test('rejects non-LPA activation codes with a useful error', () {
      expect(
        () => LpaActivationCodeParser.parse('not an lpa code'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('InstalledEsimDiscovery', () {
    const channel = MethodChannel('esim_tool/installed_esim_discovery');
    late InstalledEsimDiscovery discovery;

    setUp(() {
      discovery = const InstalledEsimDiscovery();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'discoverInstalledEsims');
            return <String, Object?>{
              'supported': true,
              'permissionGranted': true,
              'failureReason': null,
              'note': '1 profile discovered',
              'profiles': <Map<String, Object?>>[
                <String, Object?>{
                  'carrierName': 'Ubigi',
                  'displayName': 'Japan Travel',
                  'countryIso': 'jp',
                  'mobileCountryCode': '440',
                  'mobileNetworkCode': '10',
                  'phoneNumber': null,
                  'iccid': null,
                  'isEmbedded': true,
                  'isActive': true,
                  'platform': 'android',
                  'confidence': 'high',
                },
              ],
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps platform discovery result into domain objects', () async {
      final result = await discovery.discoverInstalledEsims();

      expect(result.supported, isTrue);
      expect(result.permissionGranted, isTrue);
      expect(result.profiles, hasLength(1));
      expect(result.profiles.single.carrierName, 'Ubigi');
      expect(result.profiles.single.isEmbedded, isTrue);
      expect(result.profiles.single.confidence, DiscoveryConfidence.high);
    });
  });

  group('EsimProfile', () {
    test('creates installed profile from a system discovery candidate', () {
      const discovered = DiscoveredEsim(
        carrierName: 'Ubigi',
        displayName: 'Japan Travel',
        countryIso: 'jp',
        mobileCountryCode: '440',
        mobileNetworkCode: '10',
        phoneNumber: null,
        iccid: null,
        isEmbedded: true,
        isActive: true,
        platform: 'android',
        confidence: DiscoveryConfidence.high,
      );

      final profile = EsimProfile.fromDiscovered(
        discovered,
        now: DateTime(2026, 6, 22),
      );

      expect(profile.name, 'Japan Travel');
      expect(profile.carrierName, 'Ubigi');
      expect(profile.status, EsimProfileStatus.installed);
      expect(profile.source, EsimProfileSource.systemDiscovered);
      expect(profile.isCurrentlyActive, isTrue);
    });

    test(
      'creates inactive system-discovered profile when platform marks it inactive',
      () {
        const discovered = DiscoveredEsim(
          carrierName: 'Nomad',
          displayName: 'Europe Backup',
          countryIso: 'eu',
          mobileCountryCode: null,
          mobileNetworkCode: null,
          phoneNumber: null,
          iccid: null,
          isEmbedded: true,
          isActive: false,
          platform: 'android',
          confidence: DiscoveryConfidence.high,
        );

        final profile = EsimProfile.fromDiscovered(
          discovered,
          now: DateTime(2026, 6, 22),
        );

        expect(profile.name, 'Europe Backup');
        expect(profile.status, EsimProfileStatus.installed);
        expect(profile.isCurrentlyActive, isFalse);
        expect(profile.note, contains('未启用'));
      },
    );

    test('keeps archived status without synthetic expiry logic', () {
      final profile = EsimProfile.fromActivationCode(
        r'LPA:1$smdp.example.com$MATCHING-ID',
        now: DateTime.utc(2026, 6, 1),
      ).copyWith(status: EsimProfileStatus.archived);

      expect(
        profile.effectiveStatus(DateTime.utc(2026, 6, 22)),
        EsimProfileStatus.archived,
      );
    });

    test('reports keep-alive due dates instead of expiry or data usage', () {
      final profile =
          EsimProfile.fromActivationCode(
            r'LPA:1$smdp.example.com$MATCHING-ID',
            now: DateTime.utc(2026, 1, 1),
          ).copyWith(
            status: EsimProfileStatus.installed,
            lastServiceDate: DateTime.utc(2026, 1, 15),
            serviceIntervalMonths: 6,
            serviceReminderEnabled: true,
          );

      expect(profile.nextServiceDate, DateTime.utc(2026, 7, 15));
      expect(profile.daysUntilService(DateTime.utc(2026, 7, 10)), 5);
      expect(
        profile.attentionMessages(DateTime.utc(2026, 7, 10)),
        contains('5 天后需要消费保号'),
      );
      expect(
        profile.attentionMessages(DateTime.utc(2026, 7, 16)),
        contains('已到保号消费时间'),
      );
      expect(profile.toJson().keys, isNot(contains('expiryDate')));
      expect(profile.toJson().keys, isNot(contains('dataLimitMb')));
      expect(profile.toJson().keys, isNot(contains('deviceName')));
    });
  });
}
