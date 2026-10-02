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
    customer = await s.saveParty({'kind': 'customer', 'name': 'عميل'});
    supplier = await s.saveParty({'kind': 'supplier', 'name': 'مورد'});
  });
  tearDown(() async {
    await s.db.close();
    s.dispose();
  });
  Map<String, dynamic> sale({String currency = 'USD', bool posted = true}) => {
    'kind': 'ticket',
    'currency': currency,
    'posted': posted,
    'date': '2026-10-02',
    'customer': customer,
    'supplier': supplier,
    'rate': 500,
    'lines': [
      {'qty': 2, 'base': 10000, 'gross': 12000, 'sell': 13000},
    ],
  };
  test('USD and IQD balances isolated, settlement no profit', () async {
    await s.saveEntry(sale());
    await s.saveEntry(sale(currency: 'IQD'));
    await s.saveEntry({
      'kind': 'settlement',
      'currency': 'USD',
      'posted': true,
      'date': '2026-10-02',
      'customer': customer,
      'partyType': 'customer',
      'amount': 5000,
      'direction': -1,
    });
    expect(await s.balance(customer, Currency.USD), 21000);
    expect(await s.balance(customer, Currency.IQD), 26000);
    expect(await s.balance(supplier, Currency.USD), 23000);
    expect((await s.summary(Currency.USD))['profit'], 3000);
  });
  test('draft does not create ledger; posting creates once', () async {
    final id = await s.saveEntry(sale(posted: false));
    expect(await s.balance(customer, Currency.USD), 0);
    await s.saveEntry(sale(), id: id);
    expect(await s.balance(customer, Currency.USD), 26000);
    await expectLater(s.saveEntry(sale(), id: id), throwsFormatException);
    expect(await s.balance(customer, Currency.USD), 26000);
  });
  test(
    'partial refund affects both parties and caps cumulative returns',
    () async {
      final id = await s.saveEntry(sale());
      final r = {
        'kind': 'refund',
        'currency': 'USD',
        'posted': true,
        'date': '2026-10-03',
        'customer': customer,
        'supplier': supplier,
        'original': id,
        'sale': 13000,
        'cost': 11500,
      };
      await s.saveEntry(r);
      expect(await s.balance(customer, Currency.USD), 13000);
      expect((await s.summary(Currency.USD))['profit'], 1500);
      await s.saveEntry(r);
      await expectLater(s.saveEntry(r), throwsFormatException);
      expect(await s.balance(supplier, Currency.USD), 0);
    },
  );
  test('opening and personal expenses do not affect profit', () async {
    await s.saveEntry({
      'kind': 'opening',
      'currency': 'USD',
      'posted': true,
      'date': '2026-10-01',
      'customer': customer,
      'partyType': 'customer',
      'amount': 10000,
      'direction': -1,
    });
    await s.saveEntry({
      'kind': 'expense',
      'currency': 'USD',
      'posted': true,
      'date': '2026-10-02',
      'amount': 2000,
      'personal': true,
    });
    expect(await s.balance(customer, Currency.USD), -10000);
    expect((await s.summary(Currency.USD))['net'], 0);
    await s.saveEntry({
      'kind': 'expense',
      'currency': 'USD',
      'posted': true,
      'date': '2026-10-02',
      'amount': 1500,
      'personal': false,
    });
    expect((await s.summary(Currency.USD))['net'], -1500);
  });
  test('commission settings do not change posted entries', () async {
    await s.saveEntry(sale());
    await s.saveRule({'airline': 1, 'supplier': supplier, 'rate': 2000});
    expect(await s.balance(supplier, Currency.USD), 23000);
  });
  test('account archiving preserves balances', () async {
    await s.saveEntry(sale());
    await s.archiveParty(customer, true);
    expect(s.list('customer'), isEmpty);
    expect(await s.balance(customer, Currency.USD), 26000);
    await s.archiveParty(customer, false);
    expect(s.list('customer').length, 1);
  });
  test('force delete removes ledger atomically and audit undo restores it', () async {
    final id = await s.saveEntry(sale());
    final entry = s.entries.firstWhere((e) => e.id == id);
    expect(await s.balance(customer, Currency.USD), 26000);
    await s.forceDeleteEntry(entry);
    expect(await s.balance(customer, Currency.USD), 0);
    final log = s.logs.firstWhere((r) => r['action'] == 'حذف إجباري');
    await s.undoAudit(log['id'] as int);
    expect(await s.balance(customer, Currency.USD), 26000);
    expect(s.entries.any((e) => e.id == id), isTrue);
  });
  test('duplicate active reference names are rejected', () async {
    await s.saveRef('city', 'مدينة اختبار', {});
    await expectLater(
      s.saveRef('city', 'مدينة اختبار', {}),
      throwsFormatException,
    );
  });
  test('invalid post atomic rollback', () async {
    final d = sale()..remove('customer');
    await expectLater(s.saveEntry(d), throwsFormatException);
    expect(s.entries, isEmpty);
    expect(await s.db.query('ledger'), isEmpty);
  });
  test('receivables not offset between separate customers', () async {
    await s.saveEntry(sale());
    final other = await s.saveParty({'kind': 'customer', 'name': 'ثانٍ'});
    await s.saveEntry({
      'kind': 'opening',
      'currency': 'USD',
      'posted': true,
      'date': '2026-10-01',
      'customer': other,
      'partyType': 'customer',
      'amount': 10000,
      'direction': -1,
    });
    final sum = await s.summary(Currency.USD);
    expect(sum['owed'], 26000);
    expect(sum['credit'], 10000);
  });
  test('ledger trial balance each currency', () async {
    await s.saveEntry(sale());
    await s.saveEntry(sale(currency: 'IQD'));
    final rows = await s.db.rawQuery(
      'SELECT currency,SUM(debit-credit) total FROM ledger GROUP BY currency',
    );
    expect(rows.every((r) => r['total'] == 0), isTrue);
  });
  test(
    'posted correction reverses old sale and posts replacement atomically',
    () async {
      final id = await s.saveEntry(sale());
      final replacement = sale()..addAll({'corrects': id, 'rate': 1000});
      await s.saveEntry(replacement);
      expect(s.entries.length, 3);
      expect(await s.balance(customer, Currency.USD), 26000);
      expect(await s.balance(supplier, Currency.USD), 22000);
      expect((await s.summary(Currency.USD))['profit'], 4000);
      await expectLater(s.saveEntry(replacement), throwsFormatException);
      expect(s.entries.length, 3);
    },
  );
  test('invalid replacement rolls back reversing entry too', () async {
    final id = await s.saveEntry(sale());
    final replacement = sale()..addAll({'corrects': id, 'customer': null});
    await expectLater(s.saveEntry(replacement), throwsFormatException);
    expect((await s.db.query('entries')).length, 1);
    expect(await s.balance(customer, Currency.USD), 26000);
  });
}
