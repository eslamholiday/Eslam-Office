import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:eslam_office/statement_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all legacy image qualities export at 300 DPI or higher', () {
    for (final value in [null, 144, 180, 240, 300, 0, 'invalid']) {
      expect(statementImageDpi(value), 300);
    }
    expect(statementImageDpi(400), 400);
  });

  test('saved PNG has white opaque background and preserves ink and size', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(2, 2, 2, 2),
      ui.Paint()..color = const ui.Color(0xff000000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(4, 2, 2, 2),
      ui.Paint()..color = const ui.Color(0xff123b5d),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(2, 4, 2, 2),
      ui.Paint()..color = const ui.Color(0x80000000),
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(8, 8);
    final sourceBytes = (await source.toByteData(format: ui.ImageByteFormat.png))!;
    final png = await whiteStatementPng(sourceBytes.buffer.asUint8List());
    source.dispose();
    picture.dispose();
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 8);
    expect(image.height, 8);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer.asUint8List();
    List<int> pixel(int x, int y) => bytes.sublist((y * 8 + x) * 4, (y * 8 + x) * 4 + 4);
    expect(pixel(0, 0), [255, 255, 255, 255]);
    expect(pixel(7, 7), [255, 255, 255, 255]);
    expect(pixel(2, 2), [0, 0, 0, 255]);
    expect(pixel(4, 2), [18, 59, 93, 255]);
    expect(pixel(2, 4)[0], inInclusiveRange(126, 128));
    for (var i = 3; i < bytes.length; i += 4) {
      expect(bytes[i], 255);
    }
    image.dispose();
    codec.dispose();
  });
}
