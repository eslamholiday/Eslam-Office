import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';

Future<int?> editParty(
  BuildContext c,
  Store s,
  String kind, {
  Map<String, dynamic>? party,
}) => Navigator.push<int>(
  c,
  MaterialPageRoute(builder: (_) => PartyForm(s, kind, party: party)),
);

class PartyForm extends StatefulWidget {
  final Store s;
  final String kind;
  final Map<String, dynamic>? party;
  const PartyForm(this.s, this.kind, {super.key, this.party});
  @override
  State<PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<PartyForm> {
  late final name = TextEditingController(text: widget.party?['name'] ?? '');
  late final phone = TextEditingController(text: widget.party?['phone'] ?? '');
  late final notes = TextEditingController(text: widget.party?['notes'] ?? '');
  late final passport = TextEditingController(
    text: widget.party?['passport'] ?? '',
  );
  late int? family = widget.party?['family'],
      customer = widget.party?['customer'];
  late List<String> attachments = List<String>.from(
    widget.party?['attachments'] ?? [],
  );
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    passport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.party == null ? 'إضافة' : 'تعديل'} ${{'customer': 'زبون', 'supplier': 'جهة إصدار', 'passenger': 'مسافر', 'family': 'عائلة'}[widget.kind]}',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section('البيانات الأساسية', [
          textField(name, 'الاسم'),
          if (widget.kind != 'family') ...[
            Row(
              children: [
                Expanded(child: textField(phone, 'رقم الهاتف', number: true)),
                IconButton(
                  tooltip: 'اختيار من جهات الاتصال',
                  onPressed: () => guarded(c, () async {
                    if (!await FlutterContacts.requestPermission(
                      readonly: true,
                    )) {
                      return;
                    }
                    final picked = await FlutterContacts.openExternalPick();
                    if (picked != null) {
                      final full = await FlutterContacts.getContact(
                        picked.id,
                        withProperties: true,
                      );
                      if (full != null) {
                        setState(() {
                          if (name.text.isEmpty) name.text = full.displayName;
                          phone.text = full.phones.firstOrNull?.number ?? '';
                        });
                      }
                    }
                  }),
                  icon: const Icon(Icons.contacts_outlined),
                ),
              ],
            ),
            if (widget.kind != 'supplier')
              PickField(
                'العائلة',
                family,
                widget.s.list('family'),
                (v) => setState(() => family = v),
                add: () => editParty(c, widget.s, 'family'),
              ),
            if (widget.kind == 'passenger') ...[
              PickField(
                'حساب الزبون',
                customer,
                widget.s.list('customer'),
                (v) => setState(() => customer = v),
                add: () => editParty(c, widget.s, 'customer'),
              ),
              textField(passport, 'رقم الجواز (اختياري)'),
            ],
          ],
          textField(notes, 'ملاحظات', lines: 3),
        ]),
        Section('المرفقات', [
          Attachments(attachments, (v) => setState(() => attachments = v)),
        ]),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final id = await widget.s.saveParty({
                      'kind': widget.kind,
                      'name': name.text.trim().isEmpty
                          ? 'بدون اسم'
                          : name.text.trim(),
                      'phone': phone.text.trim(),
                      'notes': notes.text,
                      'passport': passport.text,
                      'family': family,
                      'customer': customer,
                      'attachments': attachments,
                    }, id: widget.party?['id']);
                    if (c.mounted) Navigator.pop(c, id);
                  } catch (e) {
                    if (c.mounted) message(c, e);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ),
    ),
  );
}

