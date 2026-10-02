import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/main.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/pages.dart';
import 'package:eslam_office/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('offline empty startup, screen renders and search opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = (await tester.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: OfficeApp(s)));
    await tester.pumpAndSettle();
    expect(find.text('أهلًا إسلام'), findsOneWidget);
    expect(find.text('نظرة على الحسابات'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/eslam-home.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
    await tester.tap(find.byTooltip('البحث الموحّد'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => s.db.close());
  });
  testWidgets('ticket form shows quantities and optional child sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = (await tester.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    await tester.pumpWidget(OfficeApp(s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تذكرة جديدة'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryForm), findsOneWidget);
    expect(find.text('حفظ واعتماد'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => s.db.close());
  });
}
