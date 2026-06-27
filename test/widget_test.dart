import 'dart:convert';

import 'package:esim_tool/main.dart';
import 'package:esim_tool/models/esim_profile.dart';
import 'package:esim_tool/repositories/esim_profile_repository.dart';
import 'package:esim_tool/services/esim_reminder_scheduler.dart';
import 'package:esim_tool/services/installed_esim_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows automatic discovery fallback entry points', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ESIM 管家'), findsOneWidget);
    expect(find.text('SIM 列表'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    expect(find.text('暂无 SIM/eSIM 记录，点右下角添加或自动获取。'), findsOneWidget);
  });

  testWidgets('profile detail edits are saved back to local storage', (
    tester,
  ) async {
    final profile = _profile(name: '旧名字');
    SharedPreferences.setMockInitialValues(<String, Object>{
      EsimProfileRepository.storageKey: jsonEncode(<Object?>[profile.toJson()]),
    });

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧名字'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '新名字');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.text('新名字'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(EsimProfileRepository.storageKey)!;
    expect(stored, contains('新名字'));
  });

  testWidgets('home list can delete a profile record', (tester) async {
    final profile = _profile(name: '可删除日本卡');
    SharedPreferences.setMockInitialValues(<String, Object>{
      EsimProfileRepository.storageKey: jsonEncode(<Object?>[profile.toJson()]),
    });

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('可删除日本卡'), findsOneWidget);
    await tester.tap(find.byTooltip('删除').first);
    await tester.pumpAndSettle();
    expect(find.text('删除 可删除日本卡？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('可删除日本卡'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(EsimProfileRepository.storageKey), '[]');
  });

  testWidgets('home highlights keep-alive consumption reminders', (
    tester,
  ) async {
    final profile = _profile(
      name: '日本保号卡',
      lastServiceDate: DateTime.now().subtract(const Duration(days: 175)),
      serviceIntervalMonths: 6,
      serviceReminderEnabled: true,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      EsimProfileRepository.storageKey: jsonEncode(<Object?>[profile.toJson()]),
    });

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要关注'), findsOneWidget);
    expect(find.textContaining('需要消费保号'), findsWidgets);
  });

  testWidgets('activation code is redacted until user asks to reveal it', (
    tester,
  ) async {
    final profile = _profile(
      name: '待安装日本卡',
      rawActivationCode: r'LPA:1$smdp.example.com$SECRET-MATCHING-ID',
      smdpAddress: 'smdp.example.com',
      matchingId: 'SECRET-MATCHING-ID',
      status: EsimProfileStatus.notInstalled,
      source: EsimProfileSource.activationCode,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      EsimProfileRepository.storageKey: jsonEncode(<Object?>[profile.toJson()]),
    });

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('待安装日本卡'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待安装日本卡'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.textContaining('SECRET-MATCHING-ID'), findsNothing);
    expect(find.textContaining('••••'), findsOneWidget);

    await tester.tap(find.text('显示激活码'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SECRET-MATCHING-ID'), findsOneWidget);
  });

  testWidgets('scan QR imports an LPA code as a pending profile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final secureStore = InMemorySensitiveProfileStore();
    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: secureStore,
        reminderNotifier: const NoopEsimReminderNotifier(),
        qrCodeScanner: (_) async => r'LPA:1$smdp.example.com$QR-MATCHING-ID',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫描二维码'));
    await tester.pumpAndSettle();

    expect(find.text('二维码 eSIM'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(EsimProfileRepository.storageKey)!;
    expect(stored, isNot(contains('QR-MATCHING-ID')));
    expect(
      secureStore.values.values,
      contains(r'LPA:1$smdp.example.com$QR-MATCHING-ID'),
    );
  });

  testWidgets('invalid QR content shows a friendly error instead of saving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
        qrCodeScanner: (_) async => 'not an esim qr',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫描二维码'));
    await tester.pumpAndSettle();

    expect(find.textContaining('没有识别到有效的 LPA eSIM 激活码'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(EsimProfileRepository.storageKey), isNull);
  });

  testWidgets(
    'JSON string import replaces the whole profile list and persists',
    (tester) async {
      final oldProfile = _profile(name: '旧列表卡');
      final importedProfile = _profile(name: '导入日本卡');
      SharedPreferences.setMockInitialValues(<String, Object>{
        EsimProfileRepository.storageKey: jsonEncode(<Object?>[
          oldProfile.toJson(),
        ]),
      });

      await tester.pumpWidget(
        EsimToolApp(
          discovery: const NoopInstalledEsimDiscovery(),
          sensitiveStore: InMemorySensitiveProfileStore(),
          reminderNotifier: const NoopEsimReminderNotifier(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('导入导出'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从 JSON 字符串导入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '粘贴 JSON 字符串'),
        jsonEncode(<String, Object?>{
          'schema': 'esim_tool_profiles_v1',
          'profiles': <Object?>[importedProfile.toJson()],
        }),
      );
      await tester.tap(find.widgetWithText(FilledButton, '替换整个列表'));
      await tester.pumpAndSettle();

      expect(find.text('旧列表卡'), findsNothing);
      expect(find.text('导入日本卡'), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(EsimProfileRepository.storageKey),
        contains('导入日本卡'),
      );
    },
  );

  testWidgets('JSON export string can be copied and edited', (tester) async {
    final profile = _profile(name: '可导出卡');
    SharedPreferences.setMockInitialValues(<String, Object>{
      EsimProfileRepository.storageKey: jsonEncode(<Object?>[profile.toJson()]),
    });

    await tester.pumpWidget(
      EsimToolApp(
        discovery: const NoopInstalledEsimDiscovery(),
        sensitiveStore: InMemorySensitiveProfileStore(),
        reminderNotifier: const NoopEsimReminderNotifier(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入导出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看/复制 JSON 字符串'));
    await tester.pumpAndSettle();

    expect(find.text('整表 JSON'), findsOneWidget);
    expect(find.textContaining('esim_tool_profiles_v1'), findsOneWidget);
    expect(find.textContaining('可导出卡'), findsAtLeastNWidgets(1));
  });
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

class NoopInstalledEsimDiscovery extends InstalledEsimDiscovery {
  const NoopInstalledEsimDiscovery();

  @override
  Future<EsimDiscoveryResult> discoverInstalledEsims() async {
    return const EsimDiscoveryResult(
      supported: true,
      permissionGranted: true,
      profiles: <DiscoveredEsim>[],
      failureReason: EsimDiscoveryFailureReason.noProfilesFound,
      note: 'No profiles in widget tests.',
    );
  }
}

EsimProfile _profile({
  String name = '日本 7 天卡',
  String? rawActivationCode,
  String? smdpAddress,
  String? matchingId,
  DateTime? lastServiceDate,
  int? serviceIntervalMonths = 6,
  bool serviceReminderEnabled = false,
  EsimProfileStatus status = EsimProfileStatus.installed,
  EsimProfileSource source = EsimProfileSource.manualInstalled,
}) {
  return EsimProfile(
    id: 'manual-1',
    name: name,
    carrierName: 'Ubigi',
    countryOrRegion: 'JP',
    phoneNumber: null,
    iccid: null,
    rawActivationCode: rawActivationCode,
    smdpAddress: smdpAddress,
    matchingId: matchingId,
    lastServiceDate: lastServiceDate,
    serviceIntervalMonths: serviceIntervalMonths,
    serviceReminderEnabled: serviceReminderEnabled,
    status: status,
    source: source,
    isCurrentlyActive: false,
    note: null,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );
}
