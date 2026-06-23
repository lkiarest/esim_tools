import 'package:flutter/services.dart';

class EsimJsonFileTransfer {
  const EsimJsonFileTransfer({
    MethodChannel channel = const MethodChannel('esim_tool/json_file_transfer'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<String?> importJsonFile() async {
    try {
      return await _channel.invokeMethod<String>('importJsonFile');
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> exportJsonFile(String json, {String fileName = 'esim-profiles.json'}) async {
    try {
      return await _channel.invokeMethod<bool>('exportJsonFile', <String, Object?>{
            'json': json,
            'fileName': fileName,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
