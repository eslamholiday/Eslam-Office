import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/reports.dart';
import 'package:eslam_office/statement_details.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/ui.dart' show ChoiceField;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  tearDown(() => displayPreferences = {});

  test(
    'compact statement uses values and printable route separator, preserving signed currencies',
    () async {
      final s = await Store.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      Future<int> reference(String kind, String name) async {
        if (!s.refs.any((r) => r['kind'] == kind && r['name'] == name)) {
          await s.saveRef(kind, name, {});
        }
        return s.refs.firstWhere(
              (r) => r['kind'] == kind && r['name'] == name,
            )['id']
            as int;
      }

      final from = await reference('city', 'بغداد');
      final to = await reference('city', 'عمّان');
      final country = await reference('country', 'العراق');
      final ticket = Entry({'kind': 'ticket', 'from': from, 'to': to});
      final hotel = Entry({
        'kind': 'hotel',
        'country': country,
        'hotelName': 'ديفان',
        'checkIn': '2026-10-06',
        'checkOut': '2026-10-07',
      });
      final options = <String, dynamic>{
        'statementShowNumber': false,
        'statementShowQuantity': false,
        'statementShowPayment': false,
        'statementDetail_tripType': false,
      };
      final flight = statementDescription(s, ticket, options);
      final stay = statementDescription(s, hotel, options);
      expect(normalize(flight), contains('بغداد - عمان'));
      expect(flight, isNot(contains('مدينتا المغادرة')));
      expect(stay, contains('العراق\nديفان'));
      expect(stay, contains('1 ليلة'));
      expect(stay, isNot(contains('الدولة:')));
      expect(stay, isNot(contains('اسم الفندق:')));
      final rows = <List<String>>[
        ['6/10/2026', 'تسوية', r'$ 4,250', '\$ 4,250\n0 د.ع'],
        ['6/10/2026', 'تسوية', '2,750,000 د.ع', '\$ 4,250\n2,750,000 د.ع'],
        ['6/10/2026', 'تسوية', '-4,500,000 د.ع', '\$ 4,250\n-1,750,000 د.ع'],
        [
          '6/10/2026',
          '$flight\nمسافر تجريبي أول',
          '1,540,000 د.ع',
          '\$ 4,250\n-210,000 د.ع',
        ],
        [
          '6/10/2026',
          '$stay\nمسافر تجريبي ثان',
          r'$ 210',
          '\$ 4,460\n-210,000 د.ع',
        ],
        [
          '12/10/2026',
          '$flight\nمسافر تجريبي ثالث',
          '640,000 د.ع',
          '\$ 4,460\n430,000 د.ع',
        ],
      ];
      for (final small in [false, true]) {
        final page = PdfPage(
          s,
          'كشف حساب تجريبي',
          ['التاريخ', 'العملية', 'الحركة', 'الرصيد'],
          rows,
          ['الرصيد النهائي: \$ 4,460\n430,000 د.ع'],
          preferences: {
            ...options,
            'statementFontSize': small ? 16 : 12,
            'statementPaper': small ? 'a5' : 'a4',
            'office': 'Eslam Holiday',
          },
        );
        final bytes = await page.document(PdfPageFormat.a4);
        expect(bytes.length, greaterThan(10000));
        await File(
          '/tmp/eslam-statement-compact${small ? '-a5' : ''}.pdf',
        ).writeAsBytes(bytes);
      }
      await s.db.close();
      s.dispose();
    },
  );

  testWidgets(
    'last statement settings apply to every account and survive reopening',
    (t) async {
      final dir = Directory.systemTemp.createTempSync('shared-statement-');
      final path = '${dir.path}/office.db';
      final s = (await t.runAsync(
        () => Store.open(factory: databaseFactoryFfi, path: path),
      ))!;
      late int first, second;
      await t.runAsync(() async {
        first = await s.saveParty({'kind': 'customer', 'name': 'الأول'});
        second = await s.saveParty({'kind': 'customer', 'name': 'الثاني'});
        await s.set('statement_party_$first', {'statementMode': 'allUSD'});
        await s.set('statement_party_$second', {'statementMode': 'allIQD'});
        await s.set('statementDefaultTemplate', 'قديم');
        await s.set('statementTemplates', {
          'قديم': {'statementMode': 'allUSD'},
        });
      });
      Future<void> open(int party) async {
        await t.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: StatementPage(s, party, key: ValueKey(party)),
          ),
        );
        await t.pumpAndSettle();
      }

      Finder currency() => find.byWidgetPredicate(
        (w) =>
            w is ChoiceField<String> && w.decoration?.labelText == 'عرض العملة',
      );
      await open(first);
      await t.tap(currency());
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('USD فقط'));
        await s.flushSettings();
      });
      await t.pumpAndSettle();
      await open(second);
      expect(t.widget<ChoiceField<String>>(currency()).initialValue, 'USD');
      expect(find.text('إعدادات خاصة بهذا الحساب'), findsNothing);
      await t.tap(currency());
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('IQD فقط'));
        await s.flushSettings();
      });
      await t.pumpAndSettle();
      await open(first);
      expect(t.widget<ChoiceField<String>>(currency()).initialValue, 'IQD');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        await s.flushSettings();
        await s.db.close();
      });
      s.dispose();
      await t.runAsync(() async {
        final reopened = await Store.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        expect(reopened.settings['statementMode'], 'IQD');
        expect(await reopened.db.query('entries'), isEmpty);
        expect(await reopened.db.query('ledger'), isEmpty);
        await reopened.db.close();
        reopened.dispose();
        await dir.delete(recursive: true);
      });
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
