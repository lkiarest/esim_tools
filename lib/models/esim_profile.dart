import '../services/installed_esim_discovery.dart';
import '../services/lpa_activation_code_parser.dart';

enum EsimProfileStatus { notInstalled, installed, archived, expired }

enum EsimProfileSource {
  qrCode,
  activationCode,
  manualInstalled,
  systemDiscovered,
}

class EsimProfile {
  const EsimProfile({
    required this.id,
    required this.name,
    required this.carrierName,
    required this.countryOrRegion,
    required this.phoneNumber,
    required this.iccid,
    required this.rawActivationCode,
    required this.smdpAddress,
    required this.matchingId,
    required this.dataLimitMb,
    required this.usedDataMb,
    required this.activationDate,
    required this.expiryDate,
    required this.status,
    required this.source,
    required this.isCurrentlyActive,
    required this.deviceName,
    required this.devicePlatform,
    required this.note,
    this.reminderDaysBefore = 3,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? carrierName;
  final String? countryOrRegion;
  final String? phoneNumber;
  final String? iccid;
  final String? rawActivationCode;
  final String? smdpAddress;
  final String? matchingId;
  final int? dataLimitMb;
  final int? usedDataMb;
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final EsimProfileStatus status;
  final EsimProfileSource source;
  final bool isCurrentlyActive;
  final String? deviceName;
  final String? devicePlatform;
  final String? note;

  /// 到期日前几天提醒；null 表示不提醒。
  final int? reminderDaysBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? daysUntilExpiry(DateTime now) {
    if (expiryDate == null) return null;
    return _dateOnly(expiryDate!).difference(_dateOnly(now)).inDays;
  }

  EsimProfileStatus effectiveStatus(DateTime now) {
    if (status == EsimProfileStatus.archived) return EsimProfileStatus.archived;
    final days = daysUntilExpiry(now);
    if (days != null && days < 0) return EsimProfileStatus.expired;
    return status;
  }

  bool isExpiringSoon(DateTime now, {int thresholdDays = 3}) {
    if (effectiveStatus(now) != EsimProfileStatus.installed) return false;
    final days = daysUntilExpiry(now);
    return days != null && days >= 0 && days <= thresholdDays;
  }

  double? get dataUsageRatio {
    final limit = dataLimitMb;
    final used = usedDataMb;
    if (limit == null || limit <= 0 || used == null) return null;
    return used.clamp(0, limit) / limit;
  }

  bool get isDataLow {
    final ratio = dataUsageRatio;
    return ratio != null && ratio >= 0.9;
  }

  List<String> attentionMessages(DateTime now) {
    final messages = <String>[];
    final effective = effectiveStatus(now);
    final days = daysUntilExpiry(now);
    if (effective == EsimProfileStatus.expired) {
      messages.add('已过期');
    } else if (isExpiringSoon(now) && days != null) {
      messages.add(days == 0 ? '今天到期' : '$days 天后到期');
    }
    if (isDataLow) {
      messages.add('流量剩余不足 10%');
    }
    return messages;
  }

  factory EsimProfile.fromDiscovered(
    DiscoveredEsim discovered, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final name = discovered.displayName?.trim().isNotEmpty == true
        ? discovered.displayName!.trim()
        : discovered.carrierName?.trim().isNotEmpty == true
        ? discovered.carrierName!.trim()
        : '已安装 eSIM';

    return EsimProfile(
      id: 'system-${timestamp.microsecondsSinceEpoch}',
      name: name,
      carrierName: discovered.carrierName,
      countryOrRegion: discovered.countryIso?.toUpperCase(),
      phoneNumber: discovered.phoneNumber,
      iccid: discovered.iccid,
      rawActivationCode: null,
      smdpAddress: null,
      matchingId: null,
      dataLimitMb: null,
      usedDataMb: null,
      activationDate: null,
      expiryDate: null,
      status: EsimProfileStatus.installed,
      source: EsimProfileSource.systemDiscovered,
      isCurrentlyActive: discovered.isActive ?? false,
      deviceName: null,
      devicePlatform: discovered.platform,
      note: _noteForDiscovered(discovered),
      reminderDaysBefore: 3,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory EsimProfile.fromActivationCode(
    String input, {
    String? name,
    DateTime? now,
  }) {
    final parsed = LpaActivationCodeParser.parse(input);
    final timestamp = now ?? DateTime.now();
    return EsimProfile(
      id: 'lpa-${timestamp.microsecondsSinceEpoch}',
      name: name?.trim().isNotEmpty == true ? name!.trim() : '待安装 eSIM',
      carrierName: null,
      countryOrRegion: null,
      phoneNumber: null,
      iccid: null,
      rawActivationCode: parsed.raw,
      smdpAddress: parsed.smdpAddress,
      matchingId: parsed.matchingId,
      dataLimitMb: null,
      usedDataMb: null,
      activationDate: null,
      expiryDate: null,
      status: EsimProfileStatus.notInstalled,
      source: EsimProfileSource.activationCode,
      isCurrentlyActive: false,
      deviceName: null,
      devicePlatform: null,
      note: null,
      reminderDaysBefore: 3,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory EsimProfile.fromJson(Map<String, Object?> json) {
    return EsimProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名 eSIM',
      carrierName: json['carrierName'] as String?,
      countryOrRegion: json['countryOrRegion'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      iccid: json['iccid'] as String?,
      rawActivationCode: json['rawActivationCode'] as String?,
      smdpAddress: json['smdpAddress'] as String?,
      matchingId: json['matchingId'] as String?,
      dataLimitMb: json['dataLimitMb'] as int?,
      usedDataMb: json['usedDataMb'] as int?,
      activationDate: _dateFromJson(json['activationDate'] as String?),
      expiryDate: _dateFromJson(json['expiryDate'] as String?),
      status: _statusFromJson(json['status'] as String?),
      source: _sourceFromJson(json['source'] as String?),
      isCurrentlyActive: json['isCurrentlyActive'] as bool? ?? false,
      deviceName: json['deviceName'] as String?,
      devicePlatform: json['devicePlatform'] as String?,
      note: json['note'] as String?,
      reminderDaysBefore: json['reminderDaysBefore'] as int? ?? 3,
      createdAt: _dateFromJson(json['createdAt'] as String?) ?? DateTime.now(),
      updatedAt: _dateFromJson(json['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'carrierName': carrierName,
      'countryOrRegion': countryOrRegion,
      'phoneNumber': phoneNumber,
      'iccid': iccid,
      'rawActivationCode': rawActivationCode,
      'smdpAddress': smdpAddress,
      'matchingId': matchingId,
      'dataLimitMb': dataLimitMb,
      'usedDataMb': usedDataMb,
      'activationDate': activationDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'status': status.name,
      'source': source.name,
      'isCurrentlyActive': isCurrentlyActive,
      'deviceName': deviceName,
      'devicePlatform': devicePlatform,
      'note': note,
      'reminderDaysBefore': reminderDaysBefore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EsimProfile copyWith({
    String? id,
    String? name,
    String? carrierName,
    String? countryOrRegion,
    String? phoneNumber,
    String? iccid,
    String? rawActivationCode,
    String? smdpAddress,
    String? matchingId,
    int? dataLimitMb,
    int? usedDataMb,
    DateTime? activationDate,
    DateTime? expiryDate,
    EsimProfileStatus? status,
    EsimProfileSource? source,
    bool? isCurrentlyActive,
    String? deviceName,
    String? devicePlatform,
    String? note,
    int? reminderDaysBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EsimProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      carrierName: carrierName ?? this.carrierName,
      countryOrRegion: countryOrRegion ?? this.countryOrRegion,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      iccid: iccid ?? this.iccid,
      rawActivationCode: rawActivationCode ?? this.rawActivationCode,
      smdpAddress: smdpAddress ?? this.smdpAddress,
      matchingId: matchingId ?? this.matchingId,
      dataLimitMb: dataLimitMb ?? this.dataLimitMb,
      usedDataMb: usedDataMb ?? this.usedDataMb,
      activationDate: activationDate ?? this.activationDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      source: source ?? this.source,
      isCurrentlyActive: isCurrentlyActive ?? this.isCurrentlyActive,
      deviceName: deviceName ?? this.deviceName,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      note: note ?? this.note,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime? _dateFromJson(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

EsimProfileStatus _statusFromJson(String? value) {
  return EsimProfileStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => EsimProfileStatus.notInstalled,
  );
}

EsimProfileSource _sourceFromJson(String? value) {
  return EsimProfileSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => EsimProfileSource.manualInstalled,
  );
}

String _noteForDiscovered(DiscoveredEsim discovered) {
  final esimType = discovered.isEmbedded == true ? '系统识别为 eSIM' : '系统蜂窝套餐';
  final activeLabel = discovered.isActive == false ? '未启用/系统可见' : '当前启用';
  final confidence = switch (discovered.confidence) {
    DiscoveryConfidence.high => '高',
    DiscoveryConfidence.medium => '中',
    DiscoveryConfidence.low => '低',
    DiscoveryConfidence.unknown => '未知',
  };
  return '$esimType，$activeLabel，识别可信度：$confidence。请确认有效期、流量和号码等信息。';
}
