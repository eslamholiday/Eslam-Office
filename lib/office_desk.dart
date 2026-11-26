import 'package:flutter/material.dart';
import 'domain.dart';
import 'labels.dart';
import 'store.dart';
import 'ui.dart';
import 'pages.dart';
import 'forms.dart';
import 'reports.dart';
import 'settings.dart';
import 'money_pages.dart';

class OfficeDesk extends StatefulWidget {
  final Store s;
  const OfficeDesk(this.s, {super.key});
  @override
  State<OfficeDesk> createState() => _OfficeDeskState();
}

class _OfficeDeskState extends State<OfficeDesk> {
  Store get s => widget.s;
  Object? sourceEntries;
  Future<List<Map<String, int>>>? summaries;
  @override
  Widget build(BuildContext context) {
    if (!identical(sourceEntries, s.entries)) {
      sourceEntries = s.entries;
      summaries = Future.wait(Currency.values.map(s.summary));
    }
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    final hidden = List<String>.from(s.settings['homeShortcutHidden'] ?? []);
    final drafts = s.entries.where((e) => !e.posted).take(4).toList();
    final recent = s.entries.where((e) => e.posted).take(3).toList();
    final recovered = s.settings.entries
        .where(
          (e) =>
              e.key.startsWith('recovery_') &&
              e.value is Map &&
              e.value['kind'] != null,
        )
        .take(3)
        .toList();
    Widget book(
      String label,
      IconData icon,
      VoidCallback action, {
      int material = 1,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: action,
            child: OfficeSurface(
              material: material,
              stitched: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 5,
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 36, color: const Color(0xffe6c98d)),
                    const SizedBox(height: 12),
                    UiText(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffffedc9),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: ClayAppBar(
        title: const UiText('Eslam Money'),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search),
            onPressed: () => open(SearchPage(s)),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => open(SettingsPage(s)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.reload,
        child: ListView(
          key: const PageStorageKey('office-desk'),
          padding: const EdgeInsets.all(14),
          children: [
            FutureBuilder<List<Map<String, int>>>(
              future: summaries,
              builder: (c, snapshot) => Row(
                children: [
                  for (var i = 0; i < Currency.values.length; i++)
                    Expanded(
                      child: Card(
                        child: PackPaper(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                UiText(
                                  'المطلوب من الزبائن ${Currency.values[i].name}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: UiText(
                                    s.settings['hideAmounts'] == true
                                        ? '••••'
                                        : snapshot.hasData
                                        ? Currency.values[i].format(
                                            snapshot.data![i]['owed'] ?? 0,
                                          )
                                        : '…',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Section('شغل المكتب', [
              if (s.settings['showRecoveryHome'] != false)
                for (final saved in recovered)
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: UiText(
                      'متابعة ${types[saved.value['kind']] ?? 'عملية'}',
                    ),
                    subtitle: const UiText('إدخال محفوظ تلقائياً'),
                    onTap: () => open(
                      EntryForm(
                        s,
                        saved.value['kind'],
                        draft: Entry(
                          Map<String, dynamic>.from(saved.value),
                          int.tryParse(saved.key.split('_').last),
                        ),
                        resume: true,
                      ),
                    ),
                  ),
              for (final e in drafts)
                ListTile(
                  leading: Icon(kindIcon(e.kind)),
                  title: UiText('${e.label} • ${entryLabel(s, e)}'),
                  trailing: const Icon(Icons.chevron_left),
                  subtitle: const UiText('مسودة'),
                  onTap: () => open(EntryForm(s, e.kind, draft: e)),
                ),
              if (drafts.isEmpty && recovered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: UiText(
                    'أضف عملية جديدة، أو افتح ملف زبون لإكمال شغلك.',
                  ),
                ),
            ]),
            Row(
              children: [
                book(
                  'الزبائن',
                  Icons.people_outline,
                  () => open(PartiesPage(s, 'customer')),
                ),
                book(
                  'الحسابات',
                  Icons.menu_book,
                  () => open(StatementsHub(s)),
                  material: 5,
                ),
                book(
                  'العمليات',
                  Icons.receipt_long,
                  () => open(EntriesPage(s)),
                  material: 5,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final kind = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in types.entries.where(
                          (e) => !['refund', 'change'].contains(e.key),
                        ))
                          ListTile(
                            leading: ArtIcon(artIndex(e.key), size: 34),
                            title: UiText(e.value),
                            onTap: () => Navigator.pop(ctx, e.key),
                          ),
                      ],
                    ),
                  ),
                );
                if (context.mounted && kind != null) {
                  await newEntry(context, s, kind);
                }
              },
              icon: const Icon(Icons.add),
              label: const UiText('عملية جديدة'),
            ),
            if (s.settings['homeServiceCards'] != false)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in const {
                      'ticket': 'تذكرة',
                      'hotel': 'فندق',
                      'visa': 'فيزا',
                      'settlement': 'قبض / دفع',
                    }.entries)
                      ActionChip(
                        avatar: Icon(kindIcon(e.key)),
                        label: UiText(e.value),
                        onPressed: () => newEntry(context, s, e.key),
                      ),
                  ],
                ),
              ),
            Section('آخر الحركات', [
              if (recent.isEmpty) const UiText('ستظهر حركات المكتب هنا.'),
              for (final e in recent)
                ListTile(
                  leading: Icon(kindIcon(e.kind)),
                  title: UiText('${e.label} • ${entryLabel(s, e)}'),
                  subtitle: UiText(displayDate(e.date)),
                  trailing: UiText(
                    s.settings['hideAmounts'] == true
                        ? '••••'
                        : e.currency.format(e.sale),
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => open(EntryDetail(s, e)),
                ),
            ]),
            Section('نظرة على الحسابات', [
              FutureBuilder<List<Map<String, int>>>(
                future: summaries,
                builder: (c, snapshot) => Column(
                  children: [
                    for (final key in List<String>.from(
                      s.settings['homeCards'] ??
                          ['owed', 'profit', 'payable', 'expenses'],
                    ))
                      if (!List<String>.from(
                            s.settings['homeCardsHidden'] ?? [],
                          ).contains(key) &&
                          const {
                            'owed',
                            'profit',
                            'payable',
                            'expenses',
                          }.contains(key))
                        ListTile(
                          title: UiText(
                            const {
                              'owed': 'المطلوب من الزبائن',
                              'profit': 'ربح الخدمات',
                              'payable': 'مستحقات الإصدار',
                              'expenses': 'المصروفات',
                            }[key]!,
                          ),
                          subtitle: Wrap(
                            spacing: 18,
                            children: [
                              for (var i = 0; i < 2; i++)
                                UiText(
                                  s.settings['hideAmounts'] == true
                                      ? '••••'
                                      : snapshot.hasData
                                      ? Currency.values[i].format(
                                          snapshot.data![i][key] ?? 0,
                                        )
                                      : '…',
                                  textDirection: TextDirection.ltr,
                                ),
                            ],
                          ),
                          onTap: () => open(
                            key == 'profit'
                                ? ReportsPage(s)
                                : key == 'expenses'
                                ? ExpensesPage(s)
                                : key == 'payable'
                                ? SupplierBalances(s)
                                : PartiesPage(s, 'customer'),
                          ),
                        ),
                  ],
                ),
              ),
            ]),
            Section('دفاتر المكتب', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!hidden.contains('passengers'))
                    ActionChip(
                      label: const UiText('المسافرون'),
                      onPressed: () => open(PartiesPage(s, 'passenger')),
                    ),
                  if (!hidden.contains('suppliers'))
                    ActionChip(
                      label: const UiText('جهات الإصدار'),
                      onPressed: () => open(PartiesPage(s, 'supplier')),
                    ),
                  if (!hidden.contains('expense'))
                    ActionChip(
                      label: const UiText('المصروف'),
                      onPressed: () => open(ExpensesPage(s)),
                    ),
                  if (!hidden.contains('review'))
                    ActionChip(
                      label: const UiText('مركز التدقيق'),
                      onPressed: () => open(ReviewPage(s)),
                    ),
                  ActionChip(
                    label: const UiText('الأرباح والتقارير'),
                    onPressed: () => open(ReportsPage(s)),
                  ),
                ],
              ),
              SwitchListTile(
                title: const UiText('إظهار المبالغ'),
                value: s.settings['hideAmounts'] != true,
                onChanged: (value) => s.set('hideAmounts', !value),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
