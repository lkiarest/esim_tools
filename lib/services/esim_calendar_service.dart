import 'package:flutter/services.dart';

class EsimCalendarService {
  const EsimCalendarService._();

  static const MethodChannel _channel = MethodChannel('esim_tool/calendar');

  static Future<bool> addExpiryEvent({
    required String profileName,
    required DateTime expiryDate,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('addExpiryEvent', {
        'profileName': profileName,
        'expiryDateMillis': expiryDate.millisecondsSinceEpoch,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
