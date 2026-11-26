import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/input_schema.dart';
import 'package:eslam_office/live_statement.dart';
import 'package:eslam_office/visual_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'service metadata edits keep the entry ID and financial totals',
    () async {
      final s = await Store.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final customer = await s.saveParty({'kind': 'customer', 'name': 'عميل'});
      final id = await s.saveEntry({
        'kind': 'visa',
        'currency': 'USD',
        'date': '2026-11-26',
        'customer': customer,
        'qty': 1,
        'sell': 40000,
        'costUnit': 35000,
        'visaStatus': 'review',
        'documentStatus': 'missing',
        'missingDocuments': 'صورة الجواز',
        'internalNote': 'ملاحظة المكتب',
        'dueDate': '2026-12-01',
        'posted': true,
      });
      final before = await s.summary(s.entries.single.currency);
      final data = {
        ...s.entries.single.data,
        'visaStatus': 'issued',
        'documentStatus': 'complete',
      };
      expect(await s.saveEntry(data, id: id), id);
      expect(s.entries.length, 1);
      expect(s.entries.single.data['internalNote'], 'ملاحظة المكتب');
      expect(await s.summary(s.entries.single.currency), before);
      expect(inputSpecs('ticket').any((f) => f.key == 'baggage'), isTrue);
      expect(inputSpecs('hotel').any((f) => f.key == 'breakfast'), isTrue);
      expect(visualPacks.containsKey('office'), isFalse);
      await s.db.close();
    },
  );

  testWidgets('live preview debounces edits and rejects late old renders', (
    t,
  ) async {
    final old = Completer<Uint8List>();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6M0sAAAAASUVORK5CYII=',
    );
    var renderCount = 0;
    Widget view(
      String revision,
      Future<Uint8List> Function()? build, {
      String? error,
    }) => MaterialApp(
      home: Scaffold(
        body: LiveStatementPreview(
          fingerprint: revision,
          buildPdf: build,
          error: error,
          onOpen: () {},
          rasterize: (bytes) async {
            renderCount++;
            return [png];
          },
        ),
      ),
    );
    await t.pumpWidget(view('old', () => old.future));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpWidget(view('new', () async => Uint8List.fromList([2])));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(renderCount, 1);
    old.complete(Uint8List.fromList([1]));
    await t.pumpAndSettle();
    expect(renderCount, 1);
    expect(find.byType(Image), findsOneWidget);
    await t.pumpWidget(view('invalid', null, error: 'أدخل سعر الصرف'));
    await t.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('أدخل سعر الصرف'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
