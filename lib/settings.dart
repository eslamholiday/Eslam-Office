import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';

const themeNames = [
  'مكتب فاخر',
  'سفر ملون',
  'ليلي هادئ',
  'أبيض احترافي',
  'زجاجي',
  'ذهبي فاخر',
  'أزرق طيران',
  'بسيط',
  'بطاقات ناعمة',
  'تقني حديث',
];
const themeColors = [
  navy,
  Color(0xff087F8C),
  Color(0xff808BC7),
  Color(0xff36556D),
  Color(0xff5D78B1),
  Color(0xffA57520),
  Color(0xff1976C9),
  Color(0xff49535B),
  Color(0xffAD7190),
  Color(0xff526BD1),
];
const navLabels = {
  'home': 'الرئيسية',
  'entries': 'العمليات',
  'customers': 'الزبائن',
  'suppliers': 'جهات الإصدار / الموردون',
  'reports': 'التقارير',
};
const fieldNames = {
  'passenger': 'المسافر',
  'country': 'الدولة',
  'from': 'المغادرة',
  'to': 'الوصول',
  'depart': 'الذهاب',
  'return': 'العودة',
  'city': 'المدينة',
  'rooms': 'الغرف',
  'people': 'الأشخاص',
  'meals': 'الوجبات',
  'applyDate': 'التقديم',
  'issueDate': 'الإصدار',
  'expiry': 'الانتهاء',
  'days': 'الأيام',
  'entriesCount': 'الدخولات',
};
const fieldGroups = {
  'ticket': ['passenger', 'country', 'from', 'to', 'depart', 'return'],
  'hotel': ['passenger', 'country', 'city', 'rooms', 'people', 'meals'],
  'visa': [
    'passenger',
    'country',
    'applyDate',
    'issueDate',
    'expiry',
    'days',
    'entriesCount',
  ],
};

class SettingsPage extends StatelessWidget {
  final Store s;
  const SettingsPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section('المظهر والتخصيص', [
            tile(
              c,
              'الثيمات والألوان والخطوط',
              Icons.palette_outlined,
              AppearancePage(s),
            ),
          ]),
          Section('الواجهات والأقسام', [
            tile(
              c,
              'الرئيسية وشريط التنقل',
              Icons.dashboard_customize_outlined,
              LayoutPage(s),
            ),
            for (final kind in ['ticket', 'hotel', 'visa'])
              tile(
                c,
                '${types[kind]} — الحقول والافتراضيات',
                kindIcon(kind),
                FieldSettings(s, kind),
              ),
            tile(
              c,
              'بيانات المكتب والشعار والكشوف',
              Icons.business_outlined,
              OfficeSettings(s),
            ),
          ]),
          Section('النظام', [
            for (final item in {
              'airline': 'شركات الطيران',
              'country': 'الدول',
              'city': 'المدن',
            }.entries)
              tile(
                c,
                item.value,
                Icons.list_alt,
                ReferencePage(s, item.key, item.value),
              ),
            tile(
              c,
              'عمولات الطيران × جهات الإصدار',
              Icons.percent,
              RulesPage(s),
            ),
            tile(
              c,
              'المحذوفات / الأرشيف',
              Icons.archive_outlined,
              ArchivePage(s),
            ),
            tile(c, 'سجل التعديلات', Icons.history, AuditPage(s)),
            tile(c, 'حول Eslam Office', Icons.info_outline, AboutPage(s)),
          ]),
        ],
      ),
    ),
  );
  Widget tile(BuildContext c, String title, IconData icon, Widget page) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
      );
}

