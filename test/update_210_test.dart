import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/ambient_motion.dart';
import 'package:eslam_office/config_transfer.dart';
import 'package:eslam_office/date_range_field.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/entry_matching.dart';
import 'package:eslam_office/experience.dart';
import 'package:eslam_office/gallery.dart';
import 'package:eslam_office/geography.dart';
import 'package:eslam_office/input_schema.dart';
import 'package:eslam_office/labels.dart';
import 'package:eslam_office/statement_details.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/visual_system.dart';
import 'package:eslam_office/ui.dart' show ChoiceField;

Widget host(Widget child, {Store? store}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: store == null ? child : LabelScope(notifier: store, child: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Store s;
  late int customer, supplier;
  setUp(() async {
    s = await Store.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    customer = await s.saveParty({'kind': 'customer', 'name': 'مكتب الاختبار'});
    supplier = await s.saveParty({'kind': 'supplier', 'name': 'جهة الاختبار'});
  });
  tearDown(() async {
    AmbientRuntime.enabled = false;
    AmbientRuntime.foreground = true;
    await s.flushSettings();
    await s.db.close();
    s.dispose();
    displayPreferences = {};
  });
  Map<String, dynamic> sale({bool posted = true, String currency = 'USD'}) => {
    'kind': 'ticket',
    'date': '2026-11-25',
    'currency': currency,
    'customer': customer,
    'supplier': supplier,
    'posted': posted,
    'pnr': 'ABC123',
    'rate': 500,
    'lines': [
      {'qty': 2, 'base': 10000, 'gross': 12000, 'sell': 13000},
    ],
  };

  test(
    'clearance moves original/refunds atomically and removes both ledger sides',
    () async {
      final original = await s.saveEntry(sale());
      await s.saveEntry({
        'kind': 'refund',
        'date': '2026-11-25',
        'currency': 'USD',
        'posted': true,
        'customer': customer,
        'supplier': supplier,
        'original': original,
        'sale': 1000,
        'cost': 500,
      });
      await s.set('recovery_ticket_$original', sale());
      final before = await s.db.query('ledger');
      expect(await s.balance(customer, Currency.USD), 25000);
      await s.clearToArchive(
        entryIds: {s.entries.firstWhere((e) => e.kind == 'refund').id!},
      );
      expect(s.entries, isEmpty);
      expect(await s.db.query('ledger'), isEmpty);
      expect(await s.balance(customer, Currency.USD), 0);
      expect(await s.balance(supplier, Currency.USD), 0);
      expect((await s.summary(Currency.USD))['profit'], 0);
      expect(s.history(customer), isEmpty);
      expect(s.clearances.single['ledger'], before);
      expect(s.clearances.single['entries'], hasLength(2));
      expect(s.settings.containsKey('recovery_ticket_$original'), false);
      await s.set('recovery_ticket_$original', sale());
      expect(s.settings.containsKey('recovery_ticket_$original'), false);
      final next = await s.saveEntry(sale());
      expect(next, greaterThan(original));
      await expectLater(
        s.saveEntry(sale(), id: original),
        throwsFormatException,
      );
      expect(await s.balance(customer, Currency.USD), 26000);
    },
  );

  test(
    'all-approved clearance leaves drafts and account; retirement cannot be undone',
    () async {
      await s.saveEntry(sale());
      final draft = await s.saveEntry(sale(posted: false, currency: 'IQD'));
      final traveler = await s.saveParty({
        'kind': 'passenger',
        'name': 'مسافر',
        'customer': customer,
      });
      await s.clearToArchive(all: true);
      expect(s.entries.single.id, draft);
      expect(s.list('customer').single['id'], customer);
      await s.clearToArchive(party: customer, retireAccount: true);
      expect(s.entries, isEmpty);
      expect(s.list('customer'), isEmpty);
      expect(s.list('passenger'), isEmpty);
      expect(s.retiredParties, containsAll([customer, traveler]));
      await expectLater(s.archiveParty(customer, false), throwsFormatException);
      await expectLater(
        s.saveParty({'kind': 'customer', 'name': 'استعادة'}, id: customer),
        throwsFormatException,
      );
      await expectLater(s.saveEntry(sale()), throwsFormatException);
      await expectLater(
        s.saveParty({
          'kind': 'passenger',
          'name': 'تابع جديد',
          'customer': customer,
        }),
        throwsFormatException,
      );
      expect(s.clearances, hasLength(2));
    },
  );

  test(
    'clearance rollback is complete and old undo snapshots cannot revive cleared IDs',
    () async {
      final id = await s.saveEntry(sale());
      final old = s.entries.single;
      await s.forceDeleteEntry(old);
      final undo = s.logs.first['id'] as int;
      final snapshot = Map<String, Object?>.from(s.logs.first)..remove('id');
      await s.undoAudit(undo);
      final retainedUndo = await s.db.insert('audit', snapshot);
      await s.clearToArchive(entryIds: {id});
      await expectLater(s.undoAudit(retainedUndo), throwsFormatException);
      expect(s.entries, isEmpty);
      final count = s.clearances.length;
      await expectLater(
        s.clearToArchive(entryIds: {999999}),
        throwsFormatException,
      );
      expect(s.clearances.length, count);
      expect(await s.db.query('ledger'), isEmpty);
    },
  );

  test(
    'version 2 database upgrade preserves ledger, defaults and references',
    () async {
      final dir = await Directory.systemTemp.createTemp('money21-upgrade-');
      final path = '${dir.path}/v2.db';
      var db = await Store.open(factory: databaseFactoryFfi, path: path);
      final party = await db.saveParty({'kind': 'customer', 'name': 'قديم'});
      await db.saveEntry({
        'kind': 'visa',
        'currency': 'USD',
        'date': '2026-11-20',
        'posted': true,
        'customer': party,
        'qty': 1,
        'sell': 12345,
        'costUnit': 10000,
      });
      await db.set('defaults_visa', {'currency': 'USD', 'country': 4});
      final ledger = await db.db.query('ledger'),
          refs = await db.db.query('refs');
      await db.db.execute('DROP TABLE clearance_entries');
      await db.db.execute('DROP TABLE retired_parties');
      await db.db.execute('DROP TABLE clearance_batches');
      await db.db.execute('PRAGMA user_version=2');
      await db.db.close();
      db = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(await db.db.query('ledger'), ledger);
      expect(await db.db.query('refs'), refs);
      expect(await db.balance(party, Currency.USD), 12345);
      expect(db.settings['defaults_visa']['country'], 4);
      expect(db.clearances, isEmpty);
      await db.db.close();
      db.dispose();
      await dir.delete(recursive: true);
    },
  );

  test(
    'offline flags cover countries while preserving saved list counts',
    () async {
      final count = s.refs.length;
      await GeoCatalog.load();
      expect(GeoCatalog.countries.length, greaterThanOrEqualTo(249));
      expect(
        GeoCatalog.countries.map((r) => r['index']).toSet().length,
        GeoCatalog.countries.length,
      );
      expect(GeoCatalog.countryCode('العراق'), 'IQ');
      expect(GeoCatalog.countryCode('Egypt'), 'EG');
      expect(GeoCatalog.countryCode('DE'), 'DE');
      expect(GeoCatalog.infer('city', 'عمان'), 'JO');
      expect(GeoCatalog.infer('country', 'عمان'), 'OM');
      expect(GeoCatalog.infer('city', 'بغداد'), 'IQ');
      expect(GeoCatalog.infer('city', 'مدينة غير معروفة'), isNull);
      expect(
        GeoCatalog.recordCode({
          'kind': 'city',
          'name': 'بغداد',
          'flagCode': '',
        }),
        isNull,
      );
      expect(s.refs.length, count);
      final bytes = await rootBundle.load('assets/flags/atlas.webp');
      expect(bytes.lengthInBytes, greaterThan(100000));
    },
  );

  test(
    'new country only is added and user-selected city association survives renaming',
    () async {
      await GeoCatalog.load();
      final count = s.refs.length;
      await s.saveRef('country', 'ألمانيا', {});
      expect(s.refs.length, count + 1);
      expect(s.refs.last['countryCode'], 'DE');
      await s.saveRef('city', 'مدينة خاصة', {'countryCode': 'CA'});
      final city = s.refs.last;
      await s.saveRef('city', 'مدينة باسم جديد', {}, id: city['id']);
      expect(GeoCatalog.recordCode(s.refs.last), 'CA');
    },
  );

  test(
    'renaming/reordering/hiding choices preserves semantic and monetary keys',
    () async {
      final id = await s.saveEntry(sale());
      final before = await s.db.query('ledger');
      await s.set('choices_paymentMethod', {
        'labels': {'cash': 'استلام مباشر'},
        'hidden': ['bank'],
        'order': ['credit', 'cash'],
      });
      await s.set('uiLabels', {
        'التذاكر': 'رحلاتي',
        'طريقة التسديد': 'وسيلة الدفع',
      });
      final f = inputSpecs(
        'ticket',
      ).firstWhere((f) => f.key == 'paymentMethod');
      final choices = inputChoices(s.settings, 'ticket', f, current: 'bank');
      expect(choices.keys.first, 'credit');
      expect(choices['cash'], 'استلام مباشر');
      expect(choices.containsKey('bank'), true);
      expect(paymentLabel('cash'), 'استلام مباشر');
      expect(uiLabel('التذاكر'), 'رحلاتي');
      expect(s.entries.single.id, id);
      expect(await s.db.query('ledger'), before);
    },
  );

  test(
    'configuration transfer remaps reference IDs and never inserts accounts or money',
    () async {
      await s.saveEntry(sale());
      final city = s.referenceList('city').first;
      await s.set('defaults_ticket', {
        'from': city['id'],
        'customer': customer,
      });
      await s.set('uiLabels', {'الإعدادات': 'التحكم'});
      await s.set('statement_party_$customer', {'statementFont': 'sans'});
      await s.set('recovery_ticket_new', sale(posted: false));
      final data = ConfigTransfer.exportData(s);
      expect(jsonEncode(data), isNot(contains('recovery_ticket_new')));
      final other = await Store.open(
        factory: databaseFactoryFfi,
        path:
            '${(await Directory.systemTemp.createTemp('money21-config-')).path}/db',
      );
      final otherCustomer = await other.saveParty({
        'kind': 'customer',
        'name': 'مكتب الاختبار',
      });
      final refs = other.refs.length;
      await ConfigTransfer.importData(other, data);
      expect(other.entries, isEmpty);
      expect(await other.db.query('ledger'), isEmpty);
      expect(other.refs.length, refs);
      expect(other.parties.length, 1);
      expect(other.settings['defaults_ticket']['customer'], otherCustomer);
      expect(
        other.settings['statement_party_$otherCustomer']['statementFont'],
        'sans',
      );
      expect(other.settings['uiLabels']['الإعدادات'], 'التحكم');
      await other.db.close();
      other.dispose();
    },
  );

  test(
    'statement details are service-specific, individually hidden and ordered',
    () async {
      await GeoCatalog.load();
      final cities = s.referenceList('city');
      final ticket = Entry({
        ...sale(),
        'from': cities.first['id'],
        'to': cities.last['id'],
        'depart': '2026-11-25',
        'return': '2026-11-28',
      }, 25);
      final hotel = Entry({
        'kind': 'hotel',
        'hotelName': 'فندق الاختبار',
        'city': cities.first['id'],
        'checkIn': '2026-11-25',
        'checkOut': '2026-11-28',
        'rooms': '2',
      });
      final visa = Entry({'kind': 'visa', 'visaType': 'سياحية', 'days': '30'});
      expect(statementDetailValues(s, ticket)['tripType'], 'ذهاب وعودة');
      expect(statementDetailValues(s, hotel)['nights'], '3');
      expect(statementDetailValues(s, hotel)['hotelName'], 'فندق الاختبار');
      expect(statementDetailValues(s, visa)['visaType'], 'سياحية');
      final text = statementDescription(s, hotel, {
        'statementDetail_hotelName': true,
        'statementDetail_city': false,
      });
      expect(text, contains('فندق الاختبار'));
      expect(text, isNot(contains('مدينة الفندق')));
      expect(
        showStatementDetail({'statementShowTravel': false}, 'route'),
        false,
      );
      expect(
        showStatementDetail({
          'statementShowTravel': false,
          'statementDetail_route': true,
        }, 'route'),
        true,
      );
      expect(
        orderedStatementDetails({
          'statementDetailOrder': ['city', 'hotelName'],
        }).take(2),
        ['city', 'hotelName'],
      );
    },
  );

  test(
    'duplicate warning catches PNR, ignores edited record and remains overridable',
    () async {
      final id = await s.saveEntry(sale());
      expect(possibleDuplicate(s.entries, sale())?.id, id);
      expect(possibleDuplicate(s.entries, sale(), excludeId: id), isNull);
      final other = await s.saveEntry(sale());
      expect(other, isNot(id));
      expect(s.entries, hasLength(2));
    },
  );

  test(
    'new sound packs are local and native events keep exact selection',
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
      for (final style in ['silk', 'wood', 'crystal', 'water']) {
        displayPreferences = {'soundStyle': style};
        await Experience.fire('navigate', preview: 'sound');
        expect(calls.last.arguments['style'], style);
        for (final event in Experience.events) {
          final wav = await rootBundle.load(
            'assets/sounds/${style}_$event.wav',
          );
          expect(
            String.fromCharCodes(wav.buffer.asUint8List(wav.offsetInBytes, 4)),
            'RIFF',
          );
        }
      }
    },
  );

  test(
    'image sharing sends image paths independently of gallery saves',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Gallery.channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Gallery.channel, null),
      );
      await Gallery.shareImages([
        '/cache/statement_share/page1.png',
        '/cache/statement_share/page2.png',
      ]);
      expect(calls.single.method, 'shareImages');
      expect(calls.single.arguments['paths'], hasLength(2));
    },
  );

  testWidgets(
    'one calendar selects both dates, clears only return, derives ticket and hotel duration',
    (t) async {
      TravelRange? result;
      await t.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await chooseTravelRange(ctx);
                },
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('فتح'));
      await t.pumpAndSettle();
      final picker = t.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      picker.onDateChanged(DateTime(2026, 11, 25));
      await t.pumpAndSettle();
      t
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 11, 29));
      await t.pumpAndSettle();
      expect(find.text('ذهاب وعودة'), findsOneWidget);
      await t.tap(find.text('مسح العودة'));
      await t.pumpAndSettle();
      expect(find.text('ذهاب فقط'), findsOneWidget);
      await t.tap(find.text('اعتماد التواريخ'));
      await t.pumpAndSettle();
      expect(result?.start, '2026-11-25');
      expect(result?.end, isNull);
      expect(result?.tripType, 'oneWay');
      expect(const TravelRange('2026-11-25', '2026-11-29').nights, 4);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pack and label switches update existing scopes without recreating data',
    (t) async {
      await t.pumpWidget(
        host(const Scaffold(body: UiText('الإعدادات')), store: s),
      );
      expect(find.text('الإعدادات'), findsOneWidget);
      await t.runAsync(() => s.set('uiLabels', {'الإعدادات': 'التحكم'}));
      await t.pumpAndSettle();
      expect(find.text('التحكم'), findsOneWidget);
      for (final pack in visualPacks.keys) {
        displayPreferences['visualPack'] = pack;
        expect(activePack.id, pack);
        final bytes = await rootBundle.load(activePack.extraIcons!);
        expect(bytes.lengthInBytes, greaterThan(1000));
        expect(artIndex('customer'), isNot(artIndex('passenger')));
        expect(titleArt('بالغ / Adult'), isNot(titleArt('طفل / Child')));
        expect(titleArt('رضيع / Infant'), isNot(titleArt('طفل / Child')));
      }
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'ambient artwork moves at rest and reduced motion removes the transform',
    (t) async {
      AmbientRuntime.enabled = true;
      await t.runAsync(() => s.set('ambientLevel', 2));
      await t.pumpWidget(
        host(
          const Scaffold(
            body: AmbientMotion(
              seed: 0,
              child: SizedBox(width: 80, height: 80),
            ),
          ),
          store: s,
        ),
      );
      await t.pump(const Duration(milliseconds: 16));
      final transforms = find.descendant(
        of: find.byType(AmbientMotion),
        matching: find.byType(Transform),
      );
      final before = t
          .widget<Transform>(transforms.first)
          .transform
          .storage
          .toList();
      await t.pump(const Duration(milliseconds: 450));
      expect(
        t.widget<Transform>(transforms.first).transform.storage.toList(),
        isNot(before),
      );
      await t.runAsync(() => s.set('reduceMotion', true));
      await t.pumpWidget(
        host(
          const Scaffold(
            body: AmbientMotion(
              seed: 0,
              child: SizedBox(width: 80, height: 80),
            ),
          ),
          store: s,
        ),
      );
      await t.pump();
      expect(transforms, findsNothing);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'native choice target stays inside its field rather than merging the enclosing card',
    (t) async {
      await t.pumpWidget(
        host(
          Scaffold(
            body: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('عنوان البطاقة'),
                  const SizedBox(height: 140),
                  ChoiceField<String>(
                    initialValue: 'silk',
                    decoration: const InputDecoration(labelText: 'طابع الصوت'),
                    items: const [
                      DropdownMenuItem(
                        value: 'silk',
                        child: UiText('نسيم هادئ'),
                      ),
                      DropdownMenuItem(
                        value: 'crystal',
                        child: UiText('زجاج كريستالي'),
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 140),
                  const Text('نهاية البطاقة'),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = find.byType(ChoiceField<String>);
      expect(
        t.getSemantics(field).rect.height,
        closeTo(t.getSize(field).height, 1),
      );
      expect(t.getSemantics(field).rect.height, lessThan(120));
      await t.tap(field);
      await t.pumpAndSettle();
      expect(find.text('زجاج كريستالي'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
    semanticsEnabled: true,
  );
}
