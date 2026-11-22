import 'package:flutter/material.dart';
import 'domain.dart';
import 'forms.dart';
import 'input_schema.dart';
import 'settings.dart' show ReferencePage;
import 'store.dart';
import 'ui.dart';

const editableLists = {
  'airline': 'شركات الطيران',
  'city': 'المدن',
  'country': 'الدول',
  'expenseCategory': 'تصنيفات المصروف',
  'hotelName': 'أسماء الفنادق',
  'visaType': 'أنواع الفيزا',
  'meals': 'الوجبات',
};

Future<int?> addReference(BuildContext context, Store s, String kind) async {
  final controller = TextEditingController();
  int? result;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('إضافة إلى ${editableLists[kind] ?? kind}'),
      content: textField(controller, 'الاسم'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => guarded(ctx, () async {
            final name = controller.text.trim();
            if (name.isEmpty) throw const FormatException('أدخل الاسم');
            await s.saveRef(kind, name, {});
            result =
                s
                        .referenceList(kind)
                        .where((r) => r['name'] == name)
                        .firstOrNull?['id']
                    as int?;
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

class InputSearch extends StatelessWidget {
  final InputLayout layout;
  final ValueChanged<String> onSelect;
  const InputSearch({super.key, required this.layout, required this.onSelect});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton.icon(
      icon: const Icon(Icons.search),
      label: const Text('ابحث عن حقل، حتى المخفي'),
      onPressed: () async {
        var query = '';
        final result = await showModalBottomSheet<String>(
          context: c,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * .6,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'اسم الحقل',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => set(() => query = normalize(v)),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: layout.fields
                              .where(
                                (f) => normalize(
                                  '${f.label} ${layout.label(f)} ${inputGroupLabels[f.group]}',
                                ).contains(query),
                              )
                              .map(
                                (f) => ListTile(
                                  title: Text(layout.label(f)),
                                  subtitle: Text(
                                    '${inputGroupLabels[f.group]} • ${inputModes[layout.mode(f)]}',
                                  ),
                                  onTap: () => Navigator.pop(ctx, f.key),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (result != null) onSelect(result);
      },
    ),
  );
}

class InputCenterPage extends StatelessWidget {
  final Store s;
  const InputCenterPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('الإدخالات والقوائم')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'كل إعدادات الإدخال في مكان واحد. التخصيص لا يمسح بياناتك ولا يغيّر ظهورها في الكشوف.',
          ),
        ),
        _section(
          c,
          'الخدمات والحسابات',
          inputScopes.entries
              .map(
                (e) => ListTile(
                  leading: Icon(kindIcon(e.key)),
                  title: Text(e.value),
                  subtitle: const Text(
                    'الحقول • ترتيب الأقسام • الافتراضيات • المعاينة',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => FormCustomizationPage(s, e.key),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        _section(
          c,
          'القوائم المحفوظة',
          editableLists.entries
              .map(
                (e) => ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: Text(e.value),
                  subtitle: const Text('إضافة وتعديل وإيقاف العناصر'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => ReferencePage(s, e.key, e.value),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        _section(c, 'سلوك الإدخال', [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('خيارات عامة لكل النماذج'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => InputBehaviorPage(s)),
            ),
          ),
        ]),
      ],
    ),
  );
  Widget _section(BuildContext c, String title, List<Widget> rows) =>
      Section(title, rows);
}

class ChoiceOptionsPage extends StatelessWidget {
  final Store s;
  final InputSpec field;
  const ChoiceOptionsPage(this.s, this.field, {super.key});
  Map<String, dynamic> get config =>
      Map<String, dynamic>.from(s.settings['choices_${field.key}'] ?? {});
  Future<void> rename(BuildContext c, String key, String label) async {
    final controller = TextEditingController(text: label);
    final yes = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم الخيار'),
        content: textField(controller, 'الاسم'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (yes == true && controller.text.trim().isNotEmpty) {
      await s.set('choices_${field.key}', {
        ...config,
        'labels': {...?config['labels'] as Map?, key: controller.text.trim()},
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final all = {
        ...field.choices,
        ...Map<String, String>.from(config['labels'] ?? {}),
      };
      final order = <String>{
        ...List<String>.from(config['order'] ?? []),
        ...all.keys,
      }.where(all.containsKey).toList();
      final hidden = List<String>.from(config['hidden'] ?? []);
      return Scaffold(
        appBar: AppBar(
          title: Text('خيارات ${field.label}'),
          actions: [
            if (field.key == 'paymentMethod')
              IconButton(
                tooltip: 'إضافة طريقة',
                icon: const Icon(Icons.add),
                onPressed: () => rename(
                  c,
                  'custom_${DateTime.now().microsecondsSinceEpoch}',
                  '',
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اسحب للترتيب، اضغط الاسم لتغييره، أو أوقف ظهوره. الخيار المستخدم في عملية محفوظة يبقى ظاهرًا عند تعديلها.',
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: order.length,
                onReorder: (a, b) {
                  if (b > a) b--;
                  order.insert(b, order.removeAt(a));
                  s.set('choices_${field.key}', {...config, 'order': order});
                },
                itemBuilder: (c, i) {
                  final k = order[i];
                  return ListTile(
                    key: ValueKey(k),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(all[k]!),
                    onTap: () => rename(c, k, all[k]!),
                    trailing: Switch(
                      value: !hidden.contains(k),
                      onChanged: (v) {
                        v ? hidden.remove(k) : hidden.add(k);
                        s.set('choices_${field.key}', {
                          ...config,
                          'hidden': hidden,
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class InputBehaviorPage extends StatelessWidget {
  final Store s;
  const InputBehaviorPage(this.s, {super.key});
  Widget toggle(String key, String title, String subtitle, bool fallback) =>
      SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: s.settings[key] as bool? ?? fallback,
        onChanged: (v) => s.set(key, v),
      );
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) => Scaffold(
      appBar: AppBar(title: const Text('سلوك الإدخال')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section('العرض', [
            toggle(
              'compactForms',
              'إدخال مضغوط',
              'مسافات أقل وبطاقات أصغر',
              false,
            ),
            toggle(
              'stickySummary',
              'ملخص الحساب ثابت',
              'البيع والكلفة والربح أثناء إدخال الخدمات',
              true,
            ),
            toggle(
              'showInputSearch',
              'بحث داخل النموذج',
              'يجد الحقول حتى لو كانت مخفية أو مطوية',
              true,
            ),
          ]),
          Section('الاختيار من القوائم', [
            toggle(
              'pickerFavorites',
              'المفضلة وآخر المستخدم',
              'نجمة لكل عنصر مع حفظ أحدث الاختيارات',
              true,
            ),
            ChoiceField<String>(
              decoration: const InputDecoration(labelText: 'ترتيب القوائم'),
              initialValue: s.settings['pickerSort'] ?? 'recent',
              items: const [
                DropdownMenuItem(
                  value: 'recent',
                  child: Text('المفضلة ثم آخر المستخدم'),
                ),
                DropdownMenuItem(value: 'name', child: Text('أبجدي')),
                DropdownMenuItem(
                  value: 'original',
                  child: Text('ترتيب الإضافة'),
                ),
              ],
              onChanged: (v) => s.set('pickerSort', v),
            ),
          ]),
          Section('الحساب والافتراضيات', [
            toggle(
              'autoAirlineCurrency',
              'اقتراح عملة شركة الطيران',
              'يمكن إيقافه واختيار العملة يدويًا',
              true,
            ),
            toggle(
              'autoCommission',
              'تطبيق قاعدة العمولة تلقائيًا',
              'يمكن إيقافه واعتماد قيمك الافتراضية أو اليدوية',
              true,
            ),
            toggle(
              'confirmPost',
              'مراجعة قبل الاعتماد',
              'عرض ملخص العملية قبل تسجيلها',
              true,
            ),
            toggle(
              'autoRecoverForms',
              'استعادة الإدخال غير المكتمل',
              'حفظ محلي تلقائي بدون إنشاء حركة مالية',
              true,
            ),
          ]),
        ],
      ),
    ),
  );
}

class FormCustomizationPage extends StatefulWidget {
  final Store s;
  final String scope;
  const FormCustomizationPage(this.s, this.scope, {super.key});
  @override
  State<FormCustomizationPage> createState() => _FormCustomizationPageState();
}

class _FormCustomizationPageState extends State<FormCustomizationPage> {
  Store get s => widget.s;
  InputLayout get layout => InputLayout(s.settings, widget.scope);
  String query = '';
  String? group;
  Future<void> saveConfig(Map<String, dynamic> config) =>
      s.set('input_${widget.scope}', config);
  Future<void> updateField(InputSpec f, Map<String, dynamic> change) async {
    final config = layout.config;
    config['fields'] = {
      ...?config['fields'] as Map?,
      f.key: {...layout.fieldConfig(f.key), ...change},
    };
    await saveConfig(config);
  }

  Future<void> editField(InputSpec f) async {
    final label = TextEditingController(text: layout.label(f));
    var mode = layout.mode(f);
    var required = layout.requiredField(f);
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('تخصيص ${f.label}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                textField(label, 'عنوان الحقل'),
                ChoiceField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'الإظهار'),
                  items: inputModes.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => set(() => mode = v!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مطلوب عند الاعتماد'),
                  value: required,
                  onChanged: (v) => set(() => required = v),
                ),
                if (f.choices.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text('تعديل خيارات هذه القائمة'),
                    onPressed: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => ChoiceOptionsPage(s, f),
                      ),
                    ),
                  ),
                const Text(
                  'يمكن إخفاء أي حقل. إذا احتاج الاعتماد قيمة لازمة للحساب، نُظهر الحقل لتكمله. إخفاء الحقل لا يمسح قيمته.',
                ),
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (apply == true) {
      await updateField(f, {
        'label': label.text.trim().isEmpty ? f.label : label.text.trim(),
        'mode': mode,
        'required': required,
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    label.dispose();
  }

  Future<void> editDefault(InputSpec f) async {
    final defaults = layout.defaults;
    final current = defaults[f.key];
    dynamic value = current;
    final controller = TextEditingController(text: current?.toString() ?? '');
    final numeric = ['money', 'number', 'count'].contains(f.type);
    if (f.type == 'money' && current is int) {
      controller.text = Currency.values
          .byName(
            defaults['currency'] ?? s.settings['defaultCurrency'] ?? 'USD',
          )
          .input(current);
    }
    if (f.key == 'rate' && current is int) {
      controller.text = (current / 100).toString();
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('افتراضي: ${layout.label(f)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.type == 'reference')
                  PickField(
                    layout.label(f),
                    value as int?,
                    ['customer', 'supplier'].contains(f.reference)
                        ? s.list(f.reference!)
                        : s.referenceList(f.reference!),
                    (v) => set(() => value = v),
                  )
                else if (f.type == 'date')
                  DateField(
                    layout.label(f),
                    value as String?,
                    (v) => set(() => value = v),
                  )
                else if (f.choices.isNotEmpty)
                  ChoiceField<String>(
                    initialValue: value?.toString(),
                    decoration: InputDecoration(labelText: layout.label(f)),
                    items: f.choices.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => value = v),
                  )
                else if (f.type == 'bool')
                  SwitchListTile(
                    title: Text(layout.label(f)),
                    value: value == true,
                    onChanged: (v) => set(() => value = v),
                  )
                else
                  textField(controller, layout.label(f), number: numeric),
                const SizedBox(height: 12),
                const Text(
                  'القيمة تبدأ بها العمليات الجديدة فقط. «بدون افتراضي» لا يغيّر العمليات المحفوظة. العملة والتاريخ يستخدمان الإعداد العام وتاريخ اليوم عند تركهما فارغين.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('بدون افتراضي'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  if (f.key == 'rate') {
                    value = decimalUnits(controller.text, 2);
                  } else if (f.type == 'money') {
                    value = money(
                      controller.text,
                      Currency.values.byName(
                        defaults['currency'] ??
                            s.settings['defaultCurrency'] ??
                            'USD',
                      ),
                    );
                  } else if (f.type == 'count' || f.type == 'number') {
                    value = decimalUnits(controller.text, 0);
                  } else if (f.type == 'direction') {
                    value = int.tryParse(value?.toString() ?? '-1') ?? -1;
                  } else if (![
                    'reference',
                    'date',
                    'choice',
                    'bool',
                  ].contains(f.type)) {
                    value = controller.text;
                  }
                  Navigator.pop(ctx, 'save');
                } catch (e) {
                  message(ctx, e);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      if (result == 'clear') {
        defaults.remove(f.key);
      } else {
        defaults[f.key] = value;
      }
      await s.set('defaults_${widget.scope}', defaults);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  String defaultLabel(InputSpec f) {
    final v = layout.defaults[f.key];
    if (v == null || v == '') {
      return 'بدون افتراضي';
    }
    if (f.type == 'reference') {
      return (['customer', 'supplier'].contains(f.reference)
                  ? s.name(v)
                  : s.reference(v))
              .isEmpty
          ? 'عنصر محفوظ'
          : (['customer', 'supplier'].contains(f.reference)
                ? s.name(v)
                : s.reference(v));
    }
    if (f.type == 'money' && v is int) {
      return Currency.values
          .byName(
            layout.defaults['currency'] ??
                s.settings['defaultCurrency'] ??
                'USD',
          )
          .format(v);
    }
    if (f.key == 'rate' && v is int) {
      return '${v / 100}%';
    }
    if (f.type == 'bool') {
      return v == true ? 'نعم' : 'لا';
    }
    return f.choices[v.toString()] ?? v.toString();
  }

  Future<void> reset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة تخصيص هذا القسم؟'),
        content: const Text(
          'تعود عناوين الحقول وترتيبها وافتراضياتها للوضع الأصلي. تبقى بياناتك وعملياتك محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await s.set('input_${widget.scope}', {});
      await s.set('fields_${widget.scope}', []);
      await s.set('hidden_${widget.scope}', []);
      await s.set('defaults_${widget.scope}', {});
    }
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final selectedGroup = group ?? layout.groups.first;
      final fields = layout.fields
          .where(
            (f) =>
                f.group == selectedGroup &&
                normalize(
                  '${f.label} ${layout.label(f)}',
                ).contains(normalize(query)),
          )
          .toList();
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text('إدخالات ${inputScopes[widget.scope]}'),
            actions: [
              IconButton(
                tooltip: 'معاينة النموذج',
                icon: const Icon(Icons.preview_outlined),
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) =>
                        [
                          'customer',
                          'supplier',
                          'passenger',
                          'family',
                        ].contains(widget.scope)
                        ? PartyForm(s, widget.scope, preview: true)
                        : EntryForm(s, widget.scope, preview: true),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (_) => reset(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('استعادة تخصيص هذا القسم'),
                  ),
                ],
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'الحقول'),
                Tab(text: 'الأقسام'),
                Tab(text: 'الافتراضيات'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ChoiceField<String>(
                          initialValue: selectedGroup,
                          decoration: const InputDecoration(labelText: 'القسم'),
                          items: layout.groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(inputGroupLabels[g] ?? g),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            group = v;
                            query = '';
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'بحث عن حقل في كل الأقسام',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => query = v),
                        ),
                      ],
                    ),
                  ),
                  if (query.isNotEmpty)
                    Expanded(
                      child: ListView(
                        children: layout.fields
                            .where(
                              (f) => normalize(
                                '${f.label} ${layout.label(f)}',
                              ).contains(normalize(query)),
                            )
                            .map(
                              (f) => ListTile(
                                title: Text(layout.label(f)),
                                subtitle: Text(
                                  '${inputGroupLabels[f.group]} • ${inputModes[layout.mode(f)]}',
                                ),
                                trailing: const Icon(Icons.tune),
                                onTap: () => editField(f),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: fields.length,
                        onReorder: (a, b) {
                          if (b > a) b--;
                          final reordered = fields.map((f) => f.key).toList();
                          reordered.insert(b, reordered.removeAt(a));
                          var i = 0;
                          final order = layout.fields
                              .map(
                                (f) => f.group == selectedGroup
                                    ? reordered[i++]
                                    : f.key,
                              )
                              .toList();
                          saveConfig({...layout.config, 'order': order});
                        },
                        itemBuilder: (c, i) {
                          final f = fields[i];
                          return Card(
                            key: ValueKey(f.key),
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(layout.label(f)),
                              subtitle: Text(
                                '${inputModes[layout.mode(f)]}${layout.requiredField(f) ? ' • مطلوب عند الاعتماد' : ''}',
                              ),
                              trailing: const Icon(Icons.tune),
                              onTap: () => editField(f),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'اسحب لترتيب الأقسام. المفتاح يحدد فتح القسم تلقائيًا عند الإضافة. الحقول المخفية لا تظهر في القسم.',
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: layout.groups.length,
                      onReorder: (a, b) {
                        final groups = layout.groups;
                        if (b > a) b--;
                        groups.insert(b, groups.removeAt(a));
                        saveConfig({...layout.config, 'groups': groups});
                      },
                      itemBuilder: (c, i) {
                        final g = layout.groups[i];
                        return Card(
                          key: ValueKey(g),
                          child: SwitchListTile(
                            secondary: ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle),
                            ),
                            title: Text(inputGroupLabels[g] ?? g),
                            subtitle: Text(
                              layout.expanded(g)
                                  ? 'مفتوح تلقائيًا'
                                  : 'مطوي تلقائيًا',
                            ),
                            value: layout.expanded(g),
                            onChanged: (v) => saveConfig({
                              ...layout.config,
                              'expanded': {
                                ...?layout.config['expanded'] as Map?,
                                g: v,
                              },
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'اضغط أي حقل لتحديد قيمته الابتدائية أو إزالتها. القيم تخص العمليات الجديدة فقط.',
                    ),
                  ),
                  for (final g in layout.groups)
                    Section(
                      inputGroupLabels[g] ?? g,
                      layout.fields
                          .where(
                            (f) =>
                                f.group == g &&
                                ![
                                  'account',
                                  'attachments',
                                  'profile',
                                  'passengers',
                                ].contains(f.type),
                          )
                          .map(
                            (f) => ListTile(
                              title: Text(layout.label(f)),
                              subtitle: Text(defaultLabel(f)),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: () => editDefault(f),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
