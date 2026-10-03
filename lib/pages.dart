import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'forms.dart';
import 'reports.dart';

String entryLabel(Store s, Entry e) => s.name(e.data['customer']).isNotEmpty
    ? s.name(e.data['customer'])
    : s.name(e.data['supplier']).isNotEmpty
    ? s.name(e.data['supplier'])
    : e.data['notes'] ?? '';

String entryStatus(Store s, Entry e) {
  if (!e.posted) return 'مسودة';
  if (e.kind == 'refund') return 'استرجاع';
  if (['ticket', 'hotel', 'visa'].contains(e.kind)) {
    final refunds = s.entries.where(
      (r) => r.posted && r.kind == 'refund' && r.data['original'] == e.id,
    );
    if (refunds.isEmpty) return 'فعالة';
    final reversedSale = refunds.fold<int>(0, (sum, r) => sum + r.sale);
    final reversedCost = refunds.fold<int>(0, (sum, r) => sum + r.cost);
    if (reversedSale >= e.sale && reversedCost >= e.cost) {
      return 'مسترجعة بالكامل';
    }
    return 'مسترجعة جزئياً';
  }
  return 'فعالة';
}

String partyDisplayName(Map<String, dynamic> p) {
  final name = (p['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  final phone = (p['phone'] ?? '').toString().trim();
  return phone.isNotEmpty ? phone : 'حساب بدون اسم';
}

Future<void> phoneActions(BuildContext c, String raw) async {
  if (raw.trim().isEmpty) return;
  await showModalBottomSheet<void>(
    context: c,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('اتصال'),
            onTap: () async {
              Navigator.pop(ctx);
              await launchUrl(Uri(scheme: 'tel', path: raw));
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('واتساب'),
            onTap: () async {
              Navigator.pop(ctx);
              var phone = normalize(raw).replaceAll(RegExp(r'\D'), '');
              if (phone.startsWith('0')) phone = '964${phone.substring(1)}';
              await launchUrl(
                Uri.parse('https://wa.me/$phone'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('نسخ الرقم'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

class EntryTile extends StatelessWidget {
  final Store s;
  final Entry e;
  const EntryTile(this.s, this.e, {super.key});
  @override
  Widget build(BuildContext c) {
    final kind = e.data['ticketType'] == 'change' ? 'change' : e.kind;
    final state = entryStatus(s, e);
    final color = !e.posted
        ? Colors.orange.shade800
        : state.contains('مسترجع')
        ? Colors.red.shade700
        : Colors.teal.shade700;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          c,
          MaterialPageRoute(builder: (_) => EntryDetail(s, e)),
        ),
        child: Padding(
          padding: EdgeInsets.all(s.settings['compact'] == true ? 10 : 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: kindColor(kind).withValues(alpha: .12),
                child: Icon(kindIcon(kind), color: kindColor(kind)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.label} • ${entryLabel(s, e)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '#${e.id} • ${displayDate(e.date)}',
                      style: Theme.of(c).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if ((e.data['attachments'] as List? ?? []).isNotEmpty)
                          const Icon(Icons.attach_file, size: 17),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(c).width * .3,
                ),
                child: Text(
                  s.settings['hideAmounts'] == true
                      ? '••••'
                      : e.currency.format(e.data['amount'] as int? ?? e.sale),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Theme.of(c).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntriesPage extends StatefulWidget {
  final Store s;
  final String? kind;
  const EntriesPage(this.s, {super.key, this.kind});
  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  String query = '';
  String? currency, kind;
  bool drafts = false;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    kind = widget.kind;
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (c, _) {
      final entries = widget.s.entries
          .where(
            (e) =>
                (kind == null || e.kind == kind) &&
                (currency == null || e.currency.name == currency) &&
                (!drafts || !e.posted) &&
                normalize(
                  '${e.id} ${entryLabel(widget.s, e)} ${e.data['notes'] ?? ''}',
                ).contains(query),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.kind == null ? 'العمليات' : types[widget.kind]!),
          actions: [
            if (query.isNotEmpty ||
                currency != null ||
                drafts ||
                kind != widget.kind)
              IconButton(
                tooltip: 'مسح الفلاتر',
                icon: const Icon(Icons.filter_alt_off_outlined),
                onPressed: () => setState(() {
                  query = '';
                  searchController.clear();
                  currency = null;
                  drafts = false;
                  kind = widget.kind;
                }),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'اسم أو رقم العملية',
                ),
                onChanged: (v) => setState(() => query = normalize(v)),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('المسودات'),
                      selected: drafts,
                      onSelected: (v) => setState(() => drafts = v),
                    ),
                    const SizedBox(width: 8),
                    ...Currency.values.map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(v.name),
                          selected: currency == v.name,
                          onSelected: (b) =>
                              setState(() => currency = b ? v.name : null),
                        ),
                      ),
                    ),
                    if (widget.kind == null)
                      ...types.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilterChip(
                            label: Text(e.value),
                            selected: kind == e.key,
                            onSelected: (b) =>
                                setState(() => kind = b ? e.key : null),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: EmptyState(
                        'لا توجد عمليات',
                        'أضف أول عملية لتظهر هنا.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      itemBuilder: (c, i) => EntryTile(widget.s, entries[i]),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class EntryDetail extends StatelessWidget {
  final Store s;
  final Entry e;
  const EntryDetail(this.s, this.e, {super.key});
  @override
  Widget build(BuildContext c) {
    final sale = ['ticket', 'hotel', 'visa', 'refund'].contains(e.kind);
    return Scaffold(
      appBar: AppBar(
        title: Text('${e.label} #${e.id}'),
        actions: [
          if (['ticket', 'visa', 'hotel'].contains(e.kind))
            IconButton(
              tooltip: 'نسخ لإضافة عملية مشابهة',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () {
                final copy = Map<String, dynamic>.from(e.data)
                  ..remove('id')
                  ..remove('corrects')
                  ..remove('original');
                copy.addAll({
                  'date': day(DateTime.now()),
                  'posted': false,
                  'pnr': '',
                  'attachments': <String>[],
                });
                newEntry(c, s, e.kind, draft: Entry(copy));
              },
            ),
          if (e.posted && ['ticket', 'hotel', 'visa'].contains(e.kind))
            IconButton(
              tooltip: 'تصحيح العملية مع حفظ تاريخها',
              icon: const Icon(Icons.edit_note),
              onPressed: () async {
                await newEntry(
                  c,
                  s,
                  e.kind,
                  draft: Entry({
                    ...e.data,
                    'posted': false,
                    'corrects': e.id,
                    'date': day(DateTime.now()),
                  }),
                );
                if (c.mounted) Navigator.pop(c);
              },
            ),
          if (!e.posted)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await newEntry(c, s, e.kind, draft: e);
                if (c.mounted) Navigator.pop(c);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section(e.posted ? 'عملية معتمدة' : 'مسودة', [
            Text('التاريخ: ${displayDate(e.date)} • ${e.currency.name}'),
            if (e.data['customer'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('الزبون: ${s.name(e.data['customer'])}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => AccountPage(s, e.data['customer']),
                  ),
                ),
              ),
            if (e.data['supplier'] != null)
              Text('جهة الإصدار: ${s.name(e.data['supplier'])}'),
            if (e.data['airline'] != null)
              Text('الطيران: ${s.reference(e.data['airline'])}'),

            if (e.passengers.isNotEmpty)
              Text('المسافرون: ${e.passengers.map(s.name).join('، ')}'),
            if (e.data['paymentMethod'] != null)
              Text(
                'طريقة التسديد: ${paymentMethods[e.data['paymentMethod']] ?? ''}',
              ),
            if (sale) ...[
              const SizedBox(height: 16),
              pair(
                AmountBox('البيع', e.currency.format(e.sale)),
                AmountBox('التسديد', e.currency.format(e.cost)),
              ),
              AmountBox('الربح', e.currency.format(e.profit)),
              if (e.kind == 'ticket')
                Text(
                  'العمولة المثبتة: ${((e.data['rate'] ?? 0) / 100)}% • ${e.currency.format(e.data['commission'] ?? 0)}',
                ),
            ] else
              AmountBox('المبلغ', e.currency.format(e.data['amount'] ?? 0)),
            if (e.kind == 'ticket')
              ...((e.data['lines'] as List? ?? [])
                  .asMap()
                  .entries
                  .where((r) => r.value['qty'] > 0)
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${['بالغ', 'طفل', 'رضيع'][r.key]} × ${r.value['qty']} • بيع الوحدة ${e.currency.format(r.value['sell'])}',
                      ),
                    ),
                  )),
            if (e.kind == 'visa')
              Text('العدد: ${e.data['qty']} • ${e.data['visaType'] ?? ''}'),
            if (e.kind == 'hotel')
              Text(
                '${e.data['hotelName'] ?? ''}\n${e.data['checkIn'] ?? ''} — ${e.data['checkOut'] ?? ''}',
              ),
            if (e.data['notes'] != null && e.data['notes'] != '')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(e.data['notes']),
              ),
          ]),
          if ((e.data['attachments'] as List? ?? []).isNotEmpty)
            Section(
              'المرفقات',
              List<String>.from(e.data['attachments'])
                  .map(
                    (path) => ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: const Text('فتح المرفق'),
                      onTap: () => openAttachment(c, path),
                    ),
                  )
                  .toList(),
            ),
          if (e.posted && ['ticket', 'hotel', 'visa'].contains(e.kind))
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => refundDialog(c, s, e),
                    icon: const Icon(Icons.undo),
                    label: const Text('استرجاع / عكس العملية'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final copy = Map<String, dynamic>.from(e.data)
                        ..['posted'] = false
                        ..['date'] = day(DateTime.now())
                        ..remove('corrects')
                        ..remove('original');
                      newEntry(c, s, e.kind, draft: Entry(copy));
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('نسخ كعملية جديدة'),
                  ),
                ],
              ),
            ),
          if (e.posted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: c,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف إجباري؟'),
                      content: const Text(
                        'سيتم حذف العملية وكل آثارها وارتباطاتها المالية. '
                        'سيُحفظ سجل يسمح بالتراجع من سجل التعديلات.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف إجباري'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await s.forceDeleteEntry(e);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('حذف إجباري'),
              ),
            ),
          if (!e.posted)
            TextButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: c,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف المسودة؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (yes == true) {
                  await s.deleteDraft(e);
                  if (c.mounted) Navigator.pop(c);
                }
              },
              child: const Text('حذف المسودة'),
            ),
        ],
      ),
    );
  }
}

class PartiesPage extends StatefulWidget {
  final Store s;
  final String kind;
  const PartiesPage(this.s, this.kind, {super.key});
  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  String query = '';
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (c, _) {
      if (widget.kind == 'passenger') return PassengerGroupsPage(widget.s);
      final sort = widget.s.settings['partySort_${widget.kind}'] ?? 'name';
      int amount(int id, Currency v) => widget.s
          .history(id)
          .where((e) => e.currency == v)
          .fold<int>(0, (total, e) => total + widget.s.movement(e, id));
      final rows =
          widget.s
              .list(widget.kind)
              .where(
                (r) => normalize('${r['name']} ${r['phone']}').contains(query),
              )
              .toList()
            ..sort((a, b) {
              final favorite = (b['favorite'] == true ? 1 : 0).compareTo(
                a['favorite'] == true ? 1 : 0,
              );
              if (favorite != 0) return favorite;
              if (sort == 'new') {
                return (b['id'] as int).compareTo(a['id'] as int);
              }
              if (sort == 'recent') {
                return (widget.s.history(b['id']).lastOrNull?.date ?? '')
                    .compareTo(
                      widget.s.history(a['id']).lastOrNull?.date ?? '',
                    );
              }
              if (sort == 'USD' || sort == 'IQD') {
                return amount(
                  b['id'],
                  Currency.values.byName(sort),
                ).compareTo(amount(a['id'], Currency.values.byName(sort)));
              }
              return partyDisplayName(a).compareTo(partyDisplayName(b));
            });
      return Scaffold(
        appBar: AppBar(
          title: Text(
            {
              'customer': 'الزبائن',
              'supplier': 'جهات الإصدار / الموردون',
              'passenger': 'المسافرون',
              'family': 'العائلات',
            }[widget.kind]!,
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'ترتيب الحسابات',
              icon: const Icon(Icons.sort),
              initialValue: sort,
              onSelected: (v) => widget.s.set('partySort_${widget.kind}', v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'name', child: Text('أبجديًا')),
                PopupMenuItem(value: 'new', child: Text('الأحدث إضافة')),
                PopupMenuItem(value: 'recent', child: Text('آخر تعامل')),
                PopupMenuItem(value: 'USD', child: Text('الأعلى رصيدًا USD')),
                PopupMenuItem(value: 'IQD', child: Text('الأعلى رصيدًا IQD')),
              ],
            ),
            IconButton(
              onPressed: () => editParty(c, widget.s, widget.kind),
              icon: const Icon(Icons.person_add_alt),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث بالاسم أو رقم الهاتف',
                ),
                onChanged: (v) => setState(() => query = normalize(v)),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyState(
                      'قائمتك فارغة',
                      'أضف حساباتك لتبدأ العمل.',
                      icon: Icons.people_outline,
                      action: () => editParty(c, widget.s, widget.kind),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (c, i) {
                        final r = rows[i];
                        return Card(
                          child: ListTile(
                            leading: ProfileAvatar(
                              imagePath: r['profileImage'],
                              avatar: r['avatar'],
                              name: partyDisplayName(r),
                            ),
                            title: Text(partyDisplayName(r)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((r['phone'] ?? '').toString().isNotEmpty)
                                  InkWell(
                                    onTap: () => phoneActions(c, r['phone']),
                                    child: Text(
                                      normalizePhone(r['phone']),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
                                if (widget.kind == 'customer')
                                  Text(
                                    '${widget.s.list('passenger').where((p) => p['customer'] == r['id']).length} مسافرين',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (widget.s.settings['showListBalances'] ==
                                    true)
                                  FutureBuilder<List<int>>(
                                    future: Future.wait(
                                      Currency.values.map(
                                        (v) => widget.s.balance(r['id'], v),
                                      ),
                                    ),
                                    builder: (c, snapshot) => Text(
                                      widget.s.settings['hideAmounts'] == true
                                          ? '••••'
                                          : snapshot.hasData
                                          ? '${Currency.USD.format(snapshot.data![0])}  |  ${Currency.IQD.format(snapshot.data![1])}'
                                          : '…',
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (r['favorite'] == true)
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                if ([
                                  'customer',
                                  'supplier',
                                ].contains(widget.kind))
                                  IconButton(
                                    tooltip: 'كشف سريع',
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    onPressed: () => Navigator.push(
                                      c,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StatementPage(widget.s, r['id']),
                                      ),
                                    ),
                                  ),
                                const Icon(Icons.chevron_left),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                builder: (_) => AccountPage(widget.s, r['id']),
                              ),
                            ),
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

class AccountPage extends StatefulWidget {
  final Store s;
  final int id;
  const AccountPage(this.s, this.id, {super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Store get s => widget.s;
  int get id => widget.id;
  String tab = 'operations';
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final p = s.parties.where((r) => r['id'] == id).firstOrNull;
      if (p == null) {
        return const Scaffold(body: Center(child: Text('تم حذف الحساب')));
      }
      final financial = ['customer', 'supplier'].contains(p['kind']);
      final history = s.history(id);
      return Scaffold(
        appBar: AppBar(
          title: Text(partyDisplayName(p)),
          actions: [
            if (financial)
              IconButton(
                tooltip: p['favorite'] == true
                    ? 'إزالة من المفضلة'
                    : 'إضافة للمفضلة',
                onPressed: () => s.saveParty({
                  ...p,
                  'favorite': p['favorite'] != true,
                }, id: id),
                icon: Icon(
                  p['favorite'] == true ? Icons.star : Icons.star_border,
                  color: p['favorite'] == true ? Colors.amber : null,
                ),
              ),
            IconButton(
              onPressed: () => editParty(c, s, p['kind'], party: p),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Section('ملف الحساب', [
              Center(
                child: ProfileAvatar(
                  imagePath: p['profileImage'],
                  avatar: p['avatar'],
                  name: partyDisplayName(p),
                  radius: 40,
                ),
              ),
              const SizedBox(height: 10),
              if (p['phone'] != '')
                ActionChip(
                  avatar: const Icon(Icons.phone_outlined),
                  label: Text(p['phone']),
                  onPressed: () => phoneActions(c, p['phone']),
                ),
              if (p['notes'] != null && p['notes'] != '') Text(p['notes']),
              if (financial)
                FutureBuilder<List<int>>(
                  future: Future.wait(
                    Currency.values.map((v) => s.balance(id, v)),
                  ),
                  builder: (c, snapshot) => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: pair(
                      AmountBox(
                        'رصيد USD',
                        snapshot.hasData
                            ? Currency.USD.format(snapshot.data![0])
                            : '…',
                      ),
                      AmountBox(
                        'رصيد IQD',
                        snapshot.hasData
                            ? Currency.IQD.format(snapshot.data![1])
                            : '…',
                      ),
                    ),
                  ),
                ),
              if (financial)
                const Text(
                  'عليه = مستحق • له = رصيد لصالح الحساب • صفر = متوازن',
                ),
            ]),
            if (financial)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => newEntry(
                      c,
                      s,
                      'settlement',
                      party: id,
                      supplier: p['kind'] == 'supplier',
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('تسوية'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => StatementPage(s, id)),
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('كشف الحساب'),
                  ),
                  TextButton(
                    onPressed: () => newEntry(
                      c,
                      s,
                      'opening',
                      party: id,
                      supplier: p['kind'] == 'supplier',
                    ),
                    child: const Text('رصيد افتتاحي'),
                  ),
                  if (p['kind'] == 'customer') ...[
                    ActionChip(
                      label: const Text('+ تذكرة'),
                      onPressed: () => newEntry(c, s, 'ticket', party: id),
                    ),
                    ActionChip(
                      label: const Text('+ فندق'),
                      onPressed: () => newEntry(c, s, 'hotel', party: id),
                    ),
                    ActionChip(
                      label: const Text('+ فيزا'),
                      onPressed: () => newEntry(c, s, 'visa', party: id),
                    ),
                  ],
                  if (p['kind'] == 'supplier') ...[
                    ActionChip(
                      label: const Text('+ تذكرة'),
                      onPressed: () =>
                          newEntry(c, s, 'ticket', party: id, supplier: true),
                    ),
                    ActionChip(
                      label: const Text('+ فندق'),
                      onPressed: () =>
                          newEntry(c, s, 'hotel', party: id, supplier: true),
                    ),
                    ActionChip(
                      label: const Text('+ فيزا'),
                      onPressed: () =>
                          newEntry(c, s, 'visa', party: id, supplier: true),
                    ),
                  ],
                ],
              ),
            if (p['kind'] == 'customer')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'operations', label: Text('العمليات')),
                    ButtonSegment(
                      value: 'passengers',
                      label: Text('المسافرون'),
                    ),
                    ButtonSegment(
                      value: 'attachments',
                      label: Text('المرفقات'),
                    ),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                ),
              ),
            if (p['kind'] == 'customer' && tab == 'passengers') ...[
              Section('المسافرون التابعون', [
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('إضافة مسافر'),
                  onPressed: () =>
                      editParty(c, s, 'passenger', party: {'customer': id}),
                ),
                ...s
                    .list('passenger')
                    .where((r) => r['customer'] == id)
                    .map(
                      (r) => ListTile(
                        title: Text(r['name']),
                        onTap: () => editParty(c, s, 'passenger', party: r),
                      ),
                    ),
              ]),
            ],
            if (financial && (p['kind'] != 'customer' || tab == 'operations'))
              Section('ملخص الحساب', [
                Text(
                  'عدد الخدمات: ${history.where((e) => ['ticket', 'visa', 'hotel'].contains(e.kind)).length}',
                ),
                if (history.isNotEmpty)
                  Text('آخر حركة: ${displayDate(history.last.date)}'),
                for (final currency in Currency.values) ...[
                  Text(
                    'إجمالي الخدمات ${currency.name}: ${currency.format(history.where((e) => e.currency == currency && ['ticket', 'visa', 'hotel', 'refund'].contains(e.kind)).fold<int>(0, (sum, e) => sum + s.movement(e, id)))}',
                  ),
                  Text(
                    'التسديدات ${currency.name}: ${currency.format(history.where((e) => e.currency == currency && e.kind == 'settlement').fold<int>(0, (sum, e) => sum - s.movement(e, id)))}',
                  ),
                ],
              ]),
            if (!financial)
              ...s.parties
                  .where((r) => r['family'] == id || r['customer'] == id)
                  .map(
                    (r) => ListTile(
                      title: Text(r['name']),
                      onTap: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => AccountPage(s, r['id']),
                        ),
                      ),
                    ),
                  ),
            if (financial && (p['kind'] != 'customer' || tab == 'operations'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'حركة الحساب',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تبديل عرض الجدول',
                      onPressed: () =>
                          s.set('table_$id', s.settings['table_$id'] != true),
                      icon: const Icon(Icons.table_chart_outlined),
                    ),
                  ],
                ),
              ),
            if (p['kind'] != 'customer' || tab == 'operations') ...[
              if (s.settings['table_$id'] == true)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('العملية')),
                      DataColumn(label: Text('الحركة')),
                    ],
                    rows: history
                        .map(
                          (e) => DataRow(
                            cells: [
                              DataCell(
                                Text(displayDate(e.date, weekday: false)),
                              ),
                              DataCell(
                                Text('#${e.id} ${e.label}'),
                                onTap: () => Navigator.push(
                                  c,
                                  MaterialPageRoute(
                                    builder: (_) => EntryDetail(s, e),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(e.currency.format(s.movement(e, id))),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                )
              else
                ...types.entries
                    .where((k) => history.any((e) => e.kind == k.key))
                    .map(
                      (k) => Card(
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            '${k.value} (${history.where((e) => e.kind == k.key).length})',
                          ),
                          children: history.reversed
                              .where((e) => e.kind == k.key)
                              .map((e) => EntryTile(s, e))
                              .toList(),
                        ),
                      ),
                    ),
            ],
            if (p['kind'] == 'customer' &&
                tab == 'attachments' &&
                (p['attachments'] as List? ?? []).isEmpty)
              const EmptyState(
                'لا توجد مرفقات',
                'أضف مرفقات من تعديل الحساب',
                icon: Icons.attach_file,
              ),
            if ((p['kind'] != 'customer' || tab == 'attachments') &&
                (p['attachments'] as List? ?? []).isNotEmpty)
              Section(
                'المرفقات',
                List<String>.from(p['attachments'])
                    .map(
                      (path) => ListTile(
                        title: const Text('فتح المرفق'),
                        leading: const Icon(Icons.attach_file),
                        onTap: () => openAttachment(c, path),
                      ),
                    )
                    .toList(),
              ),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                'حذف الحساب وكل بياناته',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: c,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف الحساب نهائيًا؟'),
                    content: const Text(
                      'سيتم حذف الحساب والمسافرين التابعين وحركاته المالية. ستتغير أرصدة جهات الإصدار والأرباح المرتبطة بهذه الحركات.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (yes != true) return;
                try {
                  await s.deleteParty(id);
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  if (c.mounted) message(c, e);
                }
              },
            ),
            TextButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: c,
                  builder: (ctx) => AlertDialog(
                    title: const Text('أرشفة الحساب؟'),
                    content: const Text(
                      'يبقى تاريخه المالي محفوظًا ويمكن استعادته من المحذوفات.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('أرشفة'),
                      ),
                    ],
                  ),
                );
                if (yes == true) {
                  await s.archiveParty(id, true);
                  if (c.mounted) Navigator.pop(c);
                }
              },
              child: const Text('أرشفة الحساب'),
            ),
          ],
        ),
      );
    },
  );
}

