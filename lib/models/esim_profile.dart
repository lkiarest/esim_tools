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
    this.systemIdentifier,
    required this.rawActivationCode,
    required this.smdpAddress,
    required this.matchingId,
    required this.lastServiceDate,
    this.serviceIntervalMonths = 6,
    this.serviceReminderEnabled = true,
    required this.status,
    required this.source,
    required this.isCurrentlyActive,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? carrierName;
  final String? countryOrRegion;
  final String? phoneNumber;
  final String? iccid;
  final String? systemIdentifier;
  final String? rawActivationCode;
  final String? smdpAddress;
  final String? matchingId;

  /// 最近一次为保号发生的消费/充值/短信等日期。
  final DateTime? lastServiceDate;

  /// 保号消费周期（月）；null 表示不提醒。
  final int? serviceIntervalMonths;
  final bool serviceReminderEnabled;

  final EsimProfileStatus status;
  final EsimProfileSource source;
  final bool isCurrentlyActive;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime? get nextServiceDate {
    final last = lastServiceDate;
    final months = serviceIntervalMonths;
    if (!serviceReminderEnabled ||
        last == null ||
        months == null ||
        months <= 0) {
      return null;
    }
    return _addMonths(_dateOnly(last), months);
  }

  int? daysUntilService(DateTime now) {
    final next = nextServiceDate;
    if (next == null) return null;
    return _dateOnly(next).difference(_dateOnly(now)).inDays;
  }

  bool isServiceDueSoon(DateTime now, {int thresholdDays = 14}) {
    if (status == EsimProfileStatus.archived) return false;
    final days = daysUntilService(now);
    return days != null && days >= 0 && days <= thresholdDays;
  }

  bool isServiceOverdue(DateTime now) {
    if (status == EsimProfileStatus.archived) return false;
    final days = daysUntilService(now);
    return days != null && days < 0;
  }

  EsimProfileStatus effectiveStatus(DateTime now) {
    if (status == EsimProfileStatus.archived) return EsimProfileStatus.archived;
    return status;
  }

  List<String> attentionMessages(DateTime now) {
    final messages = <String>[];
    final days = daysUntilService(now);
    if (days != null) {
      if (days < 0) {
        messages.add('已到保号消费时间');
      } else if (days == 0) {
        messages.add('今天需要消费保号');
      } else if (days <= 14) {
        messages.add('$days 天后需要消费保号');
      }
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
      systemIdentifier: discovered.systemIdentifier,
      rawActivationCode: null,
      smdpAddress: null,
      matchingId: null,
      lastServiceDate: null,
      serviceIntervalMonths: 6,
      serviceReminderEnabled: false,
      status: EsimProfileStatus.installed,
      source: EsimProfileSource.systemDiscovered,
      isCurrentlyActive: discovered.isActive ?? false,
      note: null,
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
      systemIdentifier: null,
      rawActivationCode: parsed.raw,
      smdpAddress: parsed.smdpAddress,
      matchingId: parsed.matchingId,
      lastServiceDate: null,
      serviceIntervalMonths: 6,
      serviceReminderEnabled: false,
      status: EsimProfileStatus.notInstalled,
      source: EsimProfileSource.activationCode,
      isCurrentlyActive: false,
      note: null,
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
      systemIdentifier: json['systemIdentifier'] as String?,
      rawActivationCode: json['rawActivationCode'] as String?,
      smdpAddress: json['smdpAddress'] as String?,
      matchingId: json['matchingId'] as String?,
      lastServiceDate: _dateFromJson(json['lastServiceDate'] as String?),
      serviceIntervalMonths: json['serviceIntervalMonths'] as int? ?? 6,
      serviceReminderEnabled: json['serviceReminderEnabled'] as bool? ?? false,
      status: _statusFromJson(json['status'] as String?),
      source: _sourceFromJson(json['source'] as String?),
      isCurrentlyActive: json['isCurrentlyActive'] as bool? ?? false,
      note: json['note'] as String?,
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
      'systemIdentifier': systemIdentifier,
      'rawActivationCode': rawActivationCode,
      'smdpAddress': smdpAddress,
      'matchingId': matchingId,
      'lastServiceDate': lastServiceDate?.toIso8601String(),
      'serviceIntervalMonths': serviceIntervalMonths,
      'serviceReminderEnabled': serviceReminderEnabled,
      'status': status.name,
      'source': source.name,
      'isCurrentlyActive': isCurrentlyActive,
      'note': note,
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
    String? systemIdentifier,
    String? rawActivationCode,
    String? smdpAddress,
    String? matchingId,
    DateTime? lastServiceDate,
    int? serviceIntervalMonths,
    bool? serviceReminderEnabled,
    EsimProfileStatus? status,
    EsimProfileSource? source,
    bool? isCurrentlyActive,
    String? note,
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
      systemIdentifier: systemIdentifier ?? this.systemIdentifier,
      rawActivationCode: rawActivationCode ?? this.rawActivationCode,
      smdpAddress: smdpAddress ?? this.smdpAddress,
      matchingId: matchingId ?? this.matchingId,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      serviceIntervalMonths:
          serviceIntervalMonths ?? this.serviceIntervalMonths,
      serviceReminderEnabled:
          serviceReminderEnabled ?? this.serviceReminderEnabled,
      status: status ?? this.status,
      source: source ?? this.source,
      isCurrentlyActive: isCurrentlyActive ?? this.isCurrentlyActive,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _addMonths(DateTime value, int months) {
  final targetMonth = value.month + months;
  final targetYear = value.year + ((targetMonth - 1) ~/ 12);
  final normalizedMonth = ((targetMonth - 1) % 12) + 1;
  final day = value.day.clamp(1, _daysInMonth(targetYear, normalizedMonth));
  return DateTime.utc(targetYear, normalizedMonth, day);
}

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

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