class EntryForm extends StatefulWidget {
  final Store s;
  final String kind;
  final Entry? draft;
  final int? party;
  final bool supplier;
  const EntryForm(
    this.s,
    this.kind, {
    super.key,
    this.draft,
    this.party,
    this.supplier = false,
  });
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final Map<String, TextEditingController> controllers = {};
  late Map<String, dynamic> d;
  bool busy = false;
  String? calcError;
  Currency get currency => Currency.values.byName(d['currency']);
  TextEditingController tc(String key, [String value = '']) =>
      controllers.putIfAbsent(key, () => TextEditingController(text: value));
  @override
  void initState() {
    super.initState();
    d = {
      ...Map<String, dynamic>.from(
        widget.s.settings['defaults_${widget.kind}'] ?? {},
      ),
      'kind': widget.kind,
      'currency':
          (widget.s.settings['defaults_${widget.kind}'] as Map?)?['currency'] ??
          widget.s.settings['defaultCurrency'] ??
          'USD',
      'date': day(DateTime.now()),
      'rate': 0,
      'fee': 0,
      'commissionMode': 'percent',
      'qty': 1,
      'partyType': widget.supplier ? 'supplier' : 'customer',
      'direction': -1,
      'settlementMode': 'cash',
      'personal': false,
      'attachments': <String>[],
      ...?(widget.draft?.data),
    };
    if (widget.party != null) {
      d[widget.supplier ? 'supplier' : 'customer'] = widget.party;
    }
    for (final key in [
      'pnr',
      'notes',
      'hotelName',
      'meals',
      'visaType',
      'days',
      'entriesCount',
      'rooms',
      'people',
    ]) {
      tc(key, '${d[key] ?? ''}');
    }
    for (final key in ['sell', 'costUnit', 'amount', 'fee']) {
      tc(key, currency.input(d[key] as int? ?? 0));
    }
    tc('rate', ((d['rate'] as int? ?? 0) / 100).toString());
    tc('qty', '${d['qty'] ?? 1}');
    final lines =
        d['lines'] as List? ??
        [
          {'qty': 1},
          {'qty': 0},
          {'qty': 0},
        ];
    for (var i = 0; i < 3; i++) {
      final row = i < lines.length ? lines[i] : <String, dynamic>{};
      tc('q$i', '${row['qty'] ?? 0}');
      for (final key in ['base', 'gross', 'sell']) {
        tc('$key$i', currency.input(row[key] as int? ?? 0));
      }
    }
    if (widget.draft == null && d['airline'] != null) applyRule();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void applyRule() {
    final r = widget.s.commission(d['airline'], d['supplier']);
    tc('rate').text = ((r['rate'] as int? ?? 0) / 100).toString();
    d['commissionMode'] = r['commissionMode'] ?? 'percent';
    tc('fee').text = currency.input(
      r['currency'] == null || r['currency'] == currency.name
          ? r['fee'] as int? ?? 0
          : 0,
    );
  }

  Map<String, dynamic> collect() {
    final v = Map<String, dynamic>.from(d);
    for (final key in [
      'pnr',
      'notes',
      'hotelName',
      'meals',
      'visaType',
      'days',
      'entriesCount',
      'rooms',
      'people',
    ]) {
      v[key] = tc(key).text.trim();
    }
    if (widget.kind == 'ticket') {
      v['rate'] = decimalUnits(tc('rate').text, 2);
      v['fee'] = money(tc('fee').text, currency);
      v['lines'] = [
        for (var i = 0; i < 3; i++)
          {
            'qty': decimalUnits(tc('q$i').text, 0),
            'base': money(tc('base$i').text, currency),
            'gross': money(tc('gross$i').text, currency),
            'sell': money(tc('sell$i').text, currency),
          },
      ];
    }
    if (['visa', 'hotel'].contains(widget.kind)) {
      v['qty'] = decimalUnits(tc('qty').text, 0);
      v['sell'] = money(tc('sell').text, currency);
      v['costUnit'] = money(tc('costUnit').text, currency);
    }
    if (['expense', 'settlement', 'opening'].contains(widget.kind)) {
      v['amount'] = money(tc('amount').text, currency);
    }
    return v;
  }

  Future<void> save(bool post) async {
    setState(() => busy = true);
    try {
      final v = collect();
      v['posted'] = post;
      await widget.s.saveEntry(v, id: widget.draft?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String key, String label, {bool number = false}) => textField(
    tc(key),
    label,
    number: number,
    onChanged: (_) => setState(() {}),
  );
  Widget pick(String key, String label, String kind, {bool party = false}) =>
      PickField(
        label,
        d[key],
        party ? widget.s.list(kind) : widget.s.referenceList(kind),
        (v) => setState(() {
          d[key] = v;
          if (key == 'airline') {
            final ref = widget.s.refs.where((r) => r['id'] == v).firstOrNull;
            final hasPrices = controllers.entries.any(
              (p) =>
                  RegExp(r'^(base|gross|sell)[0-2]$').hasMatch(p.key) &&
                  (double.tryParse(p.value.text) ?? 0) != 0,
            );
            if (!hasPrices && ref != null) {
              d['currency'] = ref['currency'] ?? d['currency'];
            }
          }
          if (key == 'airline' || key == 'supplier') applyRule();
        }),
        add: party ? () => editParty(context, widget.s, kind) : null,
      );
  Widget date(String key, String label) =>
      DateField(label, d[key], (v) => setState(() => d[key] = v));
  Widget category(int i, String label) => Column(
    children: [
      field('q$i', 'العدد', number: true),
      pair(
        field('base$i', 'الأساسي للوحدة', number: true),
        field('gross$i', 'الشامل للوحدة', number: true),
      ),
      field('sell$i', 'سعر البيع للوحدة', number: true),
    ],
  );
  List<Widget> optionalFields() {
    final available = <String, Widget>{
      'passenger': pick('passenger', 'المسافر', 'passenger', party: true),
      'country': pick('country', 'الدولة', 'country'),
      'from': pick('from', 'مدينة المغادرة', 'city'),
      'to': pick('to', 'مدينة الوصول', 'city'),
      'depart': date('depart', 'تاريخ الذهاب'),
      'return': date('return', 'تاريخ العودة'),
      'pnr': field('pnr', 'PNR (اختياري)'),
      'city': pick('city', 'المدينة', 'city'),
      'meals': field('meals', 'الوجبات'),
      'rooms': field('rooms', 'عدد الغرف', number: true),
      'people': field('people', 'عدد الأشخاص', number: true),
      'applyDate': date('applyDate', 'تاريخ التقديم'),
      'issueDate': date('issueDate', 'تاريخ الإصدار'),
      'expiry': date('expiry', 'تاريخ الانتهاء'),
      'days': field('days', 'عدد الأيام', number: true),
      'entriesCount': field('entriesCount', 'عدد الدخولات', number: true),
    };
    final keys = switch (widget.kind) {
      'ticket' => [
        'passenger',
        'country',
        'from',
        'to',
        'depart',
        'return',
        'pnr',
      ],
      'hotel' => ['passenger', 'country', 'city', 'rooms', 'people', 'meals'],
      'visa' => [
        'passenger',
        'country',
        'applyDate',
        'issueDate',
        'expiry',
        'days',
        'entriesCount',
      ],
      _ => <String>[],
    };
    final order = List<String>.from(
      widget.s.settings['fields_${widget.kind}'] ?? keys,
    );
    final hidden = List<String>.from(
      widget.s.settings['hidden_${widget.kind}'] ?? [],
    );
    return [
      ...{...order, ...keys}
          .where((k) => keys.contains(k) && !hidden.contains(k))
          .map((k) => available[k]!),
    ];
  }

  @override
  Widget build(BuildContext c) {
    final sale = ['ticket', 'hotel', 'visa'].contains(widget.kind);
    Totals? totals;
    try {
      if (sale) totals = calculate(collect());
      calcError = null;
    } catch (e) {
      calcError = e.toString().replaceFirst('FormatException: ', '');
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.draft == null ? 'إضافة' : 'تعديل'} ${types[widget.kind]}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section('معلومات العملية', [
            if (sale) pick('customer', 'حساب الزبون', 'customer', party: true),
            if (widget.kind == 'settlement' || widget.kind == 'opening') ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'customer', label: Text('زبون')),
                  ButtonSegment(value: 'supplier', label: Text('جهة إصدار')),
                ],
                selected: {d['partyType']},
                onSelectionChanged: (v) => setState(() {
                  d['partyType'] = v.first;
                  d['customer'] = null;
                  d['supplier'] = null;
                }),
              ),
              const SizedBox(height: 16),
              pick(d['partyType'], 'الحساب', d['partyType'], party: true),
            ],
            pair(
              DropdownButtonFormField<String>(
                key: ValueKey(currency.name),
                initialValue: currency.name,
                decoration: const InputDecoration(labelText: 'العملة'),
                items: Currency.values
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v.name, child: Text(v.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  d['currency'] = v;
                  if (widget.kind == 'ticket') applyRule();
                }),
              ),
              DateField(
                'تاريخ العملية',
                d['date'],
                (v) => setState(() => d['date'] = v),
                optional: false,
              ),
            ),
            if (sale)
              pick('supplier', 'جهة الإصدار / المورد', 'supplier', party: true),
            if (widget.kind == 'ticket')
              pick('airline', 'شركة الطيران', 'airline'),
          ]),
          if (widget.kind == 'ticket') ...[
            Section('العمولة', [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'percent', label: Text('خصم عمولة')),
                  ButtonSegment(value: 'fee', label: Text('رسم إصدار إضافي')),
                ],
                selected: {d['commissionMode']},
                onSelectionChanged: (v) =>
                    setState(() => d['commissionMode'] = v.first),
              ),
              const SizedBox(height: 16),
              if (d['commissionMode'] == 'percent')
                field('rate', 'نسبة العمولة من السعر الأساسي %', number: true)
              else
                field('fee', 'رسم الإصدار لكل تذكرة', number: true),
            ]),
            Section('بالغ / Adult', [category(0, 'بالغ')]),
            Card(
              child: ExpansionTile(
                title: Text('طفل / Child — ${tc('q1').text}'),
                childrenPadding: const EdgeInsets.all(16),
                children: [category(1, 'طفل')],
              ),
            ),
            Card(
              child: ExpansionTile(
                title: Text('رضيع / Infant — ${tc('q2').text}'),
                childrenPadding: const EdgeInsets.all(16),
                children: [category(2, 'رضيع')],
              ),
            ),
          ],
          if (widget.kind == 'hotel')
            Section('الحجز', [
              field('hotelName', 'اسم الفندق'),
              pair(
                date('checkIn', 'تاريخ الدخول'),
                date('checkOut', 'تاريخ الخروج'),
              ),
              if (d['checkIn'] != null && d['checkOut'] != null)
                Text(
                  'عدد الليالي: ${DateTime.parse(d['checkOut']).difference(DateTime.parse(d['checkIn'])).inDays}',
                ),
              const SizedBox(height: 12),
              field('costUnit', 'التكلفة الكاملة للحجز', number: true),
              field('sell', 'البيع الكامل للحجز', number: true),
            ]),
          if (widget.kind == 'visa')
            Section('تفاصيل الفيزا', [
              field('visaType', 'نوع الفيزا'),
              field('qty', 'العدد', number: true),
              pair(
                field('costUnit', 'تكلفة الواحدة', number: true),
                field('sell', 'بيع الواحدة', number: true),
              ),
            ]),
          if (widget.kind == 'settlement' || widget.kind == 'opening')
            Section('حركة الحساب', [
              field('amount', 'المبلغ', number: true),
              DropdownButtonFormField<int>(
                initialValue: d['direction'],
                decoration: const InputDecoration(labelText: 'أثر الحركة'),
                items: const [
                  DropdownMenuItem(
                    value: -1,
                    child: Text('تخفيض المستحق / إضافة رصيد'),
                  ),
                  DropdownMenuItem(value: 1, child: Text('زيادة المستحق')),
                ],
                onChanged: (v) => setState(() => d['direction'] = v),
              ),
              if (widget.kind == 'settlement')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: d['settlementMode'],
                    decoration: const InputDecoration(labelText: 'نوع التسوية'),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('قبض / دفع نقدي'),
                      ),
                      DropdownMenuItem(
                        value: 'adjustment',
                        child: Text('تسوية رصيد دون نقد'),
                      ),
                    ],
                    onChanged: (v) => setState(() => d['settlementMode'] = v),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('التسوية والرصيد الافتتاحي لا يغيّران ربح الخدمات.'),
            ]),
          if (widget.kind == 'expense')
            Section('المصروف', [
              field('amount', 'المبلغ', number: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مصروف شخصي'),
                subtitle: const Text('الشخصي لا يخصم من صافي ربح المكتب'),
                value: d['personal'] == true,
                onChanged: (v) => setState(() => d['personal'] = v),
              ),
            ]),
          if (sale) Section('تفاصيل إضافية', optionalFields()),
          if (sale)
            Section('النتيجة المباشرة', [
              if (calcError != null)
                Text(calcError!, style: const TextStyle(color: Colors.red)),
              if (totals != null) ...[
                pair(
                  AmountBox('البيع', currency.format(totals.sale)),
                  AmountBox('التسديد', currency.format(totals.cost)),
                ),
                pair(
                  AmountBox('العمولة', currency.format(totals.commission)),
                  AmountBox(
                    'الربح',
                    currency.format(totals.profit),
                    color: totals.profit < 0
                        ? Colors.red
                        : const Color(0xff23836c),
                  ),
                ),
              ],
            ]),
          Section('الملاحظات والمرفقات', [
            field('notes', 'ملاحظات / سبب الحركة'),
            Attachments(
              List<String>.from(d['attachments']),
              (v) => setState(() => d['attachments'] = v),
            ),
          ]),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : () => save(true),
                  icon: const Icon(Icons.check),
                  label: Text(busy ? 'جارٍ الحفظ…' : 'حفظ واعتماد'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: busy ? null : () => save(false),
                child: const Text('مسودة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> newEntry(
  BuildContext c,
  Store s,
  String kind, {
  Entry? draft,
  int? party,
  bool supplier = false,
}) async {
  await Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) =>
          EntryForm(s, kind, draft: draft, party: party, supplier: supplier),
    ),
  );
}

