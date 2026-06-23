import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/repositories/esim_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('EsimProfile serializes to JSON and back without losing user data', () {
    final profile = EsimProfile(
      id: 'manual-1',
      name: '日本 7 天卡',
      carrierName: 'Ubigi',
      countryOrRegion: 'JP',
      phoneNumber: '+819012345678',
      iccid: '8981100000000000000',
      rawActivationCode: r'LPA:1$smdp.example.com$MATCHING-ID',
      smdpAddress: 'smdp.example.com',
      matchingId: 'MATCHING-ID',
      dataLimitMb: 10240,
      usedDataMb: 2048,
      activationDate: DateTime.utc(2026, 6, 1),
      expiryDate: DateTime.utc(2026, 6, 8),
      status: EsimProfileStatus.installed,
      source: EsimProfileSource.manualInstalled,
      isCurrentlyActive: true,
      deviceName: '小秦的 iPhone',
      devicePlatform: 'ios',
      note: '机场落地后启用',
      createdAt: DateTime.utc(2026, 5, 31),
      updatedAt: DateTime.utc(2026, 6, 2),
    );

    final restored = EsimProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.carrierName, profile.carrierName);
    expect(restored.phoneNumber, profile.phoneNumber);
    expect(restored.iccid, profile.iccid);
    expect(restored.rawActivationCode, profile.rawActivationCode);
    expect(restored.dataLimitMb, profile.dataLimitMb);
    expect(restored.usedDataMb, profile.usedDataMb);
    expect(restored.expiryDate, profile.expiryDate);
    expect(restored.status, profile.status);
    expect(restored.source, profile.source);
    expect(restored.isCurrentlyActive, isTrue);
    expect(restored.note, profile.note);
  });

  test('EsimProfileRepository persists a profile list round-trip', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final secureStore = InMemorySensitiveProfileStore();
    final repository = await EsimProfileRepository.create(
      sensitiveStore: secureStore,
    );
    final profile = EsimProfile.fromActivationCode(
      r'LPA:1$smdp.example.com$MATCHING-ID',
      name: '待安装日本卡',
      now: DateTime.utc(2026, 6, 22),
    );

    await repository.saveProfiles(<EsimProfile>[profile]);
    final restored = await repository.loadProfiles();

    expect(restored, hasLength(1));
    expect(restored.single.name, '待安装日本卡');
    expect(restored.single.smdpAddress, 'smdp.example.com');
    expect(
      restored.single.rawActivationCode,
      r'LPA:1$smdp.example.com$MATCHING-ID',
    );
    expect(restored.single.status, EsimProfileStatus.notInstalled);
  });

  test(
    'EsimProfileRepository keeps sensitive fields out of SharedPreferences',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final secureStore = InMemorySensitiveProfileStore();
      final repository = await EsimProfileRepository.create(
        sensitiveStore: secureStore,
      );
      final profile = EsimProfile(
        id: 'secure-1',
        name: '隐私卡',
        carrierName: 'Ubigi',
        countryOrRegion: 'JP',
        phoneNumber: '+819012345678',
        iccid: '8981100000000000000',
        rawActivationCode: r'LPA:1$smdp.example.com$SECRET-MATCHING-ID',
        smdpAddress: 'smdp.example.com',
        matchingId: 'SECRET-MATCHING-ID',
        dataLimitMb: null,
        usedDataMb: null,
        activationDate: null,
        expiryDate: null,
        status: EsimProfileStatus.notInstalled,
        source: EsimProfileSource.qrCode,
        isCurrentlyActive: false,
        deviceName: null,
        devicePlatform: null,
        note: null,
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      );

      await repository.saveProfiles(<EsimProfile>[profile]);

      final preferences = await SharedPreferences.getInstance();
      final publicJson = preferences.getString(
        EsimProfileRepository.storageKey,
      )!;
      expect(publicJson, isNot(contains('SECRET-MATCHING-ID')));
      expect(publicJson, isNot(contains('8981100000000000000')));
      expect(publicJson, isNot(contains('+819012345678')));
      expect(
        secureStore.values.values,
        contains(r'LPA:1$smdp.example.com$SECRET-MATCHING-ID'),
      );
      expect(secureStore.values.values, contains('8981100000000000000'));
      expect(secureStore.values.values, contains('+819012345678'));

      final restored = await repository.loadProfiles();
      expect(restored.single.rawActivationCode, profile.rawActivationCode);
      expect(restored.single.iccid, profile.iccid);
      expect(restored.single.phoneNumber, profile.phoneNumber);
    },
  );

  test(
    'EsimProfileRepository removes secure fields for deleted profiles',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final secureStore = InMemorySensitiveProfileStore();
      final repository = await EsimProfileRepository.create(
        sensitiveStore: secureStore,
      );
      final profile = EsimProfile.fromActivationCode(
        r'LPA:1$smdp.example.com$DELETE-ME',
        name: '待删除卡',
        now: DateTime.utc(2026, 6, 22),
      );

      await repository.saveProfiles(<EsimProfile>[profile]);
      expect(
        secureStore.values.values,
        contains(r'LPA:1$smdp.example.com$DELETE-ME'),
      );

      await repository.saveProfiles(<EsimProfile>[]);

      expect(
        secureStore.values.values,
        isNot(contains(r'LPA:1$smdp.example.com$DELETE-ME')),
      );
    },
  );
}

class InMemorySensitiveProfileStore implements SensitiveProfileStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
