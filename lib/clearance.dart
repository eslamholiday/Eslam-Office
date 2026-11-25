import 'labels.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'reports.dart';
import 'input_schema.dart';

Set<int> clearanceSelection(
  List<Entry> entries, {
  Entry? entry,
  int? party,
  bool all = false,
}) {
  final ids = <int>{if (entry?.id != null) entry!.id!};
  ids.addAll(
    entries
        .where(
          (e) => all
              ? e.posted
              : party != null &&
                    (e.data['customer'] == party ||
                        e.data['supplier'] == party),
        )
        .map((e) => e.id!),
  );
  bool changed;
  do {
    changed = false;
    for (final e in entries) {
      final links = [e.data['original'], e.data['corrects']].whereType<int>();
      if (ids.contains(e.id)) {
        for (final id in links) {
          if (entries.any((e) => e.id == id) && ids.add(id)) changed = true;
        }
      } else if (links.any(ids.contains) && ids.add(e.id!)) {
        changed = true;
      }
    }
  } while (changed);
  return ids;
}

Future<bool> confirmClearance(
  BuildContext context,
  Store s, {
  Entry? entry,
  int? party,
  bool all = false,
}) async {
  final selected = clearanceSelection(
    s.entries,
    entry: entry,
    party: party,
    all: all,
  );
  bool retire = false, busy = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        icon: const ArtIcon(15, size: 62),
        title: UiText(
          all
              ? 'تصفية جميع العمليات المعتمدة'
              : party == null
              ? 'تصفية وأرشفة العملية'
              : 'تصفية حساب ${s.name(party)}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiText('${selected.length} عملية مع روابطها واسترجاعاتها'),
              const SizedBox(height: 8),
              const UiText(
                'تُنقل التفاصيل والقيود إلى أرشيف الماضي، ويُزال أثرها من الأرصدة والكشوف والأرباح الحالية. الأرشيف للقراءة والتصدير فقط.',
              ),
              if (all)
                const UiText(
                  'يشمل المعتمد فقط؛ تبقى المسودات وبطاقات الحسابات.',
                ),
              if (party != null)
                RadioGroup<bool>(
                  groupValue: retire,
                  onChanged: (v) {
                    if (!busy && v != null) set(() => retire = v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        title: const UiText(
                          'تصفية العمليات وإبقاء بطاقة الحساب',
                        ),
                        value: false,
                        enabled: !busy,
                      ),
                      RadioListTile<bool>(
                        title: const UiText('تصفية وأرشفة الحساب كاملًا'),
                        value: true,
                        enabled: !busy,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx, false),
            child: const UiText('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    try {
                      await s.clearToArchive(
                        entryIds: entry == null ? null : {entry.id!},
                        party: party,
                        retireAccount: retire,
                        all: all,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (error) {
                      if (ctx.mounted) {
                        message(ctx, error);
                        set(() => busy = false);
                      }
                    }
                  },
            icon: const Icon(Icons.inventory_2_outlined),
            label: UiText(busy ? 'جارٍ التصفية…' : 'تصفية ونقل للأرشيف'),
          ),
        ],
      ),
    ),
  );
  return result == true;
}

class ClearanceArchivePage extends StatefulWidget {
  final Store s;
  const ClearanceArchivePage(this.s, {super.key});
  @override
  State<ClearanceArchivePage> createState() => _ClearanceArchivePageState();
}

