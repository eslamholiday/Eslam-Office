import 'package:flutter/material.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'forms.dart';
import 'pages.dart';
import 'reports.dart';

class StatementsHub extends StatelessWidget {
  final Store s;
  const StatementsHub(this.s, {super.key});
  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('الكشوفات'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'الزبائن'),
            Tab(text: 'جهات الإصدار'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          'customer',
          'supplier',
        ].map((kind) => StatementAccounts(s, kind)).toList(),
      ),
    ),
  );
}

class StatementAccounts extends StatefulWidget {
  final Store s;
  final String kind;
  const StatementAccounts(this.s, this.kind, {super.key});
  @override
  State<StatementAccounts> createState() => _StatementAccountsState();
}

class _StatementAccountsState extends State<StatementAccounts> {
  String query = '';
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        decoration: const InputDecoration(
          labelText: 'بحث عن حساب',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => query = normalize(v)),
      ),
      const SizedBox(height: 12),
      ...widget.s
          .list(widget.kind)
          .where((p) => normalize('${p['name']} ${p['phone']}').contains(query))
          .map(
            (p) => Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(p['name']),
                subtitle: Text(normalizePhone(p['phone'] ?? '')),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => StatementPage(widget.s, p['id']),
                  ),
                ),
              ),
            ),
          ),
    ],
  );
}

class SupplierBalances extends StatelessWidget {
  final Store s;
  const SupplierBalances(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('مستحقات جهات الإصدار')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...s.parties
            .where((p) => p['kind'] == 'supplier')
            .map(
              (p) => FutureBuilder<List<int>>(
                future: Future.wait(
                  Currency.values.map((v) => s.balance(p['id'], v)),
                ),
                builder: (c, snapshot) => Card(
                  child: ListTile(
                    title: Text(p['name']),
                    subtitle: Text(
                      snapshot.hasData
                          ? '${Currency.USD.format(snapshot.data![0])}\n${Currency.IQD.format(snapshot.data![1])}'
                          : '…',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => AccountPage(s, p['id']),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}

class ReviewPage extends StatelessWidget {
  final Store s;
  const ReviewPage(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final rows = s.entries
          .where((e) => s.reviewIssues(e).isNotEmpty)
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('مركز التدقيق')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${rows.length} عملية تحتاج مراجعة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text('التنبيهات للمراجعة ولا تغيّر القيم أو تمنع الحفظ.'),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const EmptyState(
                'لا توجد ملاحظات تدقيق',
                'تمت مراجعة الحقول والحسابات الأساسية.',
              ),
            ...rows.map(
              (e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text('#${e.id} ${e.label} • ${entryLabel(s, e)}'),
                  subtitle: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: s
                        .reviewIssues(e)
                        .map(
                          (issue) => Chip(
                            label: Text(
                              issue,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.orange.withValues(
                              alpha: .1,
                            ),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => EntryDetail(s, e)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ExpensesPage extends StatefulWidget {
  final Store s;
  const ExpensesPage(this.s, {super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String range = 'month';
  Currency currency = Currency.USD;
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (c, _) {
      final s = widget.s;
      final dates = quickDateRange(range);
      final rows = s.entries
          .where(
            (e) =>
                e.posted &&
                e.currency == currency &&
                ['expense', 'funding'].contains(e.kind) &&
                (dates[0] == null || e.date.compareTo(dates[0]!) >= 0) &&
                (dates[1] == null || e.date.compareTo(dates[1]!) <= 0),
          )
          .toList();
      final expenses = rows
          .where((e) => e.kind == 'expense')
          .fold<int>(0, (sum, e) => sum + (e.data['amount'] as int? ?? 0));
      final categories = <String, int>{};
      for (final e in rows.where((e) => e.kind == 'expense')) {
        final name = [
          s.reference(e.data['expenseCategory']),
          e.data['expenseSubcategory'] ?? '',
        ].where((e) => e.toString().isNotEmpty).join(' / ');
        final key = name.isEmpty ? 'غير مصنف' : name;
        categories[key] =
            (categories[key] ?? 0) + (e.data['amount'] as int? ?? 0);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('المصروف')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Section('رصيد المصروف المتاح', [
              const Text(
                'أرباح الخدمات بعد الاسترجاعات + الإضافات اليدوية − جميع المصروفات. هذا رصيد تخصيص للمصروف، وليس رصيد النقد المقبوض.',
              ),
              const SizedBox(height: 12),
              for (final v in Currency.values)
                AmountBox(v.name, v.format(s.expenseBalance(v))),
            ]),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => newEntry(c, s, 'expense'),
                  icon: const Icon(Icons.remove),
                  label: const Text('مصروف جديد'),
                ),
                OutlinedButton.icon(
                  onPressed: () => newEntry(c, s, 'funding'),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة رصيد'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<Currency>(
              segments: Currency.values
                  .map((v) => ButtonSegment(value: v, label: Text(v.name)))
                  .toList(),
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children:
                  {
                        'today': 'اليوم',
                        'month': 'الشهر',
                        'year': 'السنة',
                        'all': 'الكل',
                      }.entries
                      .map(
                        (e) => ChoiceChip(
                          label: Text(e.value),
                          selected: range == e.key,
                          onSelected: (_) => setState(() => range = e.key),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            AmountBox('مصروفات الفترة', currency.format(expenses)),
            ...categories.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: Text(currency.format(e.value)),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('كشف المصروفات'),
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => PdfPage(
                    s,
                    'كشف المصروفات — ${currency.name}',
                    ['التاريخ', 'العملية', 'التصنيف', 'المبلغ'],
                    rows
                        .map(
                          (e) => [
                            displayDate(e.date, weekday: false),
                            '#${e.id} ${e.label}',
                            '${s.reference(e.data['expenseCategory'])} ${e.data['expenseSubcategory'] ?? ''}',
                            currency.format(e.data['amount'] ?? 0),
                          ],
                        )
                        .toList(),
                    [
                      'مصروفات الفترة: ${currency.format(expenses)}',
                      'الرصيد الحالي لكل الفترات: ${currency.format(s.expenseBalance(currency))}',
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...rows.map((e) => EntryTile(s, e)),
          ],
        ),
      );
    },
  );
}