class AppearancePage extends StatelessWidget {
  final Store s;
  const AppearancePage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: AppBar(title: const Text('المظهر')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section('الثيمات', [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                themeNames.length,
                (i) => ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: themeColors[i],
                    radius: 10,
                  ),
                  label: Text(themeNames[i]),
                  onPressed: () async {
                    final apply = await showDialog<bool>(
                      context: c,
                      builder: (ctx) => AlertDialog(
                        title: Text(themeNames[i]),
                        content: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: themeColors[i].withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flight_takeoff,
                                size: 50,
                                color: themeColors[i],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Eslam Office',
                                style: TextStyle(
                                  color: themeColors[i],
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('معاينة اللون الأساسي والبطاقات'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تطبيق'),
                          ),
                        ],
                      ),
                    );
                    if (apply == true) {
                      await s.set('theme', i);
                      await s.set('color', themeColors[i].toARGB32());
                      if (i == 2) await s.set('dark', true);
                    }
                  },
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الوضع الداكن'),
              value: s.settings['dark'] == true,
              onChanged: (v) => s.set('dark', v),
            ),
          ]),
          Section('اللون الرئيسي', [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  [
                        navy,
                        gold,
                        Colors.teal,
                        Colors.indigo,
                        Colors.blue,
                        Colors.purple,
                        Colors.deepOrange,
                        Colors.green,
                        Colors.pink,
                        Colors.blueGrey,
                      ]
                      .map(
                        (color) => InkWell(
                          onTap: () => s.set('color', color.toARGB32()),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: color,
                            child: s.settings['color'] == color.toARGB32()
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ]),
          Section('النصوص والبطاقات', [
            const Text('حجم النص'),
            Slider(
              value: (s.settings['textScale'] as num? ?? 1).toDouble(),
              min: .85,
              max: 1.35,
              divisions: 10,
              label: '${s.settings['textScale'] ?? 1}',
              onChanged: (v) => s.set('textScale', v),
            ),
            const Text('استدارة البطاقات'),
            Slider(
              value: (s.settings['radius'] as num? ?? 18).toDouble(),
              min: 4,
              max: 30,
              divisions: 13,
              onChanged: (v) => s.set('radius', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('كثافة مدمجة'),
              value: s.settings['compact'] == true,
              onChanged: (v) => s.set('compact', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تقليل الحركة'),
              value: s.settings['reduceMotion'] == true,
              onChanged: (v) => s.set('reduceMotion', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار العناوين الإنجليزية الثانوية'),
              value: s.settings['showEnglishLabels'] != false,
              onChanged: (v) => s.set('showEnglishLabels', v),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: () async {
                for (final p in {
                  'theme': 0,
                  'color': navy.toARGB32(),
                  'dark': false,
                  'textScale': 1.0,
                  'radius': 18.0,
                  'compact': false,
                  'reduceMotion': false,
                }.entries) {
                  await s.set(p.key, p.value);
                }
              },
              child: const Text('استعادة المظهر الافتراضي'),
            ),
          ),
        ],
      ),
    ),
  );
}

class LayoutPage extends StatelessWidget {
  final Store s;
  const LayoutPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final nav = List<String>.from(
        s.settings['navOrder'] ?? navLabels.keys.toList(),
      );
      final hidden = List<String>.from(s.settings['navHidden'] ?? []);
      final cards = List<String>.from(
        s.settings['homeCards'] ?? ['owed', 'credit', 'profit', 'sale'],
      );
      return Scaffold(
        appBar: AppBar(title: const Text('الرئيسية والتنقل')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Section('شاشة البداية', [
              DropdownButtonFormField<String>(
                initialValue: s.settings['start'] ?? 'home',
                items: navLabels.entries
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p.key, child: Text(p.value)),
                    )
                    .toList(),
                onChanged: (v) => s.set('start', v),
              ),
            ]),
            Section('ترتيب شريط التنقل بالسحب', [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (a, b) {
                  if (b > a) b--;
                  final v = nav.removeAt(a);
                  nav.insert(b, v);
                  s.set('navOrder', nav);
                },
                children: nav
                    .map(
                      (key) => CheckboxListTile(
                        key: ValueKey(key),
                        title: Text(navLabels[key]!),
                        value: !hidden.contains(key),
                        onChanged: (v) {
                          if (v == false && nav.length - hidden.length <= 2) {
                            message(c, 'أبقِ قسمين على الأقل في شريط التنقل');
                            return;
                          }
                          if (v == true) {
                            hidden.remove(key);
                          } else {
                            hidden.add(key);
                          }
                          s.set('navHidden', hidden);
                        },
                      ),
                    )
                    .toList(),
              ),
            ]),
            Section('ترتيب بطاقات الرئيسية بالسحب', [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (a, b) {
                  if (b > a) b--;
                  final v = cards.removeAt(a);
                  cards.insert(b, v);
                  s.set('homeCards', cards);
                },
                children: cards
                    .map(
                      (key) => ListTile(
                        key: ValueKey(key),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(
                          {
                            'owed': 'المطلوب من الزبائن',
                            'credit': 'أرصدة لصالح الزبائن',
                            'profit': 'ربح الخدمات',
                            'sale': 'مبيعات الخدمات',
                          }[key]!,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ]),
            OutlinedButton(
              onPressed: () async {
                await s.set('homeCards', ['owed', 'credit', 'profit', 'sale']);
                await s.set('navOrder', navLabels.keys.toList());
                await s.set('navHidden', []);
                await s.set('start', 'home');
              },
              child: const Text('استعادة ترتيب الواجهات'),
            ),
          ],
        ),
      );
    },
  );
}