class _ClearanceArchivePageState extends State<ClearanceArchivePage> {
  String query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.s,
    builder: (context, _) => Scaffold(
      appBar: const ClayAppBar(title: UiText('أرشيف التصفيات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في الأرشيف',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = normalize(v)),
            ),
          ),
          Expanded(
            child: widget.s.clearances.isEmpty
                ? const Center(
                    child: EmptyState(
                      'أرشيف الماضي فارغ',
                      'تظهر هنا التصفيات مع التفاصيل والقيود السابقة.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: widget.s.clearances
                        .where(
                          (b) => normalize(
                            '${b['title']} ${b['date']} ${b['parties']}',
                          ).contains(query),
                        )
                        .map(
                          (b) => Card(
                            child: ListTile(
                              leading: const ArtIcon(15),
                              title: UiText(b['title']),
                              subtitle: UiText(
                                '${displayDate(b['date'].toString().substring(0, 10))} · ${(b['entries'] as List).length} عملية',
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClearanceDetailPage(widget.s, b),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    ),
  );
}

class ClearanceDetailPage extends StatelessWidget {
  final Store s;
  final Map<String, dynamic> batch;
  const ClearanceDetailPage(this.s, this.batch, {super.key});
  Map<String, dynamic> decode(Map raw) => {
    ...raw,
    ...Map<String, dynamic>.from(jsonDecode(raw['payload'] as String)),
  };
  String name(Object? id, String key) =>
      (batch[key] as List)
          .map((r) => decode(r as Map))
          .where((r) => r['id'] == id)
          .firstOrNull?['name'] ??
      '';
  List<Entry> get entries => (batch['entries'] as List)
      .map((r) => Entry.row(Map<String, Object?>.from(r as Map)))
      .toList();
  String description(Entry e) => [
    '${types[e.kind]} #${e.id}',
    if (name(e.data['customer'], 'parties').isNotEmpty)
      'الزبون: ${name(e.data['customer'], 'parties')}',
    if (name(e.data['supplier'], 'parties').isNotEmpty)
      'جهة الإصدار: ${name(e.data['supplier'], 'parties')}',
    if (e.passengers.isNotEmpty)
      e.passengers.map((id) => name(id, 'parties')).join('، '),
    for (final key in ['from', 'to', 'country', 'city'])
      if (e.data[key] != null) name(e.data[key], 'refs'),
    for (final key in [
      'hotelName',
      'visaType',
      'paymentMethod',
      'settlementMode',
      'depart',
      'return',
      'checkIn',
      'checkOut',
      'notes',
    ])
      if ((e.data[key] ?? '').toString().isNotEmpty) '${e.data[key]}',
  ].where((v) => v.isNotEmpty).join(' · ');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClayAppBar(
      title: UiText('تفاصيل التصفية — للقراءة فقط'),
      actions: [],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(batch['title'], [
          UiText('تاريخ التصفية: ${batch['date']}'),
          UiText(
            'العمليات: ${entries.length} · القيود: ${(batch['ledger'] as List).length}',
          ),
          FilledButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const UiText('كشف الأرشيف وتصديره'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfPage(
                  s,
                  batch['title'],
                  ['التاريخ', 'العملية', 'البيع / المبلغ', 'التكلفة السابقة'],
                  entries
                      .map(
                        (e) => [
                          displayDate(e.date, weekday: false),
                          description(e),
                          e.currency.format(e.data['amount'] as int? ?? e.sale),
                          e.currency.format(e.cost),
                        ],
                      )
                      .toList(),
                  [
                    'أرشيف مستقل — لا يدخل الحسابات الحالية',
                    'التصفية: ${batch['date']}',
                  ],
                ),
              ),
            ),
          ),
        ]),
        ...entries.map(
          (e) => Card(
            child: ExpansionTile(
              leading: ArtIcon(artIndex(e.kind)),
              title: UiText('${types[e.kind]} #${e.id}'),
              subtitle: UiText(
                '${displayDate(e.date)} · ${e.currency.format(e.data['amount'] as int? ?? e.sale)}',
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                UiText(description(e)),
                for (final f in inputSpecs(e.kind).where(
                  (f) => ![
                    'attachments',
                    'passengers',
                    'customer',
                    'supplier',
                  ].contains(f.key),
                ))
                  if (e.data[f.key] != null &&
                      e.data[f.key].toString().isNotEmpty)
                    ListTile(
                      dense: true,
                      title: UiText(f.label),
                      subtitle: SelectableText(
                        f.reference != null
                            ? name(e.data[f.key], 'refs')
                            : f.choices.isNotEmpty
                            ? f.choices[e.data[f.key].toString()] ??
                                  e.data[f.key].toString()
                            : f.type == 'money'
                            ? e.currency.format(e.data[f.key] as int? ?? 0)
                            : e.data[f.key].toString(),
                      ),
                    ),
                for (final path in List<String>.from(
                  e.data['attachments'] ?? [],
                ))
                  ListTile(
                    leading: const Icon(Icons.attachment),
                    title: const UiText('عرض المرفق المحفوظ'),
                    onTap: () => openAttachment(context, path),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
