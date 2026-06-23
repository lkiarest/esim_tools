import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares camera permission for QR scanning', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.CAMERA'));
  });

  test(
    'Android declares notification permissions and receivers for reminders',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('ScheduledNotificationReceiver'));
      expect(manifest, contains('ScheduledNotificationBootReceiver'));
    },
  );

  test('iOS explains camera permission for QR scanning', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('NSCameraUsageDescription'));
    expect(infoPlist, contains('扫描 eSIM 二维码'));
  });
}
