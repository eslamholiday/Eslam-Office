import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/store.dart';
import 'package:eslam_office/domain.dart';

void main() {
  sqfliteFfiInit();
  late Store s;
  late int customer, supplier;
  setUp(() async {
    s = await Store.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    customer = await s.saveParty({
      'kind': 'customer',
      'name': 'إسلام',
      'phone': '+964 770 455 6882',
    });
    supplier = await s.saveParty({'kind': 'supplier', 'name': 'إصدار'});
  });
  tearDown(() async {
    await s.db.close();
    s.dispose();
  });
  Map<String, dynamic> ticket({String currency = 'USD'}) => {
    'kind': 'ticket',
    'ticketType': 'change',
    'currency': currency,
    'posted': true,
    'date': '2026-10-03',
    'customer': customer,
    'supplier': supplier,
    'rate': 0,
    'lines': [
      {'qty': 2, 'base': 1000, 'gross': 1000, 'sell': 1500},
    ],
  };
  test('Iraqi phone normalizes local international and Arabic digits', () {
    for (final value in [
      '+964 770 455 6882',
      '009647704556882',
      '9647704556882',
      '7704556882',
      '٠٧٧٠٤٥٥٦٨٨٢',
    ]) {
      expect(normalizePhone(value), '07704556882');
    }
    expect(normalizePhone('+905551112233'), '+905551112233');
    expect(s.name(customer), 'إسلام');
    expect(
      s.parties.firstWhere((p) => p['id'] == customer)['phone'],
      '07704556882',
    );
  });
  test(
    'change label independent with same quantity and financial math',
    () async {
      await s.saveEntry(ticket());
      final e = s.entries.single;
      expect(e.label, 'تغيير');
      expect(e.quantity, 2);
      expect(e.data['original'], isNull);
      expect(await s.balance(customer, Currency.USD), 3000);
      expect(await s.balance(supplier, Currency.USD), 2000);
      expect(s.expenseBalance(Currency.USD), 1000);
    },
  );
  test(
    'expense wallet derives once, funding no profit, currency separated',
    () async {
      final id = await s.saveEntry(ticket());
      await s.saveEntry({...ticket(currency: 'IQD')});
      await s.saveEntry({
        'kind': 'funding',
        'amount': 500,
        'currency': 'USD',
        'date': '2026-10-03',
        'posted': true,
      });
      await s.saveEntry({
        'kind': 'expense',
        'amount': 200,
        'personal': true,
        'currency': 'USD',
        'date': '2026-10-03',
        'posted': true,
      });
      await s.reload();
      await s.reload();
      expect(s.expenseBalance(Currency.USD), 1300);
      expect(s.expenseBalance(Currency.IQD), 1000);
      expect((await s.summary(Currency.USD))['profit'], 1000);
      await s.saveEntry({
        'kind': 'refund',
        'original': id,
        'customer': customer,
        'supplier': supplier,
        'sale': 1500,
        'cost': 1000,
        'currency': 'USD',
        'date': '2026-10-03',
        'posted': true,
      });
      expect(s.expenseBalance(Currency.USD), 800);
      expect(
        (await s.db.rawQuery(
          'SELECT SUM(debit-credit) total FROM ledger',
        )).single['total'],
        0,
      );
    },
  );
  test('passenger association validates ownership and rolls back', () async {
    final other = await s.saveParty({'kind': 'customer', 'name': 'ثانٍ'});
    final passenger = await s.saveParty({
      'kind': 'passenger',
      'name': 'مسافر',
      'customer': other,
    });
    await expectLater(
      s.saveEntry({
        ...ticket(),
        'passengers': [passenger],
      }),
      throwsFormatException,
    );
    expect(s.entries, isEmpty);
    final free = await s.saveParty({'kind': 'passenger', 'name': 'مسافر حر'});
    await s.saveEntry({
      ...ticket(),
      'passengers': [free],
    });
    expect(s.parties.firstWhere((p) => p['id'] == free)['customer'], customer);
  });
  test(
    'delete account removes all connected records without altering unrelated account',
    () async {
      final passenger = await s.saveParty({
        'kind': 'passenger',
        'name': 'تابع',
        'customer': customer,
      });
      final original = await s.saveEntry({
        ...ticket(),
        'passengers': [passenger],
      });
      await s.saveEntry({...ticket(), 'corrects': original});
      final other = await s.saveParty({'kind': 'customer', 'name': 'باقٍ'});
      await s.saveEntry({...ticket(), 'customer': other});
      await s.deleteParty(customer);
      expect(
        s.parties.any((p) => p['id'] == passenger || p['id'] == customer),
        isFalse,
      );
      expect(s.entries.length, 1);
      expect(await s.balance(supplier, Currency.USD), 2000);
      expect(await s.balance(other, Currency.USD), 3000);
      expect((await s.db.rawQuery('PRAGMA foreign_key_check')), isEmpty);
      expect((await s.summary(Currency.USD))['profit'], 1000);
    },
  );
  test(
    'v1 database update retains ledger entries settings and attachments byte-for-byte',
    () async {
      final dir = await Directory.systemTemp.createTemp('eslam-migration-');
      final path = '${dir.path}/eslam_office.db';
      var old = await Store.open(factory: databaseFactoryFfi, path: path);
      final account = await old.saveParty({
        'kind': 'customer',
        'name': 'قديم',
        'attachments': ['/kept/image.jpg'],
      });
      await old.saveEntry({...ticket(), 'customer': account, 'supplier': null});
      await old.set('logo', '/kept/logo.png');
      await old.set('defaultCurrency', 'IQD');
      final before = jsonEncode(await old.db.query('entries'));
      final ledger = jsonEncode(await old.db.query('ledger'));
      await old.db.delete(
        'settings',
        where: 'key=?',
        whereArgs: ['moneyMigration'],
      );
      await old.db.execute('ALTER TABLE audit DROP COLUMN payload');
      await old.db.setVersion(1);
      await old.db.close();
      old = await Store.open(factory: databaseFactoryFfi, path: path);
      expect(jsonEncode(await old.db.query('entries')), before);
      expect(jsonEncode(await old.db.query('ledger')), ledger);
      expect(old.settings['logo'], '/kept/logo.png');
      expect(old.settings['defaultCurrency'], 'IQD');
      expect(old.parties.single['attachments'], ['/kept/image.jpg']);
      expect(await old.balance(account, Currency.USD), 3000);
      expect(old.settings['navOrder'], [
        'home',
        'customers',
        'statements',
        'settings',
      ]);
      await old.db.close();
      await dir.delete(recursive: true);
    },
  );
}
