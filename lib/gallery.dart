import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class Gallery {
  static const channel = MethodChannel('eslam_money/gallery');
  static String safeName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();
  static Future<bool> save(
    Uint8List bytes,
    String name, {
    String album = 'Eslam Money',
  }) async {
    if (Platform.isAndroid) {
      try {
        await channel.invokeMethod<String>('saveImage', {
          'bytes': bytes,
          'name': safeName(name),
          'album': album,
        });
        return true;
      } on PlatformException catch (e) {
        if (e.code != 'LEGACY') rethrow;
      }
    }
    return await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ صورة الكشف على الهاتف',
          fileName: safeName(name),
          type: FileType.custom,
          allowedExtensions: ['png'],
          bytes: bytes,
        ) !=
        null;
  }
}