class SearchPage extends StatefulWidget {
  final Store s;
  const SearchPage(this.s, {super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final s = widget.s;
    final tokens = normalize(
      query,
    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    bool matches(String v) => tokens.every((t) => normalize(v).contains(t));
    final parties = query.trim().isEmpty
        ? <Map<String, dynamic>>[]
        : s.parties
              .where(
                (r) =>
                    r['kind'] != 'family' &&
                    r['archived'] == 0 &&
                    matches('${r['name']} ${r['phone']}'),
              )
              .toList();
    final entries = query.trim().isEmpty
        ? <Entry>[]
        : s.entries.where((e) {
            final d = e.data;
            final customer = s.parties
                .where((p) => p['id'] == d['customer'])
                .firstOrNull;
            return matches(
              '${e.id} ${e.label} ${customer?['name'] ?? ''} ${customer?['phone'] ?? ''} ${s.name(d['supplier'])} ${d['hotelName'] ?? ''} ${s.reference(d['airline'])} ${s.reference(d['city'])} ${s.reference(d['from'])} ${s.reference(d['to'])}',
            );
          }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('البحث الموحّد')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'اسم، هاتف، أو رقم العملية',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const EmptyState(
                    'كل مكتبك في بحث واحد',
                    'ابحث عن حساب أو عملية وافتح النتيجة مباشرة.',
                    icon: Icons.search_rounded,
                  )
                : parties.isEmpty && entries.isEmpty
                ? const EmptyState(
                    'لا توجد نتائج',
                    'جرّب جزءًا من الاسم أو الرقم.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: parties.length + entries.length,
                    itemBuilder: (c, i) {
                      if (i < parties.length) {
                        final p = parties[i];
                        return Card(
                          child: ListTile(
                            leading: ProfileAvatar(
                              imagePath: p['profileImage'],
                              avatar: p['avatar'],
                            ),
                            title: Text(partyDisplayName(p)),
                            subtitle: p['phone'] == ''
                                ? null
                                : InkWell(
                                    onTap: () => phoneActions(c, p['phone']),
                                    child: Text(
                                      p['phone'],
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                            onTap: () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                builder: (_) => AccountPage(s, p['id']),
                              ),
                            ),
                          ),
                        );
                      }
                      return EntryTile(s, entries[i - parties.length]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PassengerGroupsPage extends StatefulWidget {
  final Store s;
  const PassengerGroupsPage(this.s, {super.key});
  @override
  State<PassengerGroupsPage> createState() => _PassengerGroupsPageState();
}

class _PassengerGroupsPageState extends State<PassengerGroupsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.s,
    builder: (context, _) {
      final s = widget.s;
      final passengers = s.list('passenger');
      final owners = s.parties.where((p) => p['kind'] == 'customer').toList();
      final ids = owners.map((p) => p['id']).toSet();
      final groups = <Map<String, dynamic>>[
        ...owners,
        {'id': null, 'name': 'مسافرون غير مرتبطين'},
      ];
      final visible = groups.where((owner) {
        final children = passengers.where(
          (p) => owner['id'] == null
              ? !ids.contains(p['customer'])
              : p['customer'] == owner['id'],
        );
        return (owner['id'] != null || children.isNotEmpty) &&
            (normalize('${owner['name']}').contains(query) ||
                children.any(
                  (p) =>
                      normalize('${p['name']} ${p['phone']}').contains(query),
                ));
      }).toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('المسافرون حسب الزبون'),
          actions: [
            IconButton(
              tooltip: 'إضافة مسافر',
              onPressed: () => editParty(context, s, 'passenger'),
              icon: const Icon(Icons.person_add_alt),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'اسم الزبون أو المسافر أو الهاتف',
                ),
                onChanged: (v) => setState(() => query = normalize(v)),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyState(
                      'لا توجد نتائج',
                      'أضف زبونًا ومسافريه أو غيّر البحث',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: visible.map((owner) {
                        final all = passengers
                            .where(
                              (p) => owner['id'] == null
                                  ? !ids.contains(p['customer'])
                                  : p['customer'] == owner['id'],
                            )
                            .toList();
                        final children = all
                            .where(
                              (p) =>
                                  normalize(
                                    '${owner['name']}',
                                  ).contains(query) ||
                                  normalize(
                                    '${p['name']} ${p['phone']}',
                                  ).contains(query),
                            )
                            .toList();
                        return Card(
                          child: ExpansionTile(
                            key: ValueKey('${owner['id']}-$query'),
                            initiallyExpanded: query.isNotEmpty,
                            leading: ProfileAvatar(
                              name: owner['name'],
                              imagePath: owner['profileImage'],
                              avatar: owner['avatar'],
                            ),
                            title: Text('${owner['name']}'),
                            subtitle: Text(
                              '${all.length} مسافرين${owner['archived'] == 1 ? ' • زبون مؤرشف' : ''}',
                            ),
                            children: [
                              ...children.map(
                                (p) => ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(partyDisplayName(p)),
                                  subtitle: Text('تابع إلى: ${owner['name']}'),
                                  trailing: const Icon(Icons.chevron_left),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AccountPage(s, p['id']),
                                    ),
                                  ),
                                ),
                              ),
                              if (children.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('لا يوجد مسافرون لهذا الزبون'),
                                ),
                              TextButton.icon(
                                onPressed: () => editParty(
                                  context,
                                  s,
                                  'passenger',
                                  party: {'customer': owner['id']},
                                ),
                                icon: const Icon(Icons.person_add_alt),
                                label: const Text('إضافة مسافر'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
