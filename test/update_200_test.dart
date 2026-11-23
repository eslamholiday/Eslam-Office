import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/experience.dart';
import 'package:eslam_office/experience_settings.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/pages.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/visual_system.dart';

Widget host(
  Widget page, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: packTheme(brightness, displayPreferences),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  tearDown(() => displayPreferences = {});

  test('unknown pack falls back to a complete light and dark identity', () {
    displayPreferences = {'visualPack': 'future-unavailable'};
    expect(activePack.id, 'clay');
    expect(
      packTheme(Brightness.light, displayPreferences).brightness,
      Brightness.light,
    );
    expect(
      packTheme(Brightness.dark, displayPreferences).brightness,
      Brightness.dark,
    );
    expect(activePack.icons, isNot(activePack.scenes));
    expect(activePack.fieldRadius, greaterThan(0));
  });

  test(
    'experience preferences survive reopen without changing ledger or input customization',
    () async {
      final dir = await Directory.systemTemp.createTemp('money-2-upgrade-');
      final path = '${dir.path}/office.db';
      var s = await Store.open(factory: databaseFactoryFfi, path: path);
      final customer = await s.saveParty({
        'kind': 'customer',
        'name': 'حساب محفوظ',
      });
      final id = await s.saveEntry({
        'kind': 'visa',
        'currency': 'USD',
        'date': '2026-11-23',
        'customer': customer,
        'qty': 1,
        'sell': 15375,
        'costUnit': 10000,
        'posted': true,
      });
      await s.set('input_ticket', {
        'fields': {
          'country': {'mode': 'hidden', 'label': 'الدولة المخصصة'},
        },
      });
      await s.set('navOrder', ['settings', 'home', 'statements', 'customers']);
      final ledger = await s.db.query('ledger');
      for (final p in <String, dynamic>{
        'visualPack': 'clay',
        'appearanceMode': 'dark',
        'soundEnabled': false,
        'soundVolume': .4,
        'hapticIntensity': .2,
        'swipeCards': false,
        'reduceMotion': true,
      }.entries) {
        await s.set(p.key, p.value);
      }
      await s.flushSettings();
      await s.db.close();
      s = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(await s.db.query('ledger'), ledger);
      expect(s.entries.single.id, id);
      expect(s.entries.single.sale, 15375);
      expect(await s.balance(customer, Currency.USD), 15375);
      expect(
        (s.settings['input_ticket']['fields']['country'])['mode'],
        'hidden',
      );
      expect(s.settings['soundEnabled'], false);
      expect(s.settings['appearanceMode'], 'dark');
      expect(s.settings['navOrder'].first, 'settings');
      await s.db.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'disabled feedback is silent, previews are independent, and values are clamped',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Experience.channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Experience.channel, null),
      );
      displayPreferences = {
        'soundEnabled': false,
        'hapticEnabled': false,
        'soundVolume': 7,
        'hapticIntensity': -2,
        'soundStyle': 'unknown',
      };
      await Experience.fire('save');
      expect(calls, isEmpty);
      await Experience.fire('save', preview: 'sound');
      expect(calls.single.arguments['sound'], true);
      expect(calls.single.arguments['haptic'], false);
      expect(calls.single.arguments['volume'], 1);
      expect(calls.single.arguments['style'], 'soft');
      calls.clear();
      await Experience.fire('save', preview: 'haptic');
      expect(calls.single.arguments['sound'], false);
      expect(calls.single.arguments['haptic'], true);
      expect(calls.single.arguments['intensity'], 0);
    },
  );

  testWidgets(
    'appearance remains usable in dark mode with larger Arabic text',
    (t) async {
      t.view.physicalSize = const Size(393, 980);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      await t.runAsync(() => s.set('liteGraphics', true));
      await t.pumpWidget(
        host(PackAppearancePage(s), brightness: Brightness.dark, scale: 1.3),
      );
      await t.pumpAndSettle();
      expect(find.text('حزم الأشكال والمظهر'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(s.flushSettings);
      await t.runAsync(() => s.db.close());
    },
  );

  testWidgets(
    'swiping a posted ticket reveals actions without altering or posting money',
    (t) async {
      t.view.physicalSize = const Size(430, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      await t.runAsync(() async {
        final customer = await s.saveParty({
          'kind': 'customer',
          'name': 'زبون',
        });
        await s.saveEntry({
          'kind': 'ticket',
          'currency': 'USD',
          'date': '2026-11-23',
          'customer': customer,
          'q0': 1,
          'base0': 10000,
          'gross0': 11000,
          'sell0': 15000,
          'posted': true,
        });
      });
      final before = (await t.runAsync(() => s.db.query('ledger')))!;
      await t.pumpWidget(
        host(
          Scaffold(body: ListView(children: [EntryTile(s, s.entries.single)])),
        ),
      );
      await t.pumpAndSettle();
      await t.drag(find.byType(EntryTile), const Offset(170, 0));
      await t.pumpAndSettle();
      expect(find.text('تعديل العملية'), findsOneWidget);
      expect((await t.runAsync(() => s.db.query('ledger'))), before);
      expect(find.byType(EntryForm), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(s.flushSettings);
      await t.runAsync(() => s.db.close());
    },
  );

  testWidgets('feedback controls render offline in all three tabs', (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = (await t.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    await t.pumpWidget(host(ExperienceSettingsPage(s)));
    await t.pumpAndSettle();
    expect(find.text('تفعيل المؤثرات الصوتية'), findsOneWidget);
    await t.tap(find.widgetWithText(Tab, 'الاهتزاز'));
    await t.pumpAndSettle();
    expect(find.text('تفعيل الاهتزاز'), findsOneWidget);
    await t.tap(find.widgetWithText(Tab, 'الإيماءات'));
    await t.pumpAndSettle();
    expect(find.text('السحب على بطاقة العملية'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(s.flushSettings);
    await t.runAsync(() => s.db.close());
  });
}
