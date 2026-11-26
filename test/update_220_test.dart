import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/main.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/pages.dart';
import 'package:eslam_office/settings.dart';
import 'package:eslam_office/reports.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/labels.dart';
import 'package:eslam_office/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'clay migration preserves ledger, then respects a later theme choice',
    () async {
      final dir = await Directory.systemTemp.createTemp('office-22-');
      final path = '${dir.path}/office.db';
      var s = await Store.open(factory: databaseFactoryFfi, path: path);
      final customer = await s.saveParty({
        'kind': 'customer',
        'name': 'زبون محفوظ',
      });
      await s.saveEntry({
        'kind': 'opening',
        'currency': 'IQD',
        'date': '2026-11-26',
        'customer': customer,
        'partyType': 'customer',
        'amount': 300000,
        'direction': 1,
        'posted': true,
      });
      await s.db.delete('settings', where: 'key=?', whereArgs: ['clay23']);
      final before = await s.db.query('ledger');
      await s.db.close();
      s = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(s.settings['visualPack'], 'clay');
      expect(await s.db.query('ledger'), before);
      await s.set('visualPack', 'glass');
      await s.db.close();
      s = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(s.settings['visualPack'], 'glass');
      expect(await s.db.query('ledger'), before);
      await s.db.close();
      await dir.delete(recursive: true);
    },
  );

  testWidgets('selected workflows render across all packs at phone width', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = (await t.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    final customer = (await t.runAsync(
      () => s.saveParty({'kind': 'customer', 'name': 'أحمد علي'}),
    ))!;
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    Future<void> mount(Widget page, {String? screenshot}) async {
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: packTheme(Brightness.light, s.settings),
            home: LabelScope(
              notifier: s,
              child: OfficeSurface(material: 0, child: page),
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      if (screenshot != null) {
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await boundary.toImage(pixelRatio: 2);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/eslam-22-$screenshot.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        });
      }
      await t.pumpWidget(const SizedBox());
    }

    for (final pack in visualPacks.keys) {
      await t.runAsync(() => s.set('visualPack', pack));
      await mount(
        SettingsPage(s),
        screenshot: pack == 'office' ? 'settings' : null,
      );
      await mount(EntriesPage(s));
      await mount(
        EntryForm(s, 'ticket', party: customer),
        screenshot: pack == 'office' ? 'ticket' : null,
      );
      await mount(StatementPage(s, customer));
    }
    await t.runAsync(() => s.set('visualPack', 'clay'));
    await mount(HomePage(s), screenshot: 'home');
    await t.runAsync(() => s.db.close());
  });

  testWidgets(
    'explicit personal statement settings do not change the global default',
    (t) async {
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      final customer = (await t.runAsync(
        () => s.saveParty({'kind': 'customer', 'name': 'حساب خاص'}),
      ))!;
      await t.runAsync(() => s.set('statementMode', 'original'));
      await t.pumpWidget(OfficeApp(s));
      Navigator.of(
        t.element(find.byType(Shell)),
      ).push(MaterialPageRoute(builder: (_) => StatementPage(s, customer)));
      await t.pumpAndSettle();
      final switcher = find.widgetWithText(SwitchListTile, 'تخصيص لهذا الزبون');
      await t.ensureVisible(switcher);
      await t.runAsync(() async {
        await t.tap(switcher);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(s.settings['statementScoped_$customer'], isA<Map>());
      expect(s.settings['statementMode'], 'original');
      await t.runAsync(() async {
        await t.tap(switcher);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(s.settings['statementScoped_$customer'], isNull);
      expect(s.settings['statementMode'], 'original');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() => s.db.close());
    },
  );
}
