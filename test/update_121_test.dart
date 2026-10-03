import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/main.dart';
import 'package:eslam_office/ui.dart';

Widget host(Widget page) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: page,
);
void main() {
  sqfliteFfiInit();
  test(
    'upgrade preserves existing data, seeds once and personal spending does not reduce profit',
    () async {
      final dir = await Directory.systemTemp.createTemp('money-upgrade-');
      final path = '${dir.path}/money.db';
      var s = await Store.open(factory: databaseFactoryFfi, path: path);
      final customer = await s.saveParty({
        'kind': 'customer',
        'name': 'عميل محفوظ',
      });
      await s.saveEntry({
        'kind': 'expense',
        'date': '2026-10-03',
        'currency': 'USD',
        'amount': 12500,
        'posted': true,
        'personal': true,
        'expenseSubcategory': 'قديم',
      });
      await s.set('office', 'مكتب محفوظ');
      // Simulate a 1.2.0 database with its existing user category and financial data.
      await s.db.delete(
        'refs',
        where: 'kind = ?',
        whereArgs: ['expenseCategory'],
      );
      await s.saveRef('expenseCategory', 'تصنيف خاص', {
        'subcategories': ['فرع خاص'],
      });
      await s.db.delete(
        'settings',
        where: 'key = ?',
        whereArgs: ['personalExpenseSeed'],
      );
      final ledgerBefore = await s.db.query('ledger');
      await s.db.close();
      s = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(s.referenceList('expenseCategory'), hasLength(14));
      expect(s.name(customer), 'عميل محفوظ');
      expect(s.settings['office'], 'مكتب محفوظ');
      expect(s.entries.single.data['expenseSubcategory'], 'قديم');
      expect(await s.db.query('ledger'), ledgerBefore);
      expect((await s.summary(Currency.USD))['profit'], 0);
      await s.db.close();
      s = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(s.referenceList('expenseCategory'), hasLength(14));
      await s.db.close();
      await dir.delete(recursive: true);
    },
  );
  testWidgets('eight dashboard cards open their own add forms below accounts', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = (await t.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    await t.runAsync(
      () => s.set('homeShortcutHidden', [
        'passengers',
        'suppliers',
        'expense',
        'movements',
        'review',
        'about',
      ]),
    );
    await t.pumpWidget(host(HomePage(s)));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    for (final target in [
      'تذاكر',
      'فيز',
      'فنادق',
      'مسافرون',
      'زبائن',
      'شركات الإصدار',
      'التسوية',
      'المصاريف',
    ]) {
      final card = find.byKey(ValueKey('home-stat-$target'));
      await t.ensureVisible(card);
      await t.pumpAndSettle();
      await t.tap(card);
      await t.pumpAndSettle();
      expect(
        find.byType(EntryForm).evaluate().length +
            find.byType(PartyForm).evaluate().length,
        1,
      );
      final expected = {
        'تذاكر': 'ticket',
        'فيز': 'visa',
        'فنادق': 'hotel',
        'مسافرون': 'passenger',
        'زبائن': 'customer',
        'شركات الإصدار': 'supplier',
        'التسوية': 'settlement',
        'المصاريف': 'expense',
      }[target];
      if (find.byType(EntryForm).evaluate().isNotEmpty) {
        expect(t.widget<EntryForm>(find.byType(EntryForm)).kind, expected);
      } else {
        expect(t.widget<PartyForm>(find.byType(PartyForm)).kind, expected);
      }
      expect(t.takeException(), isNull, reason: target);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
    }
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => s.db.close());
  });
  testWidgets(
    'expense subcategory list follows parent and new expenses are personal',
    (t) async {
      t.view.physicalSize = const Size(393, 1300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      await t.pumpWidget(host(EntryForm(s, 'expense')));
      await t.pumpAndSettle();
      final personal = find.widgetWithText(SwitchListTile, 'مصروف شخصي');
      expect(t.widget<SwitchListTile>(personal).value, isTrue);
      final category = find.byWidgetPredicate(
        (w) => w is PickField && w.label == 'تصنيف المصروف',
      );
      await t.ensureVisible(category);
      await t.tap(category);
      await t.pumpAndSettle();
      await t.tap(find.text('السكن والمنزل'));
      await t.pumpAndSettle();
      final sub = find.byWidgetPredicate(
        (w) => w is PickField && w.label == 'التصنيف الفرعي',
      );
      await t.tap(sub);
      await t.pumpAndSettle();
      expect(find.text('قسط المنزل'), findsOneWidget);
      expect(find.text('وقود'), findsNothing);
      await t.tap(find.text('قسط المنزل'));
      await t.pumpAndSettle();
      await t.tap(category);
      await t.pumpAndSettle();
      await t.tap(find.text('السيارة والتنقل'));
      await t.pumpAndSettle();
      await t.tap(sub);
      await t.pumpAndSettle();
      expect(find.text('وقود'), findsOneWidget);
      expect(find.text('قسط المنزل'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() => s.db.close());
    },
  );
}
