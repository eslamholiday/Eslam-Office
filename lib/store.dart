import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'domain.dart';
import 'expense_categories.dart';
import 'geography.dart';

class Store extends ChangeNotifier {
  final Database db;
  List<Map<String, dynamic>> parties = [], refs = [], rules = [], logs = [];
  List<Entry> entries = [];
  List<Map<String, dynamic>> clearances = [];
  Set<int> retiredParties = {};
  Map<String, dynamic> settings = {};
  final Set<Future<void>> _preferenceWrites = {};
  Store(this.db);
  static Future<Store> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final location = path ?? '${await f.getDatabasesPath()}/eslam_office.db';
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (d) async {
          await d.execute('PRAGMA foreign_keys=ON');
        },
        onUpgrade: (d, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await d.execute(
              "ALTER TABLE audit ADD COLUMN payload TEXT NOT NULL DEFAULT '{}'",
            );
          }
          if (oldVersion < 3) await _createClearanceTables(d);
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
          await _createClearanceTables(d);
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
    if (s.settings['moneyMigration'] != 1) {
      await s.set('navOrder', ['home', 'customers', 'statements', 'settings']);
      await s.set('navHidden', []);
      await s.set('homeCards', ['owed', 'profit', 'payable', 'expenses']);
      await s.set('homeCardsHidden', []);
      await s.set('start', 'home');
      await s.set('moneyMigration', 1);
    }
    if (s.settings['personalExpenseSeed'] != 1) {
      await db.transaction((tx) async {
        for (final category in personalExpenseCategories.entries) {
          final existing = await tx.query(
            'refs',
            where: 'kind = ? AND name = ?',
            whereArgs: ['expenseCategory', category.key],
          );
          if (existing.isEmpty) {
            await tx.insert('refs', {
              'kind': 'expenseCategory',
              'name': category.key,
              'payload': jsonEncode({
                'personal': true,
                'subcategories': category.value,
              }),
            });
          } else {
            final payload = Map<String, dynamic>.from(
              jsonDecode(existing.first['payload'] as String),
            );
            payload['subcategories'] = <String>{
              ...List<String>.from(payload['subcategories'] ?? []),
              ...category.value,
            }.toList();
            payload.putIfAbsent('personal', () => true);
            await tx.update(
              'refs',
              {'payload': jsonEncode(payload)},
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          }
        }
        await tx.insert('settings', {
          'key': 'personalExpenseSeed',
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      await s.reload();
    }
    if (s.settings['experience21'] != true) {
      await s.set('visualPack', 'glass');
      await s.set('soundStyle', 'silk');
      await s.set('ambientLevel', 2);
      await s.set('experience21', true);
    }
    if (s.settings['office22'] != true) {
      await s.set('visualPack', 'office');
      await s.set('office22', true);
    }
    if (s.settings['clay23'] != true) {
      await s.set('visualPack', 'clay');
      await s.set('ambientLevel', 0);
      await s.set('clay23', true);
    }
    if (s.settings['visualPack'] == 'office') await s.set('visualPack', 'clay');
    return s;
  }

  static Future<void> _createClearanceTables(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS clearance_batches(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, date TEXT NOT NULL, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS clearance_entries(id INTEGER PRIMARY KEY, batch INTEGER NOT NULL REFERENCES clearance_batches(id), payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS retired_parties(id INTEGER PRIMARY KEY, batch INTEGER NOT NULL REFERENCES clearance_batches(id))',
    );
  }

  /// Moves full journal bundles into an immutable, independent history.
  /// Active SQL queries continue to operate solely on entries and ledger.
  Future<int> clearToArchive({
    Set<int>? entryIds,
    int? party,
    bool retireAccount = false,
    bool all = false,
  }) async {
    final batchId = await db.transaction((tx) async {
      final current = (await tx.query(
        'entries',
      )).map((r) => Map<String, Object?>.from(r)).toList();
      final parsed = current.map(Entry.row).toList();
      final ids = <int>{...?(entryIds)};
      if (all) ids.addAll(parsed.where((e) => e.posted).map((e) => e.id!));
      if (party != null) {
        ids.addAll(
          parsed
              .where(
                (e) =>
                    e.data['customer'] == party || e.data['supplier'] == party,
              )
              .map((e) => e.id!),
        );
        ids.addAll(
          (await tx.query(
            'ledger',
            columns: ['entry_id'],
            where: 'party=?',
            whereArgs: [party],
          )).map((r) => r['entry_id'] as int),
        );
      }
      bool changed;
      do {
        changed = false;
        for (final e in parsed) {
          final linked = [
            e.data['original'],
            e.data['corrects'],
          ].whereType<int>();
          if (ids.contains(e.id)) {
            for (final id in linked) {
              if (parsed.any((e) => e.id == id) && ids.add(id)) changed = true;
            }
          } else if (linked.any(ids.contains) && ids.add(e.id!)) {
            changed = true;
          }
        }
      } while (changed);
      final selected = current.where((r) => ids.contains(r['id'])).toList();
      if (selected.isEmpty && !(retireAccount && party != null)) {
        throw const FormatException('لا توجد عمليات للتصفية');
      }
      final allPeople = await tx.query('parties');
      final retirement = <int>{if (retireAccount && party != null) party};
      if (retirement.isNotEmpty) {
        retirement.addAll(
          allPeople
              .map(_decode)
              .where((p) => p['kind'] == 'passenger' && p['customer'] == party)
              .map((p) => p['id'] as int),
        );
      }
      final ledger = <Map<String, Object?>>[];
      final related = <int>{...retirement};
      for (final row in selected) {
        final entry = Entry.row(row);
        related.addAll(
          [
            entry.data['customer'],
            entry.data['supplier'],
            ...entry.passengers,
          ].whereType<int>(),
        );
        ledger.addAll(
          await tx.query('ledger', where: 'entry_id=?', whereArgs: [row['id']]),
        );
      }
      related.addAll(ledger.map((r) => r['party']).whereType<int>());
      final label = all
          ? 'تصفية جميع العمليات المعتمدة'
          : party != null
          ? 'تصفية حساب ${name(party)}'
          : 'تصفية عملية ${selected.first['id']}';
      final batch = await tx.insert('clearance_batches', {
        'title': label,
        'date': DateTime.now().toIso8601String(),
        'payload': jsonEncode({
          'version': 1,
          'entries': selected,
          'ledger': ledger,
          'parties': allPeople.where((r) => related.contains(r['id'])).toList(),
          'refs': await tx.query('refs'),
          'settings': settings,
          'retired': retirement.toList(),
          'party': party,
        }),
      });
      for (final row in selected) {
        await tx.insert('clearance_entries', {
          'id': row['id'],
          'batch': batch,
          'payload': jsonEncode(row),
        });
        await tx.delete('ledger', where: 'entry_id=?', whereArgs: [row['id']]);
        await tx.delete('entries', where: 'id=?', whereArgs: [row['id']]);
      }
      for (final id in retirement) {
        await tx.update(
          'parties',
          {'archived': 1},
          where: 'id=?',
          whereArgs: [id],
        );
        await tx.insert('retired_parties', {
          'id': id,
          'batch': batch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // A recovery draft must not resurrect a cleared record on reopening.
      for (final row in await tx.query('settings')) {
        final key = row['key'] as String;
        if (!key.startsWith('recovery_')) continue;
        final value = jsonDecode(row['value'] as String);
        if (value is Map &&
            (ids.contains(value['id']) ||
                ids.contains(int.tryParse(key.split('_').last)) ||
                (party != null &&
                    (value['customer'] == party ||
                        value['supplier'] == party)) ||
                (all && value['posted'] == true))) {
          await tx.delete('settings', where: 'key=?', whereArgs: [key]);
        }
      }
      await audit(
        tx,
        'تصفية وأرشفة نهائية',
        '$batch',
        payload: {'count': selected.length, 'archiveOnly': true},
      );
      return batch;
    });
    await reload();
    return batchId;
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
    clearances = (await db.query(
      'clearance_batches',
      orderBy: 'id DESC',
    )).map(_decode).toList();
    retiredParties = (await db.query(
      'retired_parties',
    )).map((r) => r['id'] as int).toSet();
    logs = (await db.query(
      'audit',
      orderBy: 'id DESC',
      limit: 200,
    )).map((e) => Map<String, dynamic>.from(e)).toList();
    settings = {
      for (final r in await db.query('settings'))
        r['key'] as String: jsonDecode(r['value'] as String),
    };
    displayPreferences = Map<String, dynamic>.from(settings);
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
  Future<void> set(String key, dynamic value) {
    final write = _writeSetting(key, value);
    _preferenceWrites.add(write);
    write.then<void>(
      (_) {
        _preferenceWrites.remove(write);
      },
      onError: (Object _, StackTrace __) {
        _preferenceWrites.remove(write);
      },
    );
    return write;
  }

  Future<void> flushSettings() async {
    while (_preferenceWrites.isNotEmpty) {
      await Future.wait(_preferenceWrites.toList());
    }
  }

  Future<void> _writeSetting(String key, dynamic value) async {
    final record = {'key': key, 'value': jsonEncode(value)};
    if (key.startsWith('recovery_') && value is Map) {
      final applied = await db.transaction((tx) async {
        final id = int.tryParse(key.split('_').last) ?? value['id'] as int?;
        if (id != null &&
            (await tx.query(
              'entries',
              columns: ['id'],
              where: 'id=?',
              whereArgs: [id],
            )).isEmpty) {
          return false;
        }
        for (final party in [
          value['customer'],
          value['supplier'],
        ].whereType<int>()) {
          if ((await tx.query(
            'retired_parties',
            columns: ['id'],
            where: 'id=?',
            whereArgs: [party],
          )).isNotEmpty) {
            return false;
          }
        }
        await tx.insert(
          'settings',
          record,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      });
      if (!applied) return;
    } else {
      await db.insert(
        'settings',
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    settings[key] = value;
    displayPreferences = Map<String, dynamic>.from(settings);
    notifyListeners();
  }

  Future<void> audit(
    DatabaseExecutor d,
    String action,
    String target, {
    Map<String, dynamic>? payload,
  }) => d.insert('audit', {
    'date': DateTime.now().toIso8601String(),
    'action': action,
    'target': target,
    'payload': jsonEncode(payload ?? const <String, dynamic>{}),
  });
  Future<int> saveParty(Map<String, dynamic> p, {int? id}) async {
    final values = {
      'kind': p['kind'],
      'name': (p['name'] ?? '').toString().trim(),
      'phone': normalizePhone(p['phone'] ?? ''),
      'payload': jsonEncode({...p, 'phone': normalizePhone(p['phone'] ?? '')}),
      'archived': p['archived'] ?? 0,
    };
    if (retiredParties.contains(p['customer'])) {
      throw const FormatException('اختر حساب زبون حاليًا؛ الحساب السابق مصفّى');
    }
    if (id != null && retiredParties.contains(id)) {
      throw const FormatException('حساب مصفّى للقراءة فقط');
    }
    final result = await db.transaction((t) async {
      Map<String, Object?>? before;
      if (id != null) {
        final previous = await t.query(
          'parties',
          where: 'id=?',
          whereArgs: [id],
        );
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
    if (!value && retiredParties.contains(id)) {
      throw const FormatException('حساب مصفّى؛ الأرشيف للاطلاع فقط');
    }
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
    final previous = refs.where((r) => r['id'] == id).firstOrNull;
    payload = Map<String, dynamic>.from(payload);
    for (final key in ['countryCode', 'flagCode']) {
      if (!payload.containsKey(key) && previous?.containsKey(key) == true) {
        payload[key] = previous![key];
      }
    }
    final geo = GeoCatalog.infer(kind, name);
    if (geo != null) payload.putIfAbsent('countryCode', () => geo);
    final normalizedName = normalize(name);
    final duplicate = refs
        .where(
          (r) =>
              r['kind'] == kind &&
              r['id'] != id &&
              r['archived'] == 0 &&
              normalize(r['name'] as String) == normalizedName,
        )
        .firstOrNull;
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
    if ([raw['customer'], raw['supplier']].any(retiredParties.contains)) {
      throw const FormatException('اختر حسابًا حاليًا؛ الحساب السابق مصفّى');
    }
    final d = Map<String, dynamic>.from(raw);
    final currency = Currency.values.byName(d['currency']);
    if (d['posted'] == true &&
        d['depart'] != null &&
        d['return'] != null &&
        '${d['return']}'.compareTo('${d['depart']}') < 0) {
      throw const FormatException('تاريخ العودة يجب ألا يسبق الذهاب');
    }
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
        ['settlement', 'opening', 'expense', 'funding'].contains(d['kind']) &&
        (d['amount'] as int? ?? 0) <= 0) {
      throw const FormatException('أدخل مبلغًا أكبر من صفر');
    }
    final key = await db.transaction((t) async {
      // Older callers may still supply corrects; edit the original in place.
      id ??= d['corrects'] as int?;
      d.remove('corrects');
      if (id != null) {
        final rows = await t.query('entries', where: 'id=?', whereArgs: [id]);
        if (rows.isEmpty) {
          throw const FormatException('العملية غير موجودة');
        }
        final old = Entry.row(rows.first);
        if (old.kind != d['kind'] || (old.posted && !post)) {
          throw const FormatException(
            'لا يمكن تغيير نوع العملية أو تحويلها إلى مسودة',
          );
        }
        final refunds = (await t.query(
          'entries',
          where: 'kind=? AND posted=1',
          whereArgs: ['refund'],
        )).map(Entry.row).where((e) => e.data['original'] == id).toList();
        if (refunds.isNotEmpty &&
            (d['currency'] != old.currency.name ||
                d['customer'] != old.data['customer'] ||
                d['supplier'] != old.data['supplier'] ||
                (d['sale'] as int) <
                    refunds.fold<int>(0, (sum, e) => sum + e.sale) ||
                (d['cost'] as int) <
                    refunds.fold<int>(0, (sum, e) => sum + e.cost))) {
          throw const FormatException(
            'التعديل يتعارض مع استرجاع مسجل؛ راجع الاسترجاع أولاً',
          );
        }
        await t.delete('ledger', where: 'entry_id=?', whereArgs: [id]);
      }
      if (d['kind'] == 'refund') await _validateRefund(t, d, excludeId: id);
      final passengerIds = List<int>.from(
        d['passengers'] ?? (d['passenger'] == null ? [] : [d['passenger']]),
      );
      for (final pid in passengerIds) {
        final rows = await t.query(
          'parties',
          where: 'id=? AND kind=?',
          whereArgs: [pid, 'passenger'],
        );
        if (rows.isEmpty) throw const FormatException('المسافر غير موجود');
        final person = _decode(rows.first);
        if (person['customer'] != null && person['customer'] != d['customer']) {
          throw const FormatException('المسافر تابع لزبون آخر');
        }
        if (d['customer'] != null && person['customer'] == null) {
          final payload = Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String),
          );
          payload['customer'] = d['customer'];
          await t.update(
            'parties',
            {'payload': jsonEncode(payload)},
            where: 'id=?',
            whereArgs: [pid],
          );
        }
      }
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
      await audit(
        t,
        id != null
            ? 'تعديل ${types[d['kind']]}'
            : post
            ? 'اعتماد ${types[d['kind']]}'
            : 'حفظ مسودة',
        '$eid',
      );
      return eid;
    });
    await reload();
    return key;
  }

  Future<void> _validateRefund(
    Transaction t,
    Map<String, dynamic> d, {
    int? excludeId,
  }) async {
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
    final all =
        (await t.query(
              'entries',
              where: 'kind=? AND posted=1',
              whereArgs: ['refund'],
            ))
            .map(Entry.row)
            .where(
              (e) => e.data['original'] == original.id && e.id != excludeId,
            );
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
        entryRows.addAll(
          await t.query('entries', where: 'id=?', whereArgs: [id]),
        );
        ledgerRows.addAll(
          await t.query('ledger', where: 'entry_id=?', whereArgs: [id]),
        );
      }
      if (entryRows.isEmpty) {
        throw const FormatException('العملية غير موجودة');
      }
      final placeholders = List.filled(ids.length, '?').join(',');
      await t.delete(
        'ledger',
        where: 'entry_id IN ($placeholders)',
        whereArgs: ids.toList(),
      );
      await t.delete(
        'entries',
        where: 'id IN ($placeholders)',
        whereArgs: ids.toList(),
      );
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
          if ((await t.query(
            'clearance_entries',
            columns: ['id'],
            where: 'id=?',
            whereArgs: [row['id']],
          )).isNotEmpty) {
            throw const FormatException(
              'العملية مصفّاة ولا تعود إلى الحسابات الحالية',
            );
          }
          if ([row['customer'], row['supplier']].any(retiredParties.contains)) {
            throw const FormatException('الحساب مصفّى');
          }
          await t.insert(
            'entries',
            row,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
        for (final row in restoredLedger) {
          await t.insert(
            'ledger',
            row,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      } else if (undoType == 'restoreParty') {
        final before = Map<String, dynamic>.from(payload['before'] as Map);
        if (retiredParties.contains(before['id'])) {
          throw const FormatException('الحساب مصفّى؛ الأرشيف للاطلاع فقط');
        }
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

  Future<void> deleteParty(int id) async {
    await db.transaction((t) async {
      final people = (await t.query('parties')).map(_decode).toList();
      final partyIds = <int>{
        id,
        ...people
            .where((p) => p['kind'] == 'passenger' && p['customer'] == id)
            .map((p) => p['id'] as int),
      };
      final all = (await t.query('entries')).map(Entry.row).toList();
      final ids = all
          .where(
            (e) =>
                partyIds.contains(e.data['customer']) ||
                partyIds.contains(e.data['supplier']),
          )
          .map((e) => e.id!)
          .toSet();
      bool changed;
      do {
        changed = false;
        for (final e in all) {
          if ((ids.contains(e.data['original']) ||
                  ids.contains(e.data['corrects'])) &&
              ids.add(e.id!)) {
            changed = true;
          }
        }
      } while (changed);
      for (final eid in ids) {
        await t.delete('ledger', where: 'entry_id=?', whereArgs: [eid]);
        await t.delete('entries', where: 'id=?', whereArgs: [eid]);
      }
      // Unlink removed passengers from surviving records without changing money.
      for (final e in all.where((e) => !ids.contains(e.id))) {
        final d = Map<String, dynamic>.from(e.data);
        if (partyIds.contains(d['passenger'])) d.remove('passenger');
        d['passengers'] = e.passengers
            .where((pid) => !partyIds.contains(pid))
            .toList();
        await t.update(
          'entries',
          {'payload': jsonEncode(d)},
          where: 'id=?',
          whereArgs: [e.id],
        );
      }
      for (final pid in partyIds) {
        await t.delete('rules', where: 'supplier=?', whereArgs: [pid]);
        await t.delete('parties', where: 'id=?', whereArgs: [pid]);
      }
      // Old undo snapshots must not resurrect data belonging to a deleted account.
      final audits = await t.query('audit');
      for (final row in audits) {
        final payload = Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String),
        );
        bool linked(Map row) =>
            partyIds.contains(row['customer']) ||
            partyIds.contains(row['supplier']) ||
            partyIds.contains(row['party']);
        final before = payload['before'];
        if ((payload['undoType'] == 'restoreParty' &&
                before is Map &&
                partyIds.contains(before['id'])) ||
            (payload['entries'] is List &&
                (payload['entries'] as List).any((e) => linked(e as Map))) ||
            (payload['ledger'] is List &&
                (payload['ledger'] as List).any((e) => linked(e as Map)))) {
          await t.delete('audit', where: 'id=?', whereArgs: [row['id']]);
        }
      }
      await audit(t, 'حذف حساب وبياناته', '$id');
    });
    await reload();
  }

  int expenseBalance(Currency currency) {
    int value = 0;
    for (final e in entries.where((e) => e.posted && e.currency == currency)) {
      if (['ticket', 'hotel', 'visa', 'refund'].contains(e.kind)) {
        value += e.profit * (e.kind == 'refund' ? -1 : 1);
      }
      if (e.kind == 'funding') value += e.data['amount'] as int? ?? 0;
      if (e.kind == 'expense') value -= e.data['amount'] as int? ?? 0;
    }
    return value;
  }

  List<String> reviewIssues(Entry e) {
    final problems = <String>[];
    if (!e.posted) problems.add('مسودة تحتاج مراجعة');
    if (['ticket', 'visa', 'hotel'].contains(e.kind)) {
      if (e.data['customer'] == null) problems.add('حساب الزبون غير محدد');
      if (e.data['supplier'] == null) problems.add('جهة الإصدار غير محددة');
      if (e.sale == 0) problems.add('سعر البيع صفر');
      if (e.cost == 0) problems.add('التكلفة صفر');
      if (e.profit < 0) problems.add('عملية بخسارة');
      if (e.passengers.isNotEmpty &&
          e.kind != 'hotel' &&
          e.passengers.length != e.quantity) {
        problems.add('عدد المسافرين يختلف عن عدد الخدمة');
      }
    }
    if (e.data['passengers'] is List &&
        (e.data['passengers'] as List).length != e.passengers.toSet().length) {
      problems.add('مسافر مكرر');
    }
    return problems;
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
      'payable': -(values['payable'] ?? 0),
    };
  }
}