Future<void> refundDialog(BuildContext c, Store s, Entry e) async {
  final previous = s.entries.where(
    (r) => r.kind == 'refund' && r.posted && r.data['original'] == e.id,
  );
  final remainingSale = e.sale - previous.fold<int>(0, (a, r) => a + r.sale),
      remainingCost = e.cost - previous.fold<int>(0, (a, r) => a + r.cost);
  final sale = TextEditingController(text: e.currency.input(remainingSale)),
      cost = TextEditingController(text: e.currency.input(remainingCost)),
      note = TextEditingController();
  String date = day(DateTime.now());
  bool busy = false;
  await showDialog(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('استرجاع العملية #${e.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يُخفض حساب الزبون والمورد والربح. إعادة النقد تُسجل بتسوية منفصلة.',
              ),
              const SizedBox(height: 16),
              textField(sale, 'المبلغ المسترجع للزبون', number: true),
              textField(cost, 'المبلغ المسترجع من المورد', number: true),
              DateField(
                'التاريخ',
                date,
                (v) => set(() => date = v!),
                optional: false,
              ),
              textField(note, 'السبب'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    try {
                      await s.saveEntry({
                        'kind': 'refund',
                        'original': e.id,
                        'customer': e.data['customer'],
                        'supplier': e.data['supplier'],
                        'currency': e.currency.name,
                        'date': date,
                        'sale': money(sale.text, e.currency),
                        'cost': money(cost.text, e.currency),
                        'notes': note.text,
                        'posted': true,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      if (ctx.mounted) message(ctx, error);
                    } finally {
                      if (ctx.mounted) set(() => busy = false);
                    }
                  },
            child: const Text('اعتماد الاسترجاع'),
          ),
        ],
      ),
    ),
  );
  // Controllers are owned by the dialog and released after its exit animation.
  Future.delayed(const Duration(milliseconds: 400), () {
    sale.dispose();
    cost.dispose();
    note.dispose();
  });
}
