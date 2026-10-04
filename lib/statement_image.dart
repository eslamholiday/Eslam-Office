import 'dart:typed_data';
import 'dart:ui' as ui;

/// Old quality settings are upgraded without changing any accounting data.
int statementImageDpi(Object? setting) => setting == 400 ? 400 : 300;

/// Flatten transparency onto white before saving to either app storage or Gallery.
/// Some Android image viewers display transparent page areas as black.
Future<Uint8List> whiteStatementPng(Uint8List source) async {
  final codec = await ui.instantiateImageCodec(source);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      final picture = recorder.endRecording();
      try {
        final opaque = await picture.toImage(image.width, image.height);
        try {
          final bytes = await opaque.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('تعذر إنشاء صورة الكشف');
          return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
        } finally {
          opaque.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
