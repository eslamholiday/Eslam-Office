import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/pages.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/gallery.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
void main() {
  sqfliteFfiInit();
  tearDown(() => displayPreferences = {});
  test('format settings only affect display, never ledger units', () {
    displayPreferences = {
      'usdDecimals': 2,
      'arabicDigits': true,
      'dateFormat': 'iso',
      'showWeekday': false,
    };
    expect(Currency.USD.format(123456), contains('١,٢٣٤.٥٦'));
    expect(money('1,234.56', Currency.USD), 123456);
    expect(displayDate('2026-10-04'), '٢٠٢٦-١٠-٠٤');
    expect(Gallery.safeName('زبون/كشف:USD.png'), 'زبون_كشف_USD.png');
  });
  testWidgets(
    'passenger grouping and search preserve account ownership and balances',
    (t) async {
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      final c = (await t.runAsync(
        () => s.saveParty({'kind': 'customer', 'name': 'صاحب الحساب'}),
      ))!;
      await t.runAsync(() async {
        await s.saveParty({
          'kind': 'passenger',
          'name': 'مسافر مرتبط',
          'customer': c,
        });
        await s.saveParty({'kind': 'passenger', 'name': 'بدون ارتباط'});
        await s.saveEntry({
          'kind': 'opening',
          'customer': c,
          'currency': 'USD',
          'date': '2026-10-04',
          'amount': 45678,
          'direction': 1,
          'posted': true,
        });
      });
      final before = jsonEncode(await t.runAsync(() => s.db.query('ledger')));
      await t.pumpWidget(host(PassengerGroupsPage(s)));
      await t.pumpAndSettle();
      expect(find.text('صاحب الحساب'), findsOneWidget);
      expect(find.text('مسافرون غير مرتبطين'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'مسافر مرتبط');
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'مسافر مرتبط'), findsOneWidget);
      expect(find.text('تابع إلى: صاحب الحساب'), findsOneWidget);
      expect(find.text('مسافرون غير مرتبطين'), findsNothing);
      expect(jsonEncode(await t.runAsync(() => s.db.query('ledger'))), before);
      expect(await t.runAsync(() => s.balance(c, Currency.USD)), 45678);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(s.db.close);
    },
  );
  testWidgets('unsaved entry back button can discard without posting', (
    t,
  ) async {
    final s = (await t.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    await t.pumpWidget(
      host(
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => EntryForm(s, 'visa')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'نوع الفيزا'), 'زيارة');
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
    await t.tap(find.text('تجاهل'));
    await t.pumpAndSettle();
    expect(s.entries, isEmpty);
    expect(find.text('open'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(s.db.close);
  });
}
