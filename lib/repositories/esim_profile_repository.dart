import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/esim_profile.dart';

abstract class SensitiveProfileStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureSensitiveProfileStore implements SensitiveProfileStore {
  const FlutterSecureSensitiveProfileStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class EsimProfileRepository {
  EsimProfileRepository._(this._preferences, this._sensitiveStore);

  static const String storageKey = 'esim_profiles_v1';

  final SharedPreferences _preferences;
  final SensitiveProfileStore _sensitiveStore;

  static Future<EsimProfileRepository> create({
    SensitiveProfileStore? sensitiveStore,
  }) async {
    return EsimProfileRepository._(
      await SharedPreferences.getInstance(),
      sensitiveStore ?? const FlutterSecureSensitiveProfileStore(),
    );
  }

  Future<List<EsimProfile>> loadProfiles() async {
    final encoded = _preferences.getString(storageKey);
    if (encoded == null || encoded.trim().isEmpty) return <EsimProfile>[];

    final decoded = jsonDecode(encoded);
    if (decoded is! List) return <EsimProfile>[];

    final profiles = <EsimProfile>[];
    for (final item in decoded.whereType<Map<String, Object?>>()) {
      final profile = EsimProfile.fromJson(item);
      profiles.add(await _restoreSensitiveFields(profile));
    }
    return profiles;
  }

  Future<void> saveProfiles(List<EsimProfile> profiles) async {
    await _deleteSensitiveFieldsForRemovedProfiles(profiles);
    for (final profile in profiles) {
      await _saveSensitiveFields(profile);
    }

    final encoded = jsonEncode(
      profiles
          .map((profile) => _publicJsonFor(profile))
          .toList(growable: false),
    );
    await _preferences.setString(storageKey, encoded);
  }

  Future<EsimProfile> _restoreSensitiveFields(EsimProfile profile) async {
    final rawActivationCode = await _sensitiveStore.read(
      _sensitiveKey(profile.id, 'rawActivationCode'),
    );
    final iccid = await _sensitiveStore.read(
      _sensitiveKey(profile.id, 'iccid'),
    );
    final phoneNumber = await _sensitiveStore.read(
      _sensitiveKey(profile.id, 'phoneNumber'),
    );

    final matchingId = await _sensitiveStore.read(
      _sensitiveKey(profile.id, 'matchingId'),
    );

    return profile.copyWith(
      rawActivationCode: rawActivationCode,
      iccid: iccid,
      phoneNumber: phoneNumber,
      matchingId: matchingId,
    );
  }

  Future<void> _saveSensitiveFields(EsimProfile profile) async {
    await _writeOrDelete(
      _sensitiveKey(profile.id, 'rawActivationCode'),
      profile.rawActivationCode,
    );
    await _writeOrDelete(_sensitiveKey(profile.id, 'iccid'), profile.iccid);
    await _writeOrDelete(
      _sensitiveKey(profile.id, 'phoneNumber'),
      profile.phoneNumber,
    );
    await _writeOrDelete(
      _sensitiveKey(profile.id, 'matchingId'),
      profile.matchingId,
    );
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _sensitiveStore.delete(key);
    } else {
      await _sensitiveStore.write(key, value);
    }
  }

  Future<void> _deleteSensitiveFieldsForRemovedProfiles(
    List<EsimProfile> newProfiles,
  ) async {
    final existingIds = await _storedProfileIds();
    final newIds = newProfiles.map((profile) => profile.id).toSet();
    for (final removedId in existingIds.difference(newIds)) {
      await _deleteSensitiveFields(removedId);
    }
  }

  Future<Set<String>> _storedProfileIds() async {
    final encoded = _preferences.getString(storageKey);
    if (encoded == null || encoded.trim().isEmpty) return <String>{};
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return <String>{};
    return decoded
        .whereType<Map<String, Object?>>()
        .map((item) => item['id'])
        .whereType<String>()
        .toSet();
  }

  Future<void> _deleteSensitiveFields(String profileId) async {
    await _sensitiveStore.delete(_sensitiveKey(profileId, 'rawActivationCode'));
    await _sensitiveStore.delete(_sensitiveKey(profileId, 'iccid'));
    await _sensitiveStore.delete(_sensitiveKey(profileId, 'phoneNumber'));
    await _sensitiveStore.delete(_sensitiveKey(profileId, 'matchingId'));
  }

  Map<String, Object?> _publicJsonFor(EsimProfile profile) {
    final json = profile.toJson();
    json['rawActivationCode'] = null;
    json['iccid'] = null;
    json['phoneNumber'] = null;
    json['matchingId'] = null;
    return json;
  }

  String _sensitiveKey(String profileId, String field) =>
      'esim_profile_sensitive.$profileId.$field';
}
