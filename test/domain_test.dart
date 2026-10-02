import 'package:flutter_test/flutter_test.dart';
import 'package:eslam_office/domain.dart';
import 'package:eslam_office/reports.dart';

void main() {
  Map<String, dynamic> ticket(int quantity, {int rate = 500}) => {
    'kind': 'ticket',
    'rate': rate,
    'lines': [
      {'qty': quantity, 'base': 10000, 'gross': 12000, 'sell': 13000},
    ],
  };
  test('ticket commission uses base and quantity', () {
    final t = calculate(ticket(2));
    expect(
      [t.sale, t.cost, t.commission, t.profit],
      [26000, 23000, 1000, 3000],
    );
  });
  test('adult child infant retain independent prices', () {
    final d = ticket(2);
    (d['lines'] as List).addAll(<Map<String, int>>[
      {'qty': 1, 'base': 5000, 'gross': 7000, 'sell': 8000},
      {'qty': 1, 'base': 1000, 'gross': 1500, 'sell': 2000},
    ]);
    final t = calculate(d);
    expect(
      [t.sale, t.cost, t.commission, t.profit],
      [36000, 31200, 1300, 4800],
    );
  });
  test('zero commission', () {
    expect(calculate(ticket(2, rate: 0)).cost, 24000);
  });
  test('additional issuer fee is multiplied once per ticket', () {
    final d = ticket(2)..addAll({'commissionMode': 'fee', 'fee': 500});
    final t = calculate(d);
    expect([t.cost, t.commission, t.profit], [25000, 0, 1000]);
  });
  test('hotel full cost not multiplied by rooms', () {
    final t = calculate({
      'kind': 'hotel',
      'sell': 90000,
      'costUnit': 60000,
      'rooms': 3,
      'nights': 5,
      'qty': 3,
    });
    expect([t.sale, t.cost, t.profit], [90000, 60000, 30000]);
  });
  test('visa quantity', () {
    final t = calculate({
      'kind': 'visa',
      'sell': 7000,
      'costUnit': 5000,
      'qty': 3,
    });
    expect([t.sale, t.cost, t.profit], [21000, 15000, 6000]);
  });
  test('Arabic and Persian numeric input', () {
    expect(money('١٢٣٫٤٥', Currency.USD), 12345);
    expect(money('۱٬۲۳۴', Currency.IQD), 1234);
  });
  test('unsupported fractions and negatives rejected', () {
    expect(() => money('1.2', Currency.IQD), throwsFormatException);
    expect(() => money('-3', Currency.USD), throwsFormatException);
    expect(() => money('1.001', Currency.USD), throwsFormatException);
  });
  test('rounding commission once per category', () {
    expect(
      calculate({
        'kind': 'ticket',
        'rate': 333,
        'lines': [
          {'qty': 3, 'base': 101, 'gross': 150, 'sell': 200},
        ],
      }).commission,
      10,
    );
  });
  test('normalized search', () {
    expect(normalize('إِسْلَام ١٢٣'), 'اسلام 123');
  });
  test('display conversion reversible at exact rate', () {
    expect(displayConvert(10000, Currency.USD, Currency.IQD, 150000), 150000);
    expect(displayConvert(150000, Currency.IQD, Currency.USD, 150000), 10000);
  });
  test('display conversion requires positive rate', () {
    expect(
      () => displayConvert(10, Currency.IQD, Currency.USD, 0),
      throwsFormatException,
    );
  });
  test('sale journal balanced and separate receivable payable', () {
    final d = ticket(2)
      ..addAll({'customer': 1, 'supplier': 2})
      ..addAll(calculate(ticket(2)).toJson());
    final lines = journal(d);
    expect(lines.fold<int>(0, (s, l) => s + l.debit - l.credit), 0);
    expect(lines.first.debit, 26000);
    expect(lines.last.credit, 23000);
  });
  test('settlement does not create revenue', () {
    final lines = journal({
      'kind': 'settlement',
      'amount': 10000,
      'customer': 1,
      'partyType': 'customer',
      'direction': -1,
    });
    expect(lines.map((l) => l.account), ['receivable', 'cash']);
    expect(lines.first.credit, 10000);
  });
}