class FieldSettings extends StatelessWidget {
  final Store s;
  final String kind;
  const FieldSettings(this.s, this.kind, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final order = List<String>.from(
        s.settings['fields_$kind'] ?? fieldGroups[kind],
      );
      final hidden = List<String>.from(s.settings['hidden_$kind'] ?? []);
      final defaults = Map<String, dynamic>.from(
        s.settings['defaults_$kind'] ?? {},
      );
      return Scaffold(
        appBar: AppBar(title: Text('إعدادات ${types[kind]}')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Section('افتراضيات من القوائم المحفوظة', [
              PickField(
                'جهة الإصدار',
                defaults['supplier'],
                s.list('supplier'),
                (v) {
                  defaults['supplier'] = v;
                  s.set('defaults_$kind', defaults);
                },
              ),
              if (kind == 'ticket') ...[
                PickField(
                  'شركة الطيران',
                  defaults['airline'],
                  s.referenceList('airline'),
                  (v) {
                    defaults['airline'] = v;
                    s.set('defaults_$kind', defaults);
                  },
                ),
                PickField(
                  'مدينة المغادرة',
                  defaults['from'],
                  s.referenceList('city'),
                  (v) {
                    defaults['from'] = v;
                    s.set('defaults_$kind', defaults);
                  },
                ),
              ],
              PickField(
                'الدولة',
                defaults['country'],
                s.referenceList('country'),
                (v) {
                  defaults['country'] = v;
                  s.set('defaults_$kind', defaults);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: defaults['currency'] ?? 'USD',
                decoration: const InputDecoration(
                  labelText: 'العملة الافتراضية',
                ),
                items: Currency.values
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v.name, child: Text(v.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  defaults['currency'] = v;
                  s.set('defaults_$kind', defaults);
                },
              ),
            ]),
            Section('ترتيب وإظهار الحقول الاختيارية', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => s.set('hidden_$kind', <String>[]),
                    child: const Text('إظهار الكل'),
                  ),
                  OutlinedButton(
                    onPressed: () => s.set(
                      'hidden_$kind',
                      List<String>.from(fieldGroups[kind] ?? const <String>[]),
                    ),
                    child: const Text('إخفاء الاختياري'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final visible = order
                          .where((key) => !hidden.contains(key))
                          .map((key) => fieldNames[key] ?? key)
                          .toList();
                      showDialog<void>(
                        context: c,
                        builder: (ctx) => AlertDialog(
                          title: const Text('معاينة ترتيب النموذج'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: visible.isEmpty
                                ? const Text('لا توجد حقول اختيارية ظاهرة.')
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) => ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 13,
                                        child: Text('${i + 1}'),
                                      ),
                                      title: Text(visible[i]),
                                    ),
                                  ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('إغلاق'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('معاينة النموذج'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (a, b) {
                  if (b > a) b--;
                  final key = order.removeAt(a);
                  order.insert(b, key);
                  s.set('fields_$kind', order);
                },
                children: order
                    .map(
                      (key) => CheckboxListTile(
                        key: ValueKey(key),
                        title: Text(fieldNames[key]!),
                        value: !hidden.contains(key),
                        onChanged: (v) {
                          if (v == true) {
                            hidden.remove(key);
                          } else {
                            hidden.add(key);
                          }
                          s.set('hidden_$kind', hidden);
                        },
                      ),
                    )
                    .toList(),
              ),
            ]),
            TextButton(
              onPressed: () async {
                await s.set('fields_$kind', fieldGroups[kind]);
                await s.set('hidden_$kind', []);
                await s.set('defaults_$kind', {});
              },
              child: const Text('استعادة إعدادات هذا القسم'),
            ),
          ],
        ),
      );
    },
  );
}

class OfficeSettings extends StatefulWidget {
  final Store s;
  const OfficeSettings(this.s, {super.key});
  @override
  State<OfficeSettings> createState() => _OfficeSettingsState();
}

