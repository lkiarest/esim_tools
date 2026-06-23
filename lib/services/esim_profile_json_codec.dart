import 'dart:convert';

import '../models/esim_profile.dart';

class EsimProfileJsonCodec {
  static const String schema = 'esim_tool_profiles_v1';

  const EsimProfileJsonCodec._();

  static String encode(List<EsimProfile> profiles) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<String, Object?>{
      'schema': schema,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
    });
  }

  static List<EsimProfile> decode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('JSON 内容为空');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      throw FormatException('JSON 格式不正确：${error.message}');
    }

    final Object? rawProfiles = switch (decoded) {
      final List<Object?> list => list,
      final Map<String, Object?> map => map['profiles'],
      _ => throw const FormatException('JSON 顶层必须是对象或数组'),
    };

    if (rawProfiles is! List) {
      throw const FormatException('profiles 必须是数组');
    }

    return rawProfiles.asMap().entries.map((entry) {
      final index = entry.key;
      final rawProfile = entry.value;
      if (rawProfile is! Map<String, Object?>) {
        throw FormatException('第 ${index + 1} 条记录必须是 JSON 对象');
      }
      _validateProfileJson(rawProfile, index);
      return EsimProfile.fromJson(rawProfile);
    }).toList(growable: false);
  }

  static void _validateProfileJson(Map<String, Object?> json, int index) {
    final row = '第 ${index + 1} 条记录';
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.trim().isEmpty) {
      throw FormatException('$row 缺少 id');
    }
    if (name is! String || name.trim().isEmpty) {
      throw FormatException('$row 缺少 name');
    }
    for (final field in <String>['serviceIntervalMonths']) {
      final value = json[field];
      if (value != null && value is! int) {
        throw FormatException('$row 的 $field 必须是整数或 null');
      }
    }
    final serviceReminderEnabled = json['serviceReminderEnabled'];
    if (serviceReminderEnabled != null && serviceReminderEnabled is! bool) {
      throw FormatException('$row 的 serviceReminderEnabled 必须是布尔值');
    }
    for (final field in <String>[
      'lastServiceDate',
      'createdAt',
      'updatedAt',
    ]) {
      final value = json[field];
      if (value != null && (value is! String || DateTime.tryParse(value) == null)) {
        throw FormatException('$row 的 $field 必须是 ISO 日期字符串或 null');
      }
    }
    final status = json['status'];
    if (status != null &&
        (status is! String ||
            !EsimProfileStatus.values.any((item) => item.name == status))) {
      throw FormatException('$row 的 status 不合法');
    }
    final source = json['source'];
    if (source != null &&
        (source is! String ||
            !EsimProfileSource.values.any((item) => item.name == source))) {
      throw FormatException('$row 的 source 不合法');
    }
  }
}
