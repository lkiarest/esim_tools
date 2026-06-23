import 'package:flutter/services.dart';

enum DiscoveryConfidence { high, medium, low, unknown }

enum EsimDiscoveryFailureReason {
  unsupportedDevice,
  permissionDenied,
  platformRestricted,
  noProfilesFound,
  unknown,
}

class DiscoveredEsim {
  const DiscoveredEsim({
    required this.carrierName,
    required this.displayName,
    required this.countryIso,
    required this.mobileCountryCode,
    required this.mobileNetworkCode,
    required this.phoneNumber,
    required this.iccid,
    required this.isEmbedded,
    required this.isActive,
    required this.platform,
    required this.confidence,
  });

  final String? carrierName;
  final String? displayName;
  final String? countryIso;
  final String? mobileCountryCode;
  final String? mobileNetworkCode;
  final String? phoneNumber;
  final String? iccid;
  final bool? isEmbedded;
  final bool? isActive;
  final String platform;
  final DiscoveryConfidence confidence;

  factory DiscoveredEsim.fromMap(Map<Object?, Object?> map) {
    return DiscoveredEsim(
      carrierName: map['carrierName'] as String?,
      displayName: map['displayName'] as String?,
      countryIso: map['countryIso'] as String?,
      mobileCountryCode: map['mobileCountryCode'] as String?,
      mobileNetworkCode: map['mobileNetworkCode'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      iccid: map['iccid'] as String?,
      isEmbedded: map['isEmbedded'] as bool?,
      isActive: map['isActive'] as bool?,
      platform: map['platform'] as String? ?? 'unknown',
      confidence: _confidenceFromString(map['confidence'] as String?),
    );
  }
}

class EsimDiscoveryResult {
  const EsimDiscoveryResult({
    required this.supported,
    required this.permissionGranted,
    required this.profiles,
    required this.failureReason,
    required this.note,
  });

  final bool supported;
  final bool permissionGranted;
  final List<DiscoveredEsim> profiles;
  final EsimDiscoveryFailureReason? failureReason;
  final String? note;

  factory EsimDiscoveryResult.fromMap(Map<Object?, Object?> map) {
    final rawProfiles = (map['profiles'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(DiscoveredEsim.fromMap)
        .toList(growable: false);

    return EsimDiscoveryResult(
      supported: map['supported'] as bool? ?? false,
      permissionGranted: map['permissionGranted'] as bool? ?? false,
      profiles: rawProfiles,
      failureReason: _failureReasonFromString(map['failureReason'] as String?),
      note: map['note'] as String?,
    );
  }
}

class InstalledEsimDiscovery {
  const InstalledEsimDiscovery({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('esim_tool/installed_esim_discovery');

  final MethodChannel _channel;

  Future<EsimDiscoveryResult> discoverInstalledEsims() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'discoverInstalledEsims',
      );
      return EsimDiscoveryResult.fromMap(result ?? const <Object?, Object?>{});
    } on MissingPluginException {
      return const EsimDiscoveryResult(
        supported: false,
        permissionGranted: false,
        profiles: <DiscoveredEsim>[],
        failureReason: EsimDiscoveryFailureReason.platformRestricted,
        note: '当前平台没有实现自动获取 eSIM 的能力，请手动添加。',
      );
    } on PlatformException catch (error) {
      return EsimDiscoveryResult(
        supported: true,
        permissionGranted: error.code != 'permission_denied',
        profiles: const <DiscoveredEsim>[],
        failureReason: error.code == 'permission_denied'
            ? EsimDiscoveryFailureReason.permissionDenied
            : EsimDiscoveryFailureReason.unknown,
        note: error.message,
      );
    }
  }
}

DiscoveryConfidence _confidenceFromString(String? value) {
  return switch (value) {
    'high' => DiscoveryConfidence.high,
    'medium' => DiscoveryConfidence.medium,
    'low' => DiscoveryConfidence.low,
    _ => DiscoveryConfidence.unknown,
  };
}

EsimDiscoveryFailureReason? _failureReasonFromString(String? value) {
  return switch (value) {
    'unsupportedDevice' => EsimDiscoveryFailureReason.unsupportedDevice,
    'permissionDenied' => EsimDiscoveryFailureReason.permissionDenied,
    'platformRestricted' => EsimDiscoveryFailureReason.platformRestricted,
    'noProfilesFound' => EsimDiscoveryFailureReason.noProfilesFound,
    'unknown' => EsimDiscoveryFailureReason.unknown,
    _ => null,
  };
}
