import 'dart:convert';
import 'package:intl/intl.dart';

enum Currency { USD, IQD }

extension CurrencyInfo on Currency {
  int get scale => this == Currency.USD ? 100 : 1;
  String get symbol => this == Currency.USD ? r'$' : 'د.ع';
  String format(int minor) {
    final whole = roundedRatio(minor, scale);
    final value = NumberFormat('#,##0', 'en').format(whole);
    return this == Currency.USD ? '\$ $value' : '$value د.ع';
  }

  /// Monetary inputs are intentionally shown as whole units in the UI.
  /// The ledger still stores USD as integer cents and IQD as integer dinars.
  String input(int minor) => minor == 0
      ? ''
      : NumberFormat('#,##0', 'en').format(roundedRatio(minor, scale));
}

String normalize(String s) {
  const a = '٠١٢٣٤٥٦٧٨٩', b = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(a[i], '$i').replaceAll(b[i], '$i');
  }
  return s
      .toLowerCase()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp('[\u064B-\u065F\u0640]'), '')
      .trim();
}

int decimalUnits(String text, int digits, {bool signed = false}) {
  var s = normalize(text)
      .replaceAll('٫', '.')
      .replaceAll('٬', '')
      .replaceAll(',', '')
      .replaceAll(' ', '');
  if (s.isEmpty) return 0;
  if (!RegExp(signed ? r'^-?\d+(\.\d+)?$' : r'^\d+(\.\d+)?$').hasMatch(s)) {
    throw const FormatException('أدخل رقمًا صحيحًا');
  }
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  final parts = s.split('.');
  final frac = parts.length > 1 ? parts[1] : '';
  if (frac.length > digits && int.parse(frac.substring(digits)) != 0) {
    throw FormatException('الحد الأقصى $digits خانات عشرية');
  }
  final factor = digits == 0 ? 1 : 100;
  final result =
      int.parse(parts[0]) * factor +
      (digits == 0
          ? 0
          : int.parse(frac.padRight(digits, '0').substring(0, digits)));
  if (result > 9000000000000) {
    throw const FormatException('المبلغ أكبر من الحد المسموح');
  }
  return negative ? -result : result;
}

int money(String s, Currency c) => decimalUnits(s, c == Currency.USD ? 2 : 0);
int roundedRatio(int numerator, int denominator) {
  if (denominator <= 0) throw ArgumentError('Invalid denominator');
  return numerator < 0
      ? -((-numerator + denominator ~/ 2) ~/ denominator)
      : (numerator + denominator ~/ 2) ~/ denominator;
}

const types = {
  'ticket': 'تذكرة',
  'hotel': 'فندق',
  'visa': 'فيزا',
  'settlement': 'تسوية',
  'opening': 'رصيد افتتاحي',
  'expense': 'مصروف',
  'funding': 'إضافة رصيد المصروف',
  'refund': 'استرجاع',
};

class Totals {
  final int sale, cost, commission;
  const Totals(this.sale, this.cost, [this.commission = 0]);
  int get profit => sale - cost;
  Map<String, dynamic> toJson() => {
    'sale': sale,
    'cost': cost,
    'commission': commission,
  };
}

Totals calculate(Map<String, dynamic> d) {
  final kind = d['kind'];
  if (kind == 'ticket') {
    int sale = 0, cost = 0, comm = 0;
    final rate = (d['rate'] ?? 0) as int;
    if (rate < 0 || rate > 10000) {
      throw const FormatException('العمولة يجب أن تكون بين 0 و100%');
    }
    for (final raw in (d['lines'] ?? []) as List) {
      final line = Map<String, dynamic>.from(raw);
      final qty = (line['qty'] ?? 0) as int;
      final base = (line['base'] ?? 0) as int,
          gross = (line['gross'] ?? 0) as int,
          sell = (line['sell'] ?? 0) as int;
      if (qty < 0 || qty > 9999 || base < 0 || gross < 0 || sell < 0) {
        throw const FormatException('تحقق من الأعداد والأسعار');
      }
      if (qty > 0 && base > gross) {
        throw const FormatException('السعر الأساسي أكبر من السعر الشامل');
      }
      final discount = d['commissionMode'] == 'fee'
          ? 0
          : roundedRatio(base * rate * qty, 10000);
      final fee = d['commissionMode'] == 'fee'
          ? (d['fee'] as int? ?? 0) * qty
          : 0;
      sale += sell * qty;
      cost += gross * qty - discount + fee;
      comm += discount;
    }
    return Totals(sale, cost, comm);
  }
  final qty = kind == 'visa' ? (d['qty'] as int? ?? 1) : 1;
  return Totals(
    (d['sell'] as int? ?? 0) * qty,
    (d['costUnit'] as int? ?? 0) * qty,
  );
}

