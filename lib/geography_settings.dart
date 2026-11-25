import 'labels.dart';
import 'package:flutter/material.dart';
import 'geography.dart';
import 'store.dart';
import 'ui.dart';

Future<String?> chooseFlag(BuildContext context, String? selected) async {
  await GeoCatalog.load();
  if (!context.mounted) return null;
  var query = '';
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(10),
                child: UiText('مكتبة الأعلام — لا تضيف أسماء إلى قوائمك'),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'الدولة أو الرمز',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => set(() => query = GeoCatalog.clean(v)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const UiText('بدون علم'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              Expanded(
                child: ListView(
                  children: GeoCatalog.countries
                      .where(
                        (r) => GeoCatalog.clean(
                          '${r['ar']} ${r['en']} ${r['code']}',
                        ).contains(query),
                      )
                      .map(
                        (r) => ListTile(
                          leading: CountryBadge(r['code'], size: 34),
                          title: UiText('${r['ar']}'),
                          subtitle: UiText('${r['en']} · ${r['code']}'),
                          trailing: selected == r['code']
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(ctx, r['code'] as String),
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
  );
}

Future<int?> editGeographicReference(
  BuildContext context,
  Store s,
  String kind, [
  Map<String, dynamic>? record,
]) async {
  await GeoCatalog.load();
  if (!context.mounted) return null;
  final name = TextEditingController(text: record?['name'] ?? '');
  String? code = record == null ? null : GeoCatalog.recordCode(record);
  bool manual = record?.containsKey('flagCode') == true;
  int? result;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: UiText(
          record == null
              ? (kind == 'city' ? 'إضافة مدينة' : 'إضافة دولة')
              : 'تعديل الاسم والعلم',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            textField(
              name,
              'الاسم',
              onChanged: (value) {
                if (!manual) set(() => code = GeoCatalog.infer(kind, value));
              },
            ),
            ListTile(
              leading: code == null
                  ? const Icon(Icons.public)
                  : CountryBadge(code),
              title: UiText(
                GeoCatalog.byCode(code)?['ar'] ??
                    (kind == 'city' ? 'اختيار دولة المدينة' : 'اختيار العلم'),
              ),
              subtitle: const UiText('ربط العلم فقط؛ قوائمك تبقى كما هي'),
              onTap: () async {
                final chosen = await chooseFlag(ctx, code);
                if (chosen != null) {
                  set(() {
                    code = chosen;
                    manual = true;
                  });
                }
              },
            ),
          ],
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
              final payload = <String, dynamic>{...?record}
                ..remove('id')
                ..remove('kind')
                ..remove('name')
                ..remove('payload');
              if (code != null) payload['countryCode'] = code;
              if (manual) payload['flagCode'] = code ?? '';
              await s.saveRef(
                kind,
                name.text.trim(),
                payload,
                id: record?['id'],
              );
              result =
                  record?['id'] ??
                  s
                      .referenceList(kind)
                      .where((r) => r['name'] == name.text.trim())
                      .first['id'];
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: const UiText('حفظ'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  return result;
}

class GeographySettingsPage extends StatelessWidget {
  final Store s;
  const GeographySettingsPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const ClayAppBar(
          title: UiText('الدول والمدن والأعلام'),
          bottom: TabBar(
            tabs: [
              Tab(child: UiText('الدول')),
              Tab(child: UiText('المدن')),
            ],
          ),
        ),
        body: Column(
          children: [
            SwitchListTile(
              secondary: const ArtIcon(25, size: 36),
              title: const UiText('إظهار الأعلام'),
              value: s.settings['showFlags'] != false,
              onChanged: (v) => s.set('showFlags', v),
            ),
            SwitchListTile(
              title: const UiText('التعرّف التلقائي على العلم'),
              value: s.settings['autoGeoFlags'] != false,
              onChanged: (v) => s.set('autoGeoFlags', v),
            ),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: UiText('حجم الأعلام'),
                ),
                Expanded(
                  child: Slider(
                    min: 20,
                    max: 40,
                    divisions: 10,
                    value: (s.settings['flagSize'] as num? ?? 28)
                        .toDouble()
                        .clamp(20, 40),
                    onChanged: (v) => s.set('flagSize', v),
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in ['country', 'city'])
                    ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: UiText(
                            kind == 'city' ? 'إضافة مدينة' : 'إضافة دولة',
                          ),
                          onTap: () =>
                              editGeographicReference(context, s, kind),
                        ),
                        ...s
                            .referenceList(kind)
                            .map(
                              (r) => ListTile(
                                leading: CountryBadge(GeoCatalog.recordCode(r)),
                                title: UiText(r['name']),
                                subtitle: UiText(
                                  GeoCatalog.byCode(
                                        GeoCatalog.recordCode(r),
                                      )?['ar'] ??
                                      'ربط الدولة والعلم',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => editGeographicReference(
                                  context,
                                  s,
                                  kind,
                                  r,
                                ),
                              ),
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