class _OfficeSettingsState extends State<OfficeSettings> {
  late final office = TextEditingController(
        text: widget.s.settings['office'] ?? 'Eslam Holiday',
      ),
      phone = TextEditingController(
        text: widget.s.settings['phone'] ?? '07713414312',
      ),
      website = TextEditingController(
        text: widget.s.settings['website'] ?? 'Eslamholiday.com',
      ),
      footer = TextEditingController(
        text: widget.s.settings['footer'] ?? 'جميع الحقوق محفوظة 2026',
      );
  @override
  void dispose() {
    for (final c in [office, phone, website, footer]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('هوية المكتب والكشوف')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section('بيانات المكتب', [
          textField(office, 'اسم المكتب'),
          textField(phone, 'الهاتف'),
          textField(website, 'الموقع'),
          textField(footer, 'تذييل الكشف'),
        ]),
        Section('شعار الكشف', [
          Attachments(
            widget.s.settings['logo'] == null
                ? []
                : [widget.s.settings['logo']],
            (v) async {
              await widget.s.set('logo', v.isEmpty ? null : v.last);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('إظهار الشعار'),
            value: widget.s.settings['showLogo'] != false,
            onChanged: (v) async {
              await widget.s.set('showLogo', v);
              setState(() {});
            },
          ),
        ]),
        FilledButton(
          onPressed: () async {
            for (final e in {
              'office': office.text,
              'phone': phone.text,
              'website': website.text,
              'footer': footer.text,
            }.entries) {
              await widget.s.set(e.key, e.value);
            }
            if (c.mounted) Navigator.pop(c);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class ReferencePage extends StatelessWidget {
  final Store s;
  final String kind, title;
  const ReferencePage(this.s, this.kind, this.title, {super.key});
  Future<void> edit(BuildContext c, [Map<String, dynamic>? r]) async {
    final name = TextEditingController(text: r?['name'] ?? ''),
        code = TextEditingController(text: r?['code'] ?? ''),
        rate = TextEditingController(
          text: ((r?['rate'] ?? 0) / 100).toString(),
        ),
        fee = TextEditingController(
          text: Currency.values
              .byName(r?['currency'] ?? 'USD')
              .input(r?['fee'] ?? 0),
        );
    String currency = r?['currency'] ?? 'USD',
        mode = r?['commissionMode'] ?? 'percent';
    await showDialog(
      context: c,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(r == null ? 'إضافة' : 'تعديل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                textField(name, 'الاسم'),
                if (kind == 'airline') ...[
                  textField(code, 'رمز الطيران'),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    items: Currency.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.name,
                            child: Text(v.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => currency = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    items: const [
                      DropdownMenuItem(
                        value: 'percent',
                        child: Text('نسبة خصم من الأساسي'),
                      ),
                      DropdownMenuItem(
                        value: 'fee',
                        child: Text('رسم إصدار إضافي'),
                      ),
                    ],
                    onChanged: (v) => set(() => mode = v!),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'percent')
                    textField(rate, 'العمولة الافتراضية %', number: true)
                  else
                    textField(fee, 'رسم الإصدار للوحدة', number: true),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => guarded(ctx, () async {
                if (name.text.trim().isEmpty) {
                  throw const FormatException('أدخل الاسم');
                }
                final pct = decimalUnits(rate.text, 2);
                if (pct > 10000) {
                  throw const FormatException('العمولة أكبر من 100%');
                }
                await s.saveRef(kind, name.text.trim(), {
                  'code': code.text,
                  'rate': pct,
                  'fee': money(fee.text, Currency.values.byName(currency)),
                  'currency': currency,
                  'commissionMode': mode,
                }, id: r?['id']);
                if (ctx.mounted) Navigator.pop(ctx);
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final t in [name, code, rate, fee]) {
        t.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: () => edit(c), icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView(
        children: s.refs
            .where((r) => r['kind'] == kind)
            .map(
              (r) => ListTile(
                title: Text(r['name']),
                subtitle: Text(r['code'] ?? ''),
                onTap: () => edit(c, r),
                trailing: Switch(
                  value: r['archived'] == 0,
                  onChanged: (v) => s.saveRef(kind, r['name'], {
                    ...r,
                    'archived': v ? 0 : 1,
                  }, id: r['id']),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class RulesPage extends StatefulWidget {
  final Store s;
  const RulesPage(this.s, {super.key});
  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  int? airline, supplier;
  String mode = 'percent', currency = 'USD';
  final rate = TextEditingController(text: '0'),
      fee = TextEditingController(text: '0');
  @override
  void dispose() {
    rate.dispose();
    fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('قواعد العمولات')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section('قاعدة خاصة للطيران وجهة الإصدار', [
          PickField(
            'شركة الطيران',
            airline,
            widget.s.referenceList('airline'),
            (v) => setState(() => airline = v),
          ),
          PickField(
            'جهة الإصدار',
            supplier,
            widget.s.list('supplier'),
            (v) => setState(() => supplier = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: mode,
            items: const [
              DropdownMenuItem(
                value: 'percent',
                child: Text('خصم عمولة من الأساسي'),
              ),
              DropdownMenuItem(value: 'fee', child: Text('إضافة رسم إصدار')),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 12),
          if (mode == 'percent')
            textField(rate, 'العمولة %', number: true)
          else ...[
            DropdownButtonFormField<String>(
              initialValue: currency,
              items: Currency.values
                  .map(
                    (v) => DropdownMenuItem(value: v.name, child: Text(v.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => currency = v!),
            ),
            const SizedBox(height: 12),
            textField(fee, 'رسم إصدار التذكرة الواحدة', number: true),
          ],
          FilledButton(
            onPressed: () => guarded(c, () async {
              if (airline == null || supplier == null) {
                throw const FormatException('اختر الطيران وجهة الإصدار');
              }
              final pct = decimalUnits(rate.text, 2);
              if (pct > 10000) {
                throw const FormatException('العمولة أكبر من 100%');
              }
              await widget.s.saveRule({
                'airline': airline,
                'supplier': supplier,
                'rate': pct,
                'commissionMode': mode,
                'fee': money(fee.text, Currency.values.byName(currency)),
                'currency': currency,
              });
              setState(() {});
              if (c.mounted) {
                message(c, 'حُفظت القاعدة. العمليات السابقة لا تتغيّر.');
              }
            }),
            child: const Text('حفظ القاعدة'),
          ),
        ]),
        ...widget.s.rules.map(
          (r) => Card(
            child: ListTile(
              title: Text(
                '${widget.s.reference(r['airline'])} × ${widget.s.name(r['supplier'])}',
              ),
              subtitle: Text(
                r['commissionMode'] == 'fee'
                    ? 'رسم إصدار ${Currency.values.byName(r['currency'] ?? 'USD').format(r['fee'] ?? 0)}'
                    : 'خصم ${(r['rate'] ?? 0) / 100}%',
              ),
              onTap: () => setState(() {
                airline = r['airline'];
                supplier = r['supplier'];
                mode = r['commissionMode'] ?? 'percent';
                currency = r['currency'] ?? 'USD';
                rate.text = ((r['rate'] ?? 0) / 100).toString();
                fee.text = Currency.values
                    .byName(currency)
                    .input(r['fee'] ?? 0);
              }),
            ),
          ),
        ),
      ],
    ),
  );
}

class ArchivePage extends StatelessWidget {
  final Store s;
  const ArchivePage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: AppBar(title: const Text('الحسابات المؤرشفة')),
      body: ListView(
        children: s.parties
            .where((p) => p['archived'] == 1)
            .map(
              (p) => ListTile(
                title: Text(p['name']),
                trailing: TextButton(
                  onPressed: () => s.archiveParty(p['id'], false),
                  child: const Text('استعادة'),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class AuditPage extends StatelessWidget {
  final Store s;
  const AuditPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('سجل التعديلات')),
    body: ListView.builder(
      itemCount: s.logs.length,
      itemBuilder: (c, i) {
        final r = s.logs[i];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text('${r['action']} #${r['target']}'),
          subtitle: Text(
            r['date'].toString().substring(0, 16).replaceAll('T', ' '),
          ),
        );
      },
    ),
  );
}

class AboutPage extends StatelessWidget {
  final Store s;
  const AboutPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('حول التطبيق')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.flight_takeoff_rounded, size: 80, color: gold),
        const SizedBox(height: 24),
        const Text(
          'Eslam Office',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const Text('1.0.0 • فكرة وإشراف إسلام', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const Text(
          'إدارة مكتب السفر والحسابات\nحفظ محلي • دولار ودينار • بحث موحّد',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://eslamholiday.com'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Eslamholiday.com'),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/9647713414312'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('WhatsApp • 07713414312'),
        ),
      ],
    ),
  );
}
