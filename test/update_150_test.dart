import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/forms.dart';
import 'package:eslam_office/input_schema.dart';
import 'package:eslam_office/input_settings.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/ui.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

void main() {
  sqfliteFfiInit();
  tearDown(() => displayPreferences = {});

  test(
    'editing a dollar amount preserves cents and grouped input decimals',
    () {
      expect(Currency.USD.editInput(123456), '1,234.56');
      expect(money(Currency.USD.editInput(123456), Currency.USD), 123456);
      final formatted = const ThousandsSeparatorFormatter().formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '1234.56'),
      );
      expect(formatted.text, '1,234.56');
    },
  );

  test(
    'every input scope has unique fields and complete layout; legacy hiding survives',
    () {
      for (final scope in inputScopes.keys) {
        final layout = InputLayout({}, scope);
        expect(layout.fields, isNotEmpty);
        expect(
          layout.fields.map((f) => f.key).toSet().length,
          layout.fields.length,
        );
        expect(
          layout.groups.toSet(),
          inputSpecs(scope).map((f) => f.group).toSet(),
        );
      }
      final layout = InputLayout({
        'hidden_ticket': ['country'],
        'fields_ticket': ['to', 'from'],
      }, 'ticket');
      expect(
        layout.mode(layout.fields.firstWhere((f) => f.key == 'country')),
        'hidden',
      );
      expect(layout.fields.take(2).map((f) => f.key), ['to', 'from']);
    },
  );

  test(
    'required hidden fields stay discoverable and return date follows trip type',
    () {
      final layout = InputLayout({
        'input_ticket': {
          'fields': {
            'customer': {'mode': 'hidden', 'required': true},
          },
        },
      }, 'ticket');
      final data = {
        'currency': 'USD',
        'date': '2026-11-22',
        'tripType': 'oneWay',
      };
      expect(layout.missing(data), contains('customer'));
      expect(
        layout.applicable(
          layout.fields.firstWhere((f) => f.key == 'return'),
          data,
        ),
        false,
      );
      data['return'] = '2026-11-24';
      expect(
        layout.applicable(
          layout.fields.firstWhere((f) => f.key == 'return'),
          data,
        ),
        true,
      );
    },
  );

  test(
    'custom choice labels preserve semantic keys and historical selections',
    () {
      const f = InputSpec(
        'paymentMethod',
        'التسديد',
        'payment',
        choices: paymentMethods,
      );
      final settings = {
        'choices_paymentMethod': {
          'hidden': ['cash'],
          'labels': {'cash': 'نقد المكتب', 'custom_1': 'Qi'},
        },
      };
      expect(inputChoices(settings, 'ticket', f), isNot(contains('cash')));
      expect(
        inputChoices(settings, 'ticket', f, current: 'cash')['cash'],
        'نقد المكتب',
      );
      expect(inputChoices(settings, 'ticket', f)['custom_1'], 'Qi');
    },
  );

  test(
    'customization never changes posted amounts, identity, or ledger',
    () async {
      final s = await Store.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final customer = await s.saveParty({'kind': 'customer', 'name': 'زبون'});
      final id = await s.saveEntry({
        'kind': 'visa',
        'currency': 'USD',
        'date': '2026-11-22',
        'customer': customer,
        'qty': 2,
        'sell': 15000,
        'costUnit': 10000,
        'posted': true,
      });
      final before = await s.db.query('ledger');
      await s.set('input_visa', {
        'fields': {
          'sell': {'mode': 'hidden', 'label': 'السعر'},
        },
        'groups': ['travel', 'main', 'service'],
      });
      await s.set('defaults_visa', {'sell': 99999});
      expect(await s.db.query('ledger'), before);
      expect(s.entries.single.id, id);
      expect(s.entries.single.sale, 30000);
      expect(await s.balance(customer, Currency.USD), 30000);
      await s.db.close();
    },
  );

  testWidgets(
    'selected passengers and input titles are visible without opening details',
    (t) async {
      await t.binding.setSurfaceSize(const Size(430, 1100));
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      final customer = (await t.runAsync(
        () => s.saveParty({'kind': 'customer', 'name': 'الحساب'}),
      ))!;
      final passenger = (await t.runAsync(
        () => s.saveParty({
          'kind': 'passenger',
          'name': 'اسم ظاهر',
          'customer': customer,
        }),
      ))!;
      await t.pumpWidget(
        host(
          EntryForm(
            s,
            'ticket',
            draft: Entry({
              'kind': 'ticket',
              'currency': 'USD',
              'customer': customer,
              'date': '2026-11-22',
              'passengers': [passenger],
              'lines': [
                {'qty': 1},
                {'qty': 0},
                {'qty': 0},
              ],
            }),
            preview: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('اسم ظاهر').hitTestable(), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'الأساسي للوحدة' &&
              w.decoration?.floatingLabelBehavior ==
                  FloatingLabelBehavior.always,
        ),
        findsWidgets,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(s.db.close);
      await t.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'search reveals hidden fields without deleting their saved values',
    (t) async {
      final s = (await t.runAsync(
        () =>
            Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      ))!;
      await t.runAsync(
        () => s.set('input_visa', {
          'fields': {
            'visaType': {'mode': 'hidden'},
          },
        }),
      );
      await t.pumpWidget(host(EntryForm(s, 'visa', preview: true)));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'نوع الفيزا'), findsNothing);
      await t.tap(find.byTooltip('بحث الحقول الظاهرة والمخفية'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'اسم الحقل'),
        'نوع الفيزا',
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'نوع الفيزا'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.widgetWithText(TextField, 'نوع الفيزا'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(s.entries, isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(s.db.close);
    },
  );

  testWidgets('input center exposes all scopes and every settings tab opens', (
    t,
  ) async {
    final s = (await t.runAsync(
      () => Store.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    ))!;
    await t.pumpWidget(host(FormCustomizationPage(s, 'ticket')));
    await t.pumpAndSettle();
    expect(find.text('الحقول'), findsOneWidget);
    await t.tap(find.text('الأقسام'));
    await t.pumpAndSettle();
    expect(find.text('معلومات العملية'), findsOneWidget);
    await t.tap(find.text('الافتراضيات'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(s.db.close);
  });

  testWidgets(
    'picker shows selection title before focus and permits clearing',
    (t) async {
      int? selected = 1;
      await t.pumpWidget(
        host(
          StatefulBuilder(
            builder: (c, set) => Scaffold(
              body: PickField('اسم الزبون', selected, const [
                {'id': 1, 'name': 'اختيار واضح'},
              ], (v) => set(() => selected = v)),
            ),
          ),
        ),
      );
      expect(find.text('اختيار واضح'), findsOneWidget);
      final decorator = t.widget<InputDecorator>(find.byType(InputDecorator));
      expect(
        decorator.decoration.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      await t.tap(find.byTooltip('مسح الاختيار'));
      await t.pump();
      expect(selected, isNull);
      expect(t.takeException(), isNull);
    },
  );
}
