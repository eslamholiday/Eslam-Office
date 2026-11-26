import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One cached atlas, shared by every office surface. No per-frame decoding.
class OfficeSurface extends StatelessWidget {
  final int material;
  final Widget child;
  final BorderRadius? radius;
  final bool stitched;
  const OfficeSurface({
    super.key,
    required this.child,
    this.material = 2,
    this.radius,
    this.stitched = false,
  });
  static Future<ui.Image>? _image;
  static Future<ui.Image> load() => _image ??= () async {
    final data = await rootBundle.load('assets/visuals/office/materials.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }();
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: radius ?? BorderRadius.zero,
    child: FutureBuilder<ui.Image>(
      future: load(),
      builder: (_, result) => CustomPaint(
        painter: _MaterialPainter(
          result.data,
          material,
          Theme.of(context).brightness == Brightness.dark,
          stitched,
        ),
        child: child,
      ),
    ),
  );
}

class _MaterialPainter extends CustomPainter {
  final ui.Image? image;
  final int material;
  final bool dark, stitched;
  _MaterialPainter(this.image, this.material, this.dark, this.stitched);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    canvas.drawRect(
      rect,
      paint
        ..color = const [
          Color(0xff57311f),
          Color(0xff153e2e),
          Color(0xfff4e8d0),
          Color(0xffb78c4b),
          Color(0xffeee2c8),
          Color(0xff4e2b21),
        ][material],
    );
    if (image != null) {
      final w = image!.width / 3, h = image!.height / 2;
      final source = Rect.fromLTWH(
        (material % 3) * w + 1,
        (material ~/ 3) * h + 1,
        w - 2,
        h - 2,
      );
      canvas.drawImageRect(
        image!,
        source,
        rect,
        paint..color = Colors.white.withValues(alpha: material == 2 ? .55 : .9),
      );
    }
    if (dark) {
      canvas.drawRect(
        rect,
        paint..color = Colors.black.withValues(alpha: material == 2 ? .8 : .35),
      );
    }
    if (stitched && size.width > 20 && size.height > 20) {
      final edge = RRect.fromRectAndRadius(
        rect.deflate(5),
        const Radius.circular(12),
      );
      paint
        ..color = const Color(0xffc6a36a).withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8;
      for (final m in (Path()..addRRect(edge)).computeMetrics()) {
        for (double p = 0; p < m.length; p += 7) {
          canvas.drawPath(m.extractPath(p, p + 3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MaterialPainter old) =>
      old.image != image ||
      old.material != material ||
      old.dark != dark ||
      old.stitched != stitched;
}

/// Decorative barcode deliberately contains no data, no scanner or action.
class DecorativeBarcode extends StatelessWidget {
  const DecorativeBarcode({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(36, 48),
      painter: _BarcodePainter(Theme.of(context).colorScheme.onSurface),
    ),
  );
}

class _BarcodePainter extends CustomPainter {
  final Color color;
  _BarcodePainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color.withValues(alpha: .45);
    double y = 0;
    for (var i = 0; y < s.height; i++) {
      final h = i % 3 == 0 ? 2.0 : 1.0;
      c.drawRect(Rect.fromLTWH(0, y, s.width, h), p);
      y += h + (i % 4 == 0 ? 3 : 1);
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}

/// Small architectural drawings, never used as the source of city identity.
class CityLandmark extends StatelessWidget {
  final String city;
  const CityLandmark(this.city, {super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 38,
      height: 45,
      child: CustomPaint(
        painter: _LandmarkPainter(
          city,
          Theme.of(context).colorScheme.secondary,
        ),
      ),
    ),
  );
}

class _LandmarkPainter extends CustomPainter {
  final String city;
  final Color color;
  _LandmarkPainter(this.city, this.color);
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 40, s.height / 48);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    c.drawLine(const Offset(2, 45), const Offset(38, 45), p);
    if (city.contains('بغداد')) {
      c.drawLine(const Offset(20, 4), const Offset(20, 44), p);
      c.drawOval(const Rect.fromLTWH(11, 15, 18, 6), p);
      c.drawLine(const Offset(14, 21), const Offset(17, 44), p);
      c.drawLine(const Offset(26, 21), const Offset(23, 44), p);
      c.drawRect(const Rect.fromLTWH(28, 30, 7, 14), p);
    } else if (city.contains('عمان') || city.contains('عمّان')) {
      c.drawLine(const Offset(4, 15), const Offset(36, 15), p);
      c.drawLine(const Offset(4, 12), const Offset(36, 12), p);
      for (final x in [8.0, 20.0, 32.0]) {
        c.drawRect(Rect.fromLTWH(x - 2, 16, 4, 26), p);
      }
    } else {
      c.drawRect(const Rect.fromLTWH(5, 25, 8, 19), p);
      c.drawRect(const Rect.fromLTWH(17, 13, 9, 31), p);
      c.drawRect(const Rect.fromLTWH(30, 30, 6, 14), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.city != city || old.color != color;
}