class Entry {
  final int? id;
  final Map<String, dynamic> data;
  Entry(this.data, [this.id]);
  factory Entry.row(Map<String, Object?> r) => Entry(
    Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
    r['id'] as int,
  );
  String get kind => data['kind'] as String;
  String get label => kind == 'ticket' && data['ticketType'] == 'change'
      ? 'تغيير'
      : types[kind] ?? kind;
  int get quantity => kind == 'ticket'
      ? (data['lines'] as List? ?? []).fold<int>(
          0,
          (n, l) => n + (l['qty'] as int? ?? 0),
        )
      : kind == 'visa'
      ? data['qty'] as int? ?? 1
      : 1;
  List<int> get passengers => List<int>.from(
    data['passengers'] ??
        (data['passenger'] == null ? [] : [data['passenger']]),
  );
  Currency get currency => Currency.values.byName(data['currency']);
  bool get posted => data['posted'] == true;
  int get sale => data['sale'] as int? ?? 0;
  int get cost => data['cost'] as int? ?? 0;
  int get profit => sale - cost;
  String get date => data['date'];
}

class LedgerLine {
  final String account;
  final int? party;
  final int debit, credit;
  const LedgerLine(this.account, this.party, this.debit, this.credit);
}

List<LedgerLine> journal(Map<String, dynamic> d) {
  final kind = d['kind'];
  final customer = d['customer'] as int?, supplier = d['supplier'] as int?;
  final sale = d['sale'] as int? ?? 0, cost = d['cost'] as int? ?? 0;
  if (['ticket', 'hotel', 'visa', 'refund'].contains(kind)) {
    if (customer == null) {
      throw const FormatException('اختر حساب الزبون قبل اعتماد العملية');
    }
    final refund = kind == 'refund';
    return [
      LedgerLine('receivable', customer, refund ? 0 : sale, refund ? sale : 0),
      LedgerLine('revenue', null, refund ? sale : 0, refund ? 0 : sale),
      LedgerLine('cogs', null, refund ? 0 : cost, refund ? cost : 0),
      LedgerLine(
        supplier == null ? 'cash' : 'payable',
        supplier,
        refund ? cost : 0,
        refund ? 0 : cost,
      ),
    ];
  }
  if (kind == 'funding') {
    final amount = d['amount'] as int;
    return [
      LedgerLine('cash', null, amount, 0),
      LedgerLine('equity', null, 0, amount),
    ];
  }
  if (kind == 'expense') {
    final amount = d['amount'] as int;
    return [
      LedgerLine(
        d['personal'] == true ? 'drawings' : 'expense',
        null,
        amount,
        0,
      ),
      LedgerLine('cash', null, 0, amount),
    ];
  }
  final amount = d['amount'] as int;
  final increase = d['direction'] == 1;
  final isSupplier = d['partyType'] == 'supplier';
  final party = isSupplier ? supplier : customer;
  if (party == null) throw const FormatException('اختر الحساب');
  final debit = isSupplier ? !increase : increase;
  final counterpart = kind == 'opening' || d['settlementMode'] == 'adjustment'
      ? 'equity'
      : 'cash';
  return [
    LedgerLine(
      isSupplier ? 'payable' : 'receivable',
      party,
      debit ? amount : 0,
      debit ? 0 : amount,
    ),
    LedgerLine(counterpart, null, debit ? 0 : amount, debit ? amount : 0),
  ];
}

String day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _arabicWeekdays = <int, String>{
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
};

String displayDate(String? iso, {bool weekday = true}) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final numeric = '${d.day}/${d.month}/${d.year}';
  return weekday ? '${_arabicWeekdays[d.weekday]} $numeric' : numeric;
}

String normalizePhone(String raw) {
  var value = normalize(raw).replaceAll(RegExp(r'[\s()\-]'), '');
  if (value.startsWith('+964')) {
    value = value.substring(4);
  } else if (value.startsWith('00964')) {
    value = value.substring(5);
  } else if (value.startsWith('964')) {
    value = value.substring(3);
  }
  if (RegExp(r'^7[0-9]{9}$').hasMatch(value)) value = '0$value';
  return value;
}

const paymentMethods = {
  'cash': 'نقدًا',
  'bank': 'تحويل مصرفي',
  'card': 'بطاقة',
  'wallet': 'محفظة إلكترونية',
  'credit': 'آجل',
};

const statementOptions = {
  'statementShowPrevious': 'رصيد أول المدة',
  'statementShowTravel': 'تفاصيل السفر والخدمة',
  'statementShowNumber': 'رقم العملية',
  'statementShowDate': 'تاريخ العملية',
  'statementShowQuantity': 'عدد الخدمات',
  'statementShowPassengers': 'أسماء المسافرين',
  'statementShowPayment': 'طريقة التسديد',
  'statementShowNotes': 'الملاحظات',
  'statementShowBalance': 'الرصيد بعد كل حركة',
  'statementShowExchange': 'سعر صرف العرض',
  'statementShowFee': 'عمولة التحويل',
  'statementShowFinal': 'الرصيد والإجمالي النهائي',
  'statementShowPeriod': 'الفترة',
  'statementShowOffice': 'اسم المكتب',
  'statementShowPhone': 'رقم الهاتف',
  'statementShowWebsite': 'الموقع الإلكتروني',
  'statementShowTransferAccount': 'حساب التحويل الإلكتروني',
  'statementShowFooter': 'التذييل',
  'statementShowPage': 'رقم الصفحة',
};
