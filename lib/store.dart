import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'domain.dart';

class Store extends ChangeNotifier {
  final Database db;
  List<Map<String, dynamic>> parties = [], refs = [], rules = [], logs = [];
  List<Entry> entries = [];
  Map<String, dynamic> settings = {};
  Store(this.db);
  static Future<Store> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final location = path ?? '${await f.getDatabasesPath()}/eslam_office.db';
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (d) async {
          await d.execute('PRAGMA foreign_keys=ON');
        },
        onUpgrade: (d, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await d.execute(
              "ALTER TABLE audit ADD COLUMN payload TEXT NOT NULL DEFAULT '{}'",
            );
          }
        },
        onCreate: (d, v) async {
          await d.execute(
            'CREATE TABLE parties(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT "", payload TEXT NOT NULL, archived INTEGER NOT NULL DEFAULT 0)',
          );
          await d.execute(
            'CREATE TABLE refs(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, name TEXT NOT NULL, payload TEXT NOT NULL, archived INTEGER NOT NULL DEFAULT 0)',
          );
          await d.execute(
            'CREATE TABLE rules(id INTEGER PRIMARY KEY AUTOINCREMENT, airline INTEGER NOT NULL, supplier INTEGER, payload TEXT NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, currency TEXT NOT NULL CHECK(currency IN ("USD","IQD")), date TEXT NOT NULL, customer INTEGER REFERENCES parties(id), supplier INTEGER REFERENCES parties(id), posted INTEGER NOT NULL, payload TEXT NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE ledger(id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER NOT NULL REFERENCES entries(id), currency TEXT NOT NULL CHECK(currency IN ("USD","IQD")), account TEXT NOT NULL, party INTEGER REFERENCES parties(id), debit INTEGER NOT NULL CHECK(debit>=0), credit INTEGER NOT NULL CHECK(credit>=0), CHECK(debit=0 OR credit=0))',
          );
          await d.execute(
            'CREATE INDEX ledger_party ON ledger(party,currency)',
          );
          await d.execute(
            'CREATE INDEX entries_date ON entries(date,currency)',
          );
          await d.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await d.execute(
            "CREATE TABLE audit(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL, payload TEXT NOT NULL DEFAULT '{}')",
          );
          for (final pair in {
            'airline': [
              'الخطوط الجوية العراقية|IA',
              'طيران العربية|G9',
              'فلاي دبي|FZ',
              'الخطوط التركية|TK',
              'الخطوط القطرية|QR',
              'الملكية الأردنية|RJ',
              'مصر للطيران|MS',
              'الإمارات|EK',
              'الشرق الأوسط|ME',
              'السعودية|SV',
              'فلاي ناس|XY',
              'بيغاسوس|PC',
              'فلاي بغداد|IF',
              'طيران الجزيرة|J9',
              'طيران الخليج|GF',
              'العُمانية|WY',
            ],
            'city': [
              'بغداد',
              'البصرة',
              'أربيل',
              'السليمانية',
              'النجف',
              'إسطنبول',
              'أنقرة',
              'دبي',
              'أبوظبي',
              'الشارقة',
              'عمّان',
              'بيروت',
              'القاهرة',
              'جدة',
              'الرياض',
              'الدوحة',
              'مسقط',
              'طهران',
              'كوالالمبور',
              'بانكوك',
              'تبليسي',
              'يريفان',
              'موسكو',
              'المالديف',
            ],
            'country': [
              'العراق',
              'تركيا',
              'الإمارات',
              'الأردن',
              'لبنان',
              'مصر',
              'السعودية',
              'قطر',
              'عُمان',
              'إيران',
              'ماليزيا',
              'تايلاند',
              'جورجيا',
              'أرمينيا',
              'روسيا',
              'المالديف',
              'الصين',
              'اليابان',
              'إندونيسيا',
              'سنغافورة',
              'سريلانكا',
              'المغرب',
              'جنوب أفريقيا',
            ],
          }.entries) {
            for (final text in pair.value) {
              final s = text.split('|');
              await d.insert('refs', {
                'kind': pair.key,
                'name': s[0],
                'payload': jsonEncode({
                  'code': s.length > 1 ? s[1] : '',
                  'rate': 0,
                  'currency': 'USD',
                }),
              });
            }
          }
        },
      ),
    );
    final s = Store(db);
    await s.reload();
    return s;
  }

  Future<void> reload() async {
    parties = (await db.query(
      'parties',
      orderBy: 'name',
    )).map(_decode).toList();
    refs = (await db.query('refs', orderBy: 'id')).map(_decode).toList();
    rules = (await db.query('rules')).map(_decode).toList();
    entries = (await db.query(
      'entries',
      orderBy: 'date DESC,id DESC',
    )).map(Entry.row).toList();
    logs = (await db.query(
      'audit',
      orderBy: 'id DESC',
      limit: 200,
    )).map((e) => Map<String, dynamic>.from(e)).toList();
    settings = {
      for (final r in await db.query('settings'))
        r['key'] as String: jsonDecode(r['value'] as String),
    };
    notifyListeners();
  }

  static Map<String, dynamic> _decode(Map<String, Object?> r) => {
    ...r,
    ...Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
  };
  String name(int? id) =>
      parties.where((p) => p['id'] == id).firstOrNull?['name'] ?? '';
  String reference(int? id) =>
      refs.where((p) => p['id'] == id).firstOrNull?['name'] ?? '';
  List<Map<String, dynamic>> list(String kind) =>
      parties.where((p) => p['kind'] == kind && p['archived'] == 0).toList();
  List<Map<String, dynamic>> referenceList(String kind) =>
      refs.where((p) => p['kind'] == kind && p['archived'] == 0).toList();
  Future<void> set(String key, dynamic value) async {
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    settings[key] = value;
    notifyListeners();
  }

  Future<void> audit(
    DatabaseExecutor d,
    String action,
    String target, {
    Map<String, dynamic>? payload,
  }) =>
      d.insert('audit', {
        'date': DateTime.now().toIso8601String(),
        'action': action,
        'target': target,
        'payload': jsonEncode(payload ?? const <String, dynamic>{}),
      });
  Future<int> saveParty(Map<String, dynamic> p, {int? id}) async {
    final values = {
      'kind': p['kind'],
      'name': (p['name'] ?? '').toString().trim(),
      'phone': p['phone'] ?? '',
      'payload': jsonEncode(p),
      'archived': p['archived'] ?? 0,
    };
    final result = await db.transaction((t) async {
      Map<String, Object?>? before;
      if (id != null) {
        final previous = await t.query('parties', where: 'id=?', whereArgs: [id]);
        if (previous.isNotEmpty) before = previous.first;
      }
      final key = id ?? await t.insert('parties', values);
      if (id != null) {
        await t.update('parties', values, where: 'id=?', whereArgs: [id]);
      }
      await audit(
        t,
        id == null ? 'إضافة حساب' : 'تعديل حساب',
        '$key',
        payload: {
          if (before != null) 'undoType': 'restoreParty',
          if (before != null) 'before': before,
          'after': values,
        },
      );
      return key;
    });
    await reload();
    return result;
  }

  Future<void> archiveParty(int id, bool value) async {
    await db.transaction((t) async {
      await t.update(
        'parties',
        {'archived': value ? 1 : 0},
        where: 'id=?',
        whereArgs: [id],
      );
      await audit(t, value ? 'أرشفة حساب' : 'استعادة حساب', '$id');
    });
    await reload();
  }

  Future<void> saveRef(
    String kind,
    String name,
    Map<String, dynamic> payload, {
    int? id,
  }) async {
    final normalizedName = normalize(name);
    final duplicate = refs.where(
      (r) =>
          r['kind'] == kind &&
          r['id'] != id &&
          r['archived'] == 0 &&
          normalize(r['name'] as String) == normalizedName,
    ).firstOrNull;
    if (duplicate != null) {
      throw const FormatException('هذا العنصر موجود مسبقاً');
    }
    final v = {
      'kind': kind,
      'name': name,
      'payload': jsonEncode(payload),
      'archived': payload['archived'] ?? 0,
    };
    await db.transaction((t) async {
      Map<String, Object?>? before;
      if (id != null) {
        final previous = await t.query('refs', where: 'id=?', whereArgs: [id]);
        if (previous.isNotEmpty) before = previous.first;
      }
      final key = id ?? await t.insert('refs', v);
      if (id != null) {
        await t.update('refs', v, where: 'id=?', whereArgs: [id]);
      }
      await audit(
        t,
        id == null ? 'إضافة عنصر مرجعي' : 'تعديل عنصر مرجعي',
        '$kind:$key',
        payload: {
          if (before != null) 'undoType': 'restoreRef',
          if (before != null) 'before': before,
          'after': v,
        },
      );
    });
    await reload();
  }

  Map<String, dynamic> commission(int? airline, int? supplier) {
    final rule = rules
        .where((r) => r['airline'] == airline && r['supplier'] == supplier)
        .firstOrNull;
    return rule ??
        refs.where((r) => r['id'] == airline).firstOrNull ??
        {'rate': 0, 'commissionMode': 'percent', 'fee': 0};
  }

  Future<void> saveRule(Map<String, dynamic> rule) async {
    await db.transaction((t) async {
      await t.delete(
        'rules',
        where: 'airline=? AND supplier=?',
        whereArgs: [rule['airline'], rule['supplier']],
      );
      await t.insert('rules', {
        'airline': rule['airline'],
        'supplier': rule['supplier'],
        'payload': jsonEncode(rule),
      });
    });
    await reload();
  }

  Future<int> saveEntry(Map<String, dynamic> raw, {int? id}) async {
    final d = Map<String, dynamic>.from(raw);
    final currency = Currency.values.byName(d['currency']);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d['date'])) {
      throw const FormatException('تاريخ غير صالح');
    }
    if (['ticket', 'hotel', 'visa'].contains(d['kind'])) {
      try {
        d.addAll(calculate(d).toJson());
      } on FormatException {
        if (d['posted'] == true) rethrow;
        d.addAll(const Totals(0, 0).toJson());
      }
    }
    if (d['posted'] == true &&
        d['kind'] == 'visa' &&
        ((d['qty'] as int? ?? 0) <= 0)) {
      throw const FormatException('عدد الفيز يجب أن يكون أكبر من صفر');
    }
    if (d['posted'] == true &&
        d['kind'] == 'ticket' &&
        (d['lines'] as List).fold<int>(0, (s, r) => s + (r['qty'] as int)) <=
            0) {
      throw const FormatException('أدخل عدد التذاكر');
    }
    if (d['kind'] == 'hotel' &&
        d['checkIn'] != null &&
        d['checkOut'] != null &&
        d['checkOut'].compareTo(d['checkIn']) <= 0) {
      throw const FormatException('الخروج يجب أن يكون بعد الدخول');
    }
    final post = d['posted'] == true;
    if (post &&
        ['settlement', 'opening', 'expense'].contains(d['kind']) &&
        (d['amount'] as int? ?? 0) <= 0) {
      throw const FormatException('أدخل مبلغًا أكبر من صفر');
    }
    final key = await db.transaction((t) async {
      if (id != null) {
        final old = await t.query('entries', where: 'id=?', whereArgs: [id]);
        if (old.isEmpty || old.first['posted'] == 1) {
          throw const FormatException(
            'العملية المعتمدة محفوظة؛ استخدم الاسترجاع للتصحيح',
          );
        }
      }
      if (post && d['corrects'] != null) {
        final previous = await t.query(
          'entries',
          where: 'id=?',
          whereArgs: [d['corrects']],
        );
        if (previous.isEmpty) {
          throw const FormatException('العملية السابقة غير موجودة');
        }
        final old = Entry.row(previous.first);
        if (!old.posted || !['ticket', 'hotel', 'visa'].contains(old.kind)) {
          throw const FormatException('هذه العملية لا تقبل تصحيح بيع');
        }
        final reverse = <String, dynamic>{
          'kind': 'refund',
          'original': old.id,
          'customer': old.data['customer'],
          'supplier': old.data['supplier'],
          'currency': old.currency.name,
          'date': d['date'],
          'sale': old.sale,
          'cost': old.cost,
          'posted': true,
          'notes': 'قيد عكس لتصحيح العملية #${old.id}',
        };
        await _validateRefund(t, reverse);
        final rid = await t.insert('entries', {
          'kind': 'refund',
          'currency': old.currency.name,
          'date': reverse['date'],
          'customer': reverse['customer'],
          'supplier': reverse['supplier'],
          'posted': 1,
          'payload': jsonEncode(reverse),
        });
        for (final l in journal(reverse)) {
          await t.insert('ledger', {
            'entry_id': rid,
            'currency': old.currency.name,
            'account': l.account,
            'party': l.party,
            'debit': l.debit,
            'credit': l.credit,
          });
        }
        await audit(t, 'عكس وتصحيح', '${old.id}');
      }
      if (d['kind'] == 'refund') await _validateRefund(t, d);
      final lines = post ? journal(d) : <LedgerLine>[];
      if (lines.fold<int>(0, (s, l) => s + l.debit - l.credit) != 0) {
        throw StateError('Unbalanced journal');
      }
      final values = {
        'kind': d['kind'],
        'currency': currency.name,
        'date': d['date'],
        'customer': d['customer'],
        'supplier': d['supplier'],
        'posted': post ? 1 : 0,
        'payload': jsonEncode(d),
      };
      final eid = id ?? await t.insert('entries', values);
      if (id != null) {
        await t.update('entries', values, where: 'id=?', whereArgs: [id]);
      }
      for (final l in lines) {
        await t.insert('ledger', {
          'entry_id': eid,
          'currency': currency.name,
          'account': l.account,
          'party': l.party,
          'debit': l.debit,
          'credit': l.credit,
        });
      }
      await audit(t, post ? 'اعتماد ${types[d['kind']]}' : 'حفظ مسودة', '$eid');
      return eid;
    });
    await reload();
    return key;
  }

  Future<void> _validateRefund(Transaction t, Map<String, dynamic> d) async {
    final r = await t.query(
      'entries',
      where: 'id=?',
      whereArgs: [d['original']],
    );
    if (r.isEmpty) throw const FormatException('العملية الأصلية غير موجودة');
    final original = Entry.row(r.first);
    if (!original.posted ||
        !['ticket', 'hotel', 'visa'].contains(original.kind) ||
        d['currency'] != original.currency.name ||
        d['customer'] != original.data['customer'] ||
        d['supplier'] != original.data['supplier']) {
      throw const FormatException('بيانات الاسترجاع غير متطابقة');
    }
    final all = (await t.query(
      'entries',
      where: 'kind=? AND posted=1',
      whereArgs: ['refund'],
    )).map(Entry.row).where((e) => e.data['original'] == original.id);
    final sale = all.fold<int>(0, (s, e) => s + e.sale),
        cost = all.fold<int>(0, (s, e) => s + e.cost);
    if (d['sale'] < 0 ||
        d['cost'] < 0 ||
        d['sale'] > original.sale - sale ||
        d['cost'] > original.cost - cost ||
        d['sale'] + d['cost'] == 0) {
      throw const FormatException('مبلغ الاسترجاع يتجاوز المتبقي من العملية');
    }
  }


  Future<void> forceDeleteEntry(Entry entry) async {
    if (entry.id == null) return;
    await db.transaction((t) async {
      final ids = <int>{entry.id!};
      for (final candidate in entries) {
        if (candidate.id != null &&
            (candidate.data['original'] == entry.id ||
                candidate.data['corrects'] == entry.id)) {
          ids.add(candidate.id!);
        }
      }
      final entryRows = <Map<String, Object?>>[];
      final ledgerRows = <Map<String, Object?>>[];
      for (final id in ids) {
        entryRows.addAll(await t.query('entries', where: 'id=?', whereArgs: [id]));
        ledgerRows.addAll(await t.query('ledger', where: 'entry_id=?', whereArgs: [id]));
      }
      if (entryRows.isEmpty) {
        throw const FormatException('العملية غير موجودة');
      }
      final placeholders = List.filled(ids.length, '?').join(',');
      await t.delete('ledger', where: 'entry_id IN ($placeholders)', whereArgs: ids.toList());
      await t.delete('entries', where: 'id IN ($placeholders)', whereArgs: ids.toList());
      await audit(
        t,
        'حذف إجباري',
        '${entry.id}',
        payload: {
          'undoType': 'forceDeleteEntry',
          'entries': entryRows,
          'ledger': ledgerRows,
        },
      );
    });
    await reload();
  }

  Future<void> undoAudit(int auditId) async {
    await db.transaction((t) async {
      final rows = await t.query('audit', where: 'id=?', whereArgs: [auditId]);
      if (rows.isEmpty) throw const FormatException('سجل التعديل غير موجود');
      final raw = rows.first['payload'] as String? ?? '{}';
      final payload = Map<String, dynamic>.from(jsonDecode(raw));
      final undoType = payload['undoType'];
      if (undoType == 'forceDeleteEntry') {
        final restoredEntries = (payload['entries'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final restoredLedger = (payload['ledger'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final row in restoredEntries) {
          await t.insert('entries', row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
        for (final row in restoredLedger) {
          await t.insert('ledger', row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      } else if (undoType == 'restoreParty') {
        final before = Map<String, dynamic>.from(payload['before'] as Map);
        await t.update(
          'parties',
          before,
          where: 'id=?',
          whereArgs: [before['id']],
        );
      } else if (undoType == 'restoreRef') {
        final before = Map<String, dynamic>.from(payload['before'] as Map);
        await t.update(
          'refs',
          before,
          where: 'id=?',
          whereArgs: [before['id']],
        );
      } else {
        throw const FormatException('هذا التعديل لا يدعم التراجع');
      }
      await t.delete('audit', where: 'id=?', whereArgs: [auditId]);
      await audit(t, 'تراجع عن تعديل', '${rows.first['target']}');
    });
    await reload();
  }

  Future<void> deleteDraft(Entry e) async {
    if (e.posted) return;
    await db.transaction((t) async {
      await t.delete('entries', where: 'id=? AND posted=0', whereArgs: [e.id]);
      await audit(t, 'حذف مسودة', '${e.id}');
    });
    await reload();
  }

  Future<int> balance(int id, Currency currency, {String? before}) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN l.account="payable" THEN l.credit-l.debit ELSE l.debit-l.credit END),0) AS total FROM ledger l JOIN entries e ON e.id=l.entry_id WHERE l.party=? AND l.currency=? AND l.account IN ("receivable","payable") ${before == null ? '' : 'AND e.date < ?'}',
      [id, currency.name, if (before != null) before],
    );
    return r.first['total'] as int;
  }

  int movement(Entry e, int party) {
    if (!e.posted) return 0;
    if (['ticket', 'hotel', 'visa', 'refund'].contains(e.kind)) {
      return (e.data['customer'] == party ? e.sale : e.cost) *
          (e.kind == 'refund' ? -1 : 1);
    }
    return (e.data['amount'] as int? ?? 0) * (e.data['direction'] as int? ?? 1);
  }

  List<Entry> history(int party) =>
      entries
          .where(
            (e) =>
                e.posted &&
                (e.data['customer'] == party || e.data['supplier'] == party),
          )
          .toList()
        ..sort(
          (a, b) => a.date == b.date
              ? a.id!.compareTo(b.id!)
              : a.date.compareTo(b.date),
        );
  Future<Map<String, int>> summary(Currency c) async {
    final bs = await db.rawQuery(
      'SELECT party,SUM(debit-credit) total FROM ledger WHERE account="receivable" AND currency=? GROUP BY party',
      [c.name],
    );
    int owed = 0, credit = 0;
    for (final r in bs) {
      final b = r['total'] as int;
      if (b > 0) {
        owed += b;
      } else {
        credit -= b;
      }
    }
    final p = await db.rawQuery(
      'SELECT account, SUM(debit-credit) total FROM ledger WHERE currency=? GROUP BY account',
      [c.name],
    );
    final values = {for (final r in p) r['account']: r['total'] as int};
    final sale = -(values['revenue'] ?? 0),
        cost = values['cogs'] ?? 0,
        expenses = values['expense'] ?? 0;
    return {
      'owed': owed,
      'credit': credit,
      'sale': sale,
      'profit': sale - cost,
      'expenses': expenses,
      'net': sale - cost - expenses,
    };
  }
}
