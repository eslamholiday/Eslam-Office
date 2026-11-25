import 'labels.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'input_settings.dart';
import 'input_schema.dart';
import 'experience_settings.dart';
import 'experience.dart';
import 'geography_settings.dart';
import 'clearance.dart';
import 'label_settings.dart';
import 'config_transfer.dart';

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
  'customers': 'الزبائن',
  'statements': 'الكشوفات',
  'settings': 'الإعدادات',
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
  'settlement': <String>[],
  'expense': <String>[],
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
  Widget tile(
    BuildContext c,
    String title,
    int art,
    Widget page, [
    String? subtitle,
  ]) => Tactile(
    child: Card(
      child: InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ArtIcon(art, size: 48),
                  const Spacer(),
                  const Icon(Icons.chevron_left_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              UiText(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: UiText(
                    subtitle,
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: ClayAppBar(
      title: const UiText('الإعدادات'),
      actions: [
        IconButton(
          tooltip: 'بحث بالإعدادات',
          icon: const Icon(Icons.search),
          onPressed: () => showSearch(context: c, delegate: SettingsSearch(s)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              ArtIcon(8, size: 64),
              SizedBox(width: 12),
              Expanded(
                child: UiText(
                  'خلّي التطبيق على راحتك',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Section('الإدخال والقوائم', [
          pair(
            tile(
              c,
              'تخصيص كل الإدخالات والقوائم',
              13,
              InputCenterPage(s),
              'إخفاء • ترتيب • افتراضيات',
            ),
            tile(
              c,
              'سلوك الإدخال',
              12,
              InputBehaviorPage(s),
              'بحث • اختيار • حفظ',
            ),
          ),
        ]),
        Section('العناوين والأعلام والتخصيصات', [
          pair(
            tile(c, 'العناوين ومحتويات القوائم', 23, UiLabelsPage(s)),
            tile(c, 'الدول والمدن والأعلام', 25, GeographySettingsPage(s)),
          ),
          tile(c, 'نقل تخصيصات التطبيق', 31, ConfigTransferPage(s)),
        ]),
        Section('المظهر والتنقل', [
          pair(
            tile(c, 'الثيمات والألوان والخطوط', 9, AppearancePage(s)),
            tile(c, 'الرئيسية وشريط التنقل', 0, LayoutPage(s)),
          ),
          pair(
            tile(c, 'الصوت', 10, ExperienceSettingsPage(s)),
            tile(
              c,
              'الاهتزاز',
              11,
              ExperienceSettingsPage(s, initial: 'haptic'),
            ),
          ),
          tile(
            c,
            'الإيماءات والحركة',
            12,
            ExperienceSettingsPage(s, initial: 'gesture'),
          ),
        ]),
        Section('المكتب والكشوف والحساب', [
          pair(
            tile(c, 'الأرقام والتواريخ والحفظ', 14, PreferencesPage(s)),
            tile(c, 'بيانات المكتب والشعار والكشوف', 6, OfficeSettings(s)),
          ),
          tile(c, 'عمولات الطيران وجهات الإصدار', 7, RulesPage(s)),
        ]),
        Section('السجل والتطبيق', [
          pair(
            tile(c, 'المحذوفات / الأرشيف', 15, ArchivePage(s)),
            tile(c, 'سجل التعديلات', 13, AuditPage(s)),
          ),
          tile(c, 'حول Eslam Money', 0, AboutPage(s)),
        ]),
      ],
    ),
  );
}

class AppearancePage extends StatelessWidget {
  final Store s;
  const AppearancePage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => PackAppearancePage(s);
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
        s.settings['homeCards'] ?? ['owed', 'profit', 'payable', 'expenses'],
      );
      final hiddenCards = List<String>.from(
        s.settings['homeCardsHidden'] ?? const <String>[],
      );
      final hiddenShortcuts = List<String>.from(
        s.settings['homeShortcutHidden'] ?? const <String>[],
      );
      return Scaffold(
        appBar: ClayAppBar(title: const UiText('الرئيسية والتنقل')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Section('بطاقات الخدمات المصوّرة', [
              SwitchListTile(
                title: const UiText('إظهار بطاقات التذاكر والفيزا والفنادق'),
                secondary: const ArtIcon(0, size: 36),
                value: s.settings['homeServiceCards'] != false,
                onChanged: (v) => s.set('homeServiceCards', v),
              ),
            ]),
            Section('شاشة البداية', [
              ChoiceField<String>(
                isExpanded: true,
                initialValue: s.settings['start'] ?? 'home',
                items: navLabels.entries
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.key,
                        child: UiText(p.value),
                      ),
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
                        title: UiText(navLabels[key]!),
                        secondary: ReorderableDragStartListener(
                          index: nav.indexOf(key),
                          child: const Icon(Icons.drag_handle),
                        ),
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
            Section('ترتيب وإظهار بطاقات الرئيسية', [
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
                      (key) => CheckboxListTile(
                        key: ValueKey(key),
                        secondary: const Icon(Icons.drag_handle),
                        title: UiText(
                          {
                            'owed': 'المطلوب من الزبائن',
                            'payable': 'مستحقات الإصدار',
                            'profit': 'ربح الخدمات',
                            'expenses': 'المصروفات',
                          }[key]!,
                        ),
                        value: !hiddenCards.contains(key),
                        onChanged: (v) {
                          v == true
                              ? hiddenCards.remove(key)
                              : hiddenCards.add(key);
                          s.set('homeCardsHidden', hiddenCards);
                        },
                      ),
                    )
                    .toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UiText('إظهار الإحصاءات المختصرة'),
                value: s.settings['showHomeStats'] != false,
                onChanged: (v) => s.set('showHomeStats', v),
              ),
            ]),
            Section('اختصارات الرئيسية', [
              for (final key in [
                'passengers',
                'suppliers',
                'expense',
                'movements',
                'review',
                'about',
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: UiText(
                    {
                      'passengers': 'المسافرون',
                      'suppliers': 'جهات الإصدار',
                      'expense': 'المصروف',
                      'movements': 'الحركات',
                      'review': 'مركز التدقيق',
                      'about': 'نبذة التطبيق',
                    }[key]!,
                  ),
                  value: !hiddenShortcuts.contains(key),
                  onChanged: (v) {
                    v == true
                        ? hiddenShortcuts.remove(key)
                        : hiddenShortcuts.add(key);
                    s.set('homeShortcutHidden', hiddenShortcuts);
                  },
                ),
            ]),
            OutlinedButton(
              onPressed: () async {
                await s.set('homeCards', [
                  'owed',
                  'profit',
                  'payable',
                  'expenses',
                ]);
                await s.set('homeCardsHidden', []);
                await s.set('homeShortcutHidden', []);
                await s.set('showHomeStats', true);
                await s.set('navOrder', navLabels.keys.toList());
                await s.set('navHidden', []);
                await s.set('start', 'home');
              },
              child: const UiText('استعادة ترتيب الواجهات'),
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
  Widget build(BuildContext c) => FormCustomizationPage(s, kind);
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
      transferAccount = TextEditingController(
        text: widget.s.settings['transferAccount'] ?? '9645239113',
      ),
      footer = TextEditingController(
        text: widget.s.settings['footer'] ?? 'جميع الحقوق محفوظة 2026',
      );
  late String logoAlign = widget.s.settings['logoAlign'] ?? 'right';
  late String logoSize = widget.s.settings['logoSize'] ?? 'medium';
  @override
  void dispose() {
    for (final c in [office, phone, website, transferAccount, footer]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: ClayAppBar(title: const UiText('هوية المكتب والكشوف')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section('بيانات المكتب', [
          textField(office, 'اسم المكتب'),
          textField(phone, 'الهاتف'),
          textField(website, 'الموقع'),
          textField(transferAccount, 'للتحويل الإلكتروني — رقم الحساب'),
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
            title: const UiText('إظهار الشعار'),
            value: widget.s.settings['showLogo'] != false,
            onChanged: (v) async {
              await widget.s.set('showLogo', v);
              setState(() {});
            },
          ),
          pair(
            ChoiceField<String>(
              isExpanded: true,
              initialValue: logoAlign,
              decoration: const InputDecoration(labelText: 'محاذاة الشعار'),
              items: const [
                DropdownMenuItem(value: 'right', child: UiText('يمين')),
                DropdownMenuItem(value: 'center', child: UiText('وسط')),
                DropdownMenuItem(value: 'left', child: UiText('يسار')),
              ],
              onChanged: (v) => setState(() => logoAlign = v ?? 'right'),
            ),
            ChoiceField<String>(
              isExpanded: true,
              initialValue: logoSize,
              decoration: const InputDecoration(labelText: 'حجم الشعار'),
              items: const [
                DropdownMenuItem(value: 'small', child: UiText('صغير')),
                DropdownMenuItem(value: 'medium', child: UiText('متوسط')),
                DropdownMenuItem(value: 'large', child: UiText('كبير')),
              ],
              onChanged: (v) => setState(() => logoSize = v ?? 'medium'),
            ),
          ),
        ]),
        Section(
          'إظهار وإخفاء تفاصيل الكشف',
          statementOptions.entries
              .map(
                (e) => SwitchListTile(
                  title: UiText(e.value),
                  value: e.key == 'statementShowNotes'
                      ? widget.s.settings[e.key] == true
                      : widget.s.settings[e.key] != false,
                  onChanged: (v) async {
                    await widget.s.set(e.key, v);
                    if (mounted) setState(() {});
                  },
                ),
              )
              .toList(),
        ),
        FilledButton(
          onPressed: () async {
            for (final e in {
              'office': office.text,
              'phone': phone.text,
              'website': website.text,
              'transferAccount': transferAccount.text.trim(),
              'footer': footer.text,
              'logoAlign': logoAlign,
              'logoSize': logoSize,
            }.entries) {
              await widget.s.set(e.key, e.value);
            }
            if (c.mounted) Navigator.pop(c);
          },
          child: const UiText('حفظ'),
        ),
      ],
    ),
  );
}

class ReferencePage extends StatefulWidget {
  final Store s;
  final String kind, title;
  const ReferencePage(this.s, this.kind, this.title, {super.key});
  @override
  State<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage> {
  Store get s => widget.s;
  String get kind => widget.kind;
  String get title => widget.title;
  String query = '';
  bool alphabetic = true;
  Future<void> edit(BuildContext c, [Map<String, dynamic>? r]) async {
    if (kind == 'city' || kind == 'country') {
      await editGeographicReference(c, s, kind, r);
      return;
    }
    final name = TextEditingController(text: r?['name'] ?? ''),
        code = TextEditingController(text: r?['code'] ?? ''),
        subcategories = TextEditingController(
          text: List<String>.from(r?['subcategories'] ?? []).join('\n'),
        ),
        rate = TextEditingController(
          text: (r?['rate'] ?? 0) == 0
              ? ''
              : ((r?['rate'] ?? 0) / 100).toString(),
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
          title: UiText(r == null ? 'إضافة' : 'تعديل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                textField(name, 'الاسم'),
                if (kind == 'expenseCategory')
                  textField(
                    subcategories,
                    'التصنيفات الفرعية — اسم بكل سطر',
                    lines: 5,
                  ),
                if (kind == 'airline') ...[
                  textField(code, 'رمز الطيران'),
                  ChoiceField<String>(
                    isExpanded: true,
                    initialValue: currency,
                    items: Currency.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.name,
                            child: UiText(v.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => currency = v!),
                  ),
                  const SizedBox(height: 12),
                  ChoiceField<String>(
                    isExpanded: true,
                    initialValue: mode,
                    items: const [
                      DropdownMenuItem(
                        value: 'percent',
                        child: UiText('نسبة خصم من الأساسي'),
                      ),
                      DropdownMenuItem(
                        value: 'fee',
                        child: UiText('رسم إصدار إضافي'),
                      ),
                    ],
                    onChanged: (v) => set(() => mode = v!),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'percent')
                    textField(rate, 'العمولة الافتراضية %', number: true)
                  else
                    textField(
                      fee,
                      'رسم الإصدار للوحدة',
                      number: true,
                      grouped: true,
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const UiText('إلغاء'),
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
                  if (kind == 'expenseCategory')
                    'subcategories': subcategories.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toSet()
                        .toList(),
                  if (r?['personal'] != null) 'personal': r!['personal'],
                  'code': code.text,
                  'rate': pct,
                  'fee': money(fee.text, Currency.values.byName(currency)),
                  'currency': currency,
                  'commissionMode': mode,
                }, id: r?['id']);
                if (ctx.mounted) Navigator.pop(ctx);
              }),
              child: const UiText('حفظ'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final t in [name, code, rate, fee, subcategories]) {
        t.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final rows = s.refs
          .where(
            (r) =>
                r['kind'] == kind &&
                normalize('${r['name']} ${r['code'] ?? ''}').contains(query),
          )
          .toList();
      if (alphabetic) {
        rows.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      }
      return Scaffold(
        appBar: ClayAppBar(
          title: UiText(title),
          actions: [
            IconButton(
              tooltip: 'تبديل الترتيب',
              onPressed: () => setState(() => alphabetic = !alphabetic),
              icon: const Icon(Icons.sort),
            ),
            IconButton(onPressed: () => edit(c), icon: const Icon(Icons.add)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث في القائمة',
                ),
                onChanged: (v) => setState(() => query = normalize(v)),
              ),
            ),
            Expanded(
              child: ListView(
                children: rows
                    .map(
                      (r) => ListTile(
                        title: UiText(r['name']),
                        subtitle: UiText(r['code'] ?? ''),
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
          ],
        ),
      );
    },
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
  final rate = TextEditingController(), fee = TextEditingController();
  @override
  void dispose() {
    rate.dispose();
    fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: ClayAppBar(title: const UiText('قواعد العمولات')),
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
          ChoiceField<String>(
            isExpanded: true,
            initialValue: mode,
            items: const [
              DropdownMenuItem(
                value: 'percent',
                child: UiText('خصم عمولة من الأساسي'),
              ),
              DropdownMenuItem(value: 'fee', child: UiText('إضافة رسم إصدار')),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 12),
          if (mode == 'percent')
            textField(rate, 'العمولة %', number: true)
          else ...[
            ChoiceField<String>(
              isExpanded: true,
              initialValue: currency,
              items: Currency.values
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v.name, child: UiText(v.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => currency = v!),
            ),
            const SizedBox(height: 12),
            textField(
              fee,
              'رسم إصدار التذكرة الواحدة',
              number: true,
              grouped: true,
            ),
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
            child: const UiText('حفظ القاعدة'),
          ),
        ]),
        ...widget.s.rules.map(
          (r) => Card(
            child: ListTile(
              title: UiText(
                '${widget.s.reference(r['airline'])} × ${widget.s.name(r['supplier'])}',
              ),
              subtitle: UiText(
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
      appBar: const ClayAppBar(title: UiText('الأرشيف والتصفية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Section('أرشيف الماضي', [
            ListTile(
              leading: const ArtIcon(15),
              title: const UiText('أرشيف التصفيات'),
              subtitle: UiText(
                '${s.clearances.length} تصفية — للقراءة والتصدير فقط',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => ClearanceArchivePage(s)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: s.entries.any((e) => e.posted)
                  ? () => confirmClearance(c, s, all: true)
                  : null,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const UiText('تصفية جميع العمليات المعتمدة'),
            ),
          ]),
          if (s.parties.any(
            (p) => p['archived'] == 1 && !s.retiredParties.contains(p['id']),
          ))
            Section('حسابات مخفية سابقًا', [
              ...s.parties
                  .where(
                    (p) =>
                        p['archived'] == 1 &&
                        !s.retiredParties.contains(p['id']),
                  )
                  .map(
                    (p) => ListTile(
                      title: UiText(p['name']),
                      trailing: TextButton(
                        onPressed: () => s.archiveParty(p['id'], false),
                        child: const UiText('استعادة'),
                      ),
                    ),
                  ),
            ]),
        ],
      ),
    ),
  );
}

class AuditPage extends StatelessWidget {
  final Store s;
  const AuditPage(this.s, {super.key});

  String auditTarget(Map<String, dynamic> row) {
    final id = int.tryParse('${row['target']}');
    if ('${row['action']}'.contains('حساب')) {
      final name = s.name(id);
      if (name.isNotEmpty) return name;
      try {
        final payload = jsonDecode(row['payload'] ?? '{}');
        final data = payload['after'] ?? payload['before'];
        if (data is Map && data['name'] != null) return '${data['name']}';
      } catch (_) {}
    }
    return '#${row['target']}';
  }

  bool canUndo(Map<String, dynamic> row) {
    try {
      final payload = Map<String, dynamic>.from(
        jsonDecode((row['payload'] ?? '{}').toString()),
      );
      return const {
        'forceDeleteEntry',
        'restoreParty',
        'restoreRef',
      }.contains(payload['undoType']);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: ClayAppBar(title: const UiText('سجل التعديلات')),
      body: s.logs.isEmpty
          ? const Center(
              child: EmptyState(
                'لا توجد تعديلات مسجلة',
                'ستظهر هنا الإضافات والتعديلات والحذف الإجباري.',
                icon: Icons.history,
              ),
            )
          : ListView.builder(
              itemCount: s.logs.length,
              itemBuilder: (c, i) {
                final r = s.logs[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i == 0 ||
                        '${s.logs[i - 1]['date']}'.substring(0, 10) !=
                            '${r['date']}'.substring(0, 10))
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: UiText(
                          displayDate('${r['date']}'.substring(0, 10)),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ListTile(
                      leading: Icon(
                        '${r['action']}'.contains('حذف')
                            ? Icons.delete_outline
                            : Icons.edit_outlined,
                      ),
                      title: UiText('${r['action']} • ${auditTarget(r)}'),
                      subtitle: UiText(
                        r['date']
                            .toString()
                            .substring(0, 16)
                            .replaceAll('T', ' '),
                      ),
                      onTap: () {
                        try {
                          final payload = Map<String, dynamic>.from(
                            jsonDecode((r['payload'] ?? '{}').toString()),
                          );
                          if (payload['before'] == null &&
                              payload['after'] == null) {
                            return;
                          }
                          showDialog<void>(
                            context: c,
                            builder: (ctx) => AlertDialog(
                              title: const UiText('تفاصيل التعديل'),
                              content: SingleChildScrollView(
                                child: SelectableText(
                                  'قبل:\n${payload['before'] ?? '—'}\n\nبعد:\n${payload['after'] ?? '—'}',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const UiText('إغلاق'),
                                ),
                              ],
                            ),
                          );
                        } catch (_) {}
                      },
                      trailing: canUndo(r)
                          ? TextButton.icon(
                              onPressed: () => guarded(c, () async {
                                await s.undoAudit(r['id'] as int);
                                if (c.mounted) {
                                  message(c, 'تم التراجع واستعادة العملية');
                                }
                              }),
                              icon: const Icon(Icons.undo),
                              label: const UiText('تراجع'),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
    ),
  );
}

class AboutPage extends StatelessWidget {
  final Store s;
  const AboutPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: ClayAppBar(title: const UiText('حول التطبيق')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ArtIcon(0, size: 100),
        const SizedBox(height: 24),
        const UiText(
          'Eslam Money',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const UiText('2.0.0 • فكرة وإشراف إسلام', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const UiText(
          'إدارة مكتب السفر والحسابات\nحفظ محلي • دولار ودينار • بحث موحّد',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://eslamholiday.com'),
            mode: LaunchMode.externalApplication,
          ),
          child: const UiText('Eslamholiday.com'),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/9647713414312'),
            mode: LaunchMode.externalApplication,
          ),
          child: const UiText('WhatsApp • 07713414312'),
        ),
      ],
    ),
  );
}

class PreferencesPage extends StatelessWidget {
  final Store s;
  const PreferencesPage(this.s, {super.key});
  Widget option(
    String title,
    String key,
    Map<String, String> values,
    String fallback,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ChoiceField<String>(
      key: ValueKey('$key-${s.settings[key]}'),
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      initialValue: key == 'imageDpi'
          ? '${s.settings[key] == 400 ? 400 : 300}'
          : '${s.settings[key] ?? fallback}',
      items: values.entries
          .map((e) => DropdownMenuItem(value: e.key, child: UiText(e.value)))
          .toList(),
      onChanged: (v) => s.set(
        key,
        key == 'usdDecimals' || key == 'imageDpi' ? int.parse(v!) : v,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) => Scaffold(
      appBar: ClayAppBar(title: const UiText('الأرقام والتواريخ والحفظ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Section('عرض الأرقام', [
            SwitchListTile(
              title: const UiText('أرقام عربية ١٢٣'),
              value: s.settings['arabicDigits'] == true,
              onChanged: (v) => s.set('arabicDigits', v),
            ),
            SwitchListTile(
              title: const UiText('فاصل الآلاف'),
              value: s.settings['groupNumbers'] != false,
              onChanged: (v) => s.set('groupNumbers', v),
            ),
            option('المنازل العشرية للدولار', 'usdDecimals', {
              '0': 'بدون كسور',
              '2': 'منزلتان عشريتان',
            }, '0'),
            UiText('الدينار: أعداد صحيحة • ${Currency.USD.format(123456)}'),
          ]),
          Section('عرض التاريخ', [
            option('نسق التاريخ', 'dateFormat', {
              'day': 'يوم / شهر / سنة',
              'iso': 'سنة-شهر-يوم',
            }, 'day'),
            SwitchListTile(
              title: const UiText('إظهار اسم اليوم'),
              value: s.settings['showWeekday'] != false,
              onChanged: (v) => s.set('showWeekday', v),
            ),
            UiText(displayDate(day(DateTime.now()))),
          ]),
          Section('صور الكشوف', [
            option('جودة الصور', 'imageDpi', {
              '300': 'عالية — 300 DPI',
              '400': 'فائقة — 400 DPI',
            }, '300'),
            const UiText('PNG بدون فقدان جودة • خلفية بيضاء ثابتة'),
            option('ألبوم الحفظ في المعرض', 'galleryAlbum', {
              'Eslam Money': 'Eslam Money',
              'Passengers Statements': 'Passengers Statements',
            }, 'Eslam Money'),
            SwitchListTile(
              title: const UiText('نسخ للمعرض عند الحفظ داخل التطبيق'),
              value: s.settings['autoGallery'] == true,
              onChanged: (v) => s.set('autoGallery', v),
            ),
            const UiText(
              'الاسم تلقائي: صاحب الكشف + العملة + التاريخ + رقم الصفحة. الكشوف الطويلة تُحفظ على عدة صور.',
            ),
          ]),
          Section('بعد حفظ العملية', [
            option('الإجراء الافتراضي', 'afterSave', {
              'back': 'العودة للصفحة السابقة',
              'detail': 'فتح تفاصيل العملية',
              'another': 'إضافة عملية أخرى',
            }, 'back'),
          ]),
          Section('قوائم الحسابات', [
            SwitchListTile(
              title: const UiText('عرض الرصيد المختصر'),
              value: s.settings['showListBalances'] == true,
              onChanged: (v) => s.set('showListBalances', v),
            ),
          ]),
        ],
      ),
    ),
  );
}

class SettingsSearch extends SearchDelegate<void> {
  final Store s;
  SettingsSearch(this.s) : super(searchFieldLabel: 'ابحث في الإعدادات');
  Map<String, Widget> get destinations => {
    'العناوين التسميات الخيارات الأيقونات': UiLabelsPage(s),
    'الدول المدن الأعلام': GeographySettingsPage(s),
    'تصدير استيراد نقل التخصيصات': ConfigTransferPage(s),
    'الثيمات الألوان الخطوط المظهر حزم الأشكال': AppearancePage(s),
    'الصوت المؤثرات مستوى الصوت': ExperienceSettingsPage(s),
    'الاهتزاز القوة اللمس': ExperienceSettingsPage(s, initial: 'haptic'),
    'الإيماءات السحب الحركة السرعة': ExperienceSettingsPage(
      s,
      initial: 'gesture',
    ),
    'الأرقام التاريخ حفظ الصور المعرض': PreferencesPage(s),
    'الرئيسية ترتيب شريط التنقل': LayoutPage(s),
    'الإدخالات القوائم تخصيص كل الحقول': InputCenterPage(s),
    'سلوك الإدخال الحفظ التلقائي المفضلة': InputBehaviorPage(s),
    for (final k in inputScopes.keys)
      '${inputScopes[k]} الحقول الافتراضية الإخفاء الإظهار':
          FormCustomizationPage(s, k),
    'بيانات المكتب الشعار الكشوف': OfficeSettings(s),
    'الطيران': ReferencePage(s, 'airline', 'شركات الطيران'),
    'الدول': ReferencePage(s, 'country', 'الدول'),
    'المدن': ReferencePage(s, 'city', 'المدن'),
    'تصنيفات المصروف': ReferencePage(s, 'expenseCategory', 'تصنيفات المصروف'),
    'العمولات': RulesPage(s),
    'الأرشيف': ArchivePage(s),
    'سجل التعديلات': AuditPage(s),
  };
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) => ListView(
    children: destinations.entries
        .where((e) => normalize(e.key).contains(normalize(query)))
        .map(
          (e) => ListTile(
            title: UiText(e.key),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => e.value),
            ),
          ),
        )
        .toList(),
  );
}
