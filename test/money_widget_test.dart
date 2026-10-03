import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/pages.dart';
import 'package:eslam_office/reports.dart';
import 'package:eslam_office/settings.dart';
import 'package:eslam_office/money_pages.dart';

Widget host(Widget page) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: page,
);
void main() {
  sqfliteFfiInit();
  testWidgets(
    'review can cancel without a write then approve a standalone change',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = (await tester.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      final customer = (await tester.runAsync(
        () => s.saveParty({'kind': 'customer', 'name': 'إسلام'}),
      ))!;
      await tester.pumpWidget(
        host(
          EntryForm(
            s,
            'ticket',
            draft: Entry({
              'kind': 'ticket',
              'currency': 'USD',
              'date': '2026-10-03',
              'customer': customer,
              'posted': false,
              'lines': [
                {'qty': 1, 'base': 10000, 'gross': 12000, 'sell': 13000},
              ],
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تغيير'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ واعتماد'));
      await tester.pumpAndSettle();
      expect(find.text('مراجعة قبل الاعتماد'), findsOneWidget);
      expect(s.entries, isEmpty);
      await tester.tap(find.text('رجوع للتعديل'));
      await tester.pumpAndSettle();
      expect(s.entries, isEmpty);
      await tester.tap(find.text('حفظ واعتماد'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('اعتماد'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 300)); });
    await tester.pumpAndSettle();
    expect(s.entries, hasLength(1), reason: tester.widgetList<Text>(find.byType(Text)).map((e) => e.data).join(' | '));
    expect(s.entries.single.label, 'تغيير');
      expect(s.entries.single.data['original'], isNull);
      expect(
        await tester.runAsync(() => s.balance(customer, Currency.USD)),
        13000,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => s.db.close());
    },
  );
  testWidgets(
    'new screens render populated data at phone width without exceptions',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = (await tester.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      final customer = (await tester.runAsync(
        () => s.saveParty({'kind': 'customer', 'name': 'اختبار الحساب'}),
      ))!;
      await tester.runAsync(
        () => s.saveEntry({
          'kind': 'visa',
          'currency': 'USD',
          'date': '2026-10-03',
          'customer': customer,
          'qty': 3,
          'costUnit': 5000,
          'sell': 7000,
          'posted': true,
        }),
      );
      for (final page in <Widget>[
        AccountPage(s, customer),
        StatementsHub(s),
        StatementPage(s, customer),
        ExpensesPage(s),
        ReviewPage(s),
        ReportsPage(s),
        LayoutPage(s),
        FieldSettings(s, 'settlement'),
        OfficeSettings(s),
      ]) {
        await tester.pumpWidget(host(page));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: page.runtimeType.toString(),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => s.db.close());
    },
  );
}
