import 'dart:convert';

import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/services/esim_profile_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EsimProfileJsonCodec exports editable JSON object with profiles', () {
    final profile = _profile(name: '日本卡');

    final exported = EsimProfileJsonCodec.encode(<EsimProfile>[profile]);
    final decoded = jsonDecode(exported) as Map<String, Object?>;

    expect(decoded['schema'], 'esim_tool_profiles_v1');
    expect(decoded['profiles'], isA<List<Object?>>());
    expect(exported, contains('日本卡'));
    expect(exported, contains('SECRET-MATCHING-ID'));
  });

  test('EsimProfileJsonCodec imports edited JSON object and raw list', () {
    final profile = _profile(name: '旧名字');
    final objectJson = EsimProfileJsonCodec.encode(<EsimProfile>[profile]);
    final editedObjectJson = objectJson.replaceFirst('旧名字', '新名字');

    final fromObject = EsimProfileJsonCodec.decode(editedObjectJson);
    final fromList = EsimProfileJsonCodec.decode(
      jsonEncode(<Object?>[profile.copyWith(name: '列表名字').toJson()]),
    );

    expect(fromObject.single.name, '新名字');
    expect(fromObject.single.matchingId, 'SECRET-MATCHING-ID');
    expect(fromList.single.name, '列表名字');
  });

  test('EsimProfileJsonCodec rejects malformed profile JSON clearly', () {
    expect(
      () => EsimProfileJsonCodec.decode('{"profiles":[{"id":"missing-name"}]}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EsimProfileJsonCodec.decode('{"profiles":"not a list"}'),
      throwsA(isA<FormatException>()),
    );
  });
}

EsimProfile _profile({required String name}) {
  return EsimProfile(
    id: 'profile-1',
    name: name,
    carrierName: 'Ubigi',
    countryOrRegion: 'JP',
    phoneNumber: '+819012345678',
    iccid: '8981100000000000000',
    rawActivationCode: r'LPA:1$smdp.example.com$SECRET-MATCHING-ID',
    smdpAddress: 'smdp.example.com',
    matchingId: 'SECRET-MATCHING-ID',
    lastServiceDate: DateTime.utc(2026, 1, 15),
    serviceIntervalMonths: 6,
    serviceReminderEnabled: true,
    status: EsimProfileStatus.installed,
    source: EsimProfileSource.manualInstalled,
    isCurrentlyActive: false,
    note: '可编辑整表 JSON',
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 2),
  );
}
