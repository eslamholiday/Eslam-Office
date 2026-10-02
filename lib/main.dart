import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'forms.dart';
import 'pages.dart';
import 'reports.dart';
import 'settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<Store> future = Store.open();
  @override
  Widget build(BuildContext c) => FutureBuilder<Store>(
    future: future,
    builder: (c, s) {
      if (s.hasData) return OfficeApp(s.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: navy,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: s.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: gold,
                            size: 56,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'تعذر فتح البيانات',
                            style: TextStyle(color: Colors.white, fontSize: 24),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            '${s.error}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () =>
                                setState(() => future = Store.open()),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flight_takeoff_rounded,
                            color: gold,
                            size: 70,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Eslam Office',
                            style: TextStyle(color: Colors.white, fontSize: 28),
                          ),
                          SizedBox(height: 28),
                          CircularProgressIndicator(color: gold),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class OfficeApp extends StatelessWidget {
  final Store s;
  const OfficeApp(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final dark = s.settings['dark'] == true;
      final color = Color(s.settings['color'] as int? ?? navy.toARGB32());
      final radius = (s.settings['radius'] as num? ?? 18).toDouble();
      return MaterialApp(
        title: 'Eslam Office',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Cairo',
          brightness: dark ? Brightness.dark : Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: color,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          scaffoldBackgroundColor: dark
              ? const Color(0xff111a24)
              : const Color(0xfff4f6f9),
          visualDensity: s.settings['compact'] == true
              ? VisualDensity.compact
              : VisualDensity.standard,
          appBarTheme: AppBarTheme(
            centerTitle: false,
            backgroundColor: dark
                ? const Color(0xff111a24)
                : const Color(0xfff4f6f9),
            elevation: 0,
            titleTextStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : navy,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: dark ? Colors.white10 : const Color(0xffe4e9ef),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: dark ? const Color(0xff202d3a) : const Color(0xfff7f9fc),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffdce3ec)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffdce3ec)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          iconTheme: const IconThemeData(size: 26),
        ),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(
              (s.settings['textScale'] as num? ?? 1).toDouble(),
            ),
            disableAnimations: s.settings['reduceMotion'] == true,
          ),
          child: child!,
        ),
        home: Shell(s),
      );
    },
  );
}

class Shell extends StatefulWidget {
  final Store s;
  const Shell(this.s, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late String current = widget.s.settings['start'] ?? 'home';
  Widget page(String id) => switch (id) {
    'entries' => EntriesPage(widget.s),
    'customers' => PartiesPage(widget.s, 'customer'),
    'suppliers' => PartiesPage(widget.s, 'supplier'),
    'reports' => ReportsPage(widget.s),
    _ => HomePage(widget.s),
  };
  @override
  Widget build(BuildContext c) {
    final order = List<String>.from(
      widget.s.settings['navOrder'] ?? navLabels.keys.toList(),
    );
    final hidden = List<String>.from(widget.s.settings['navHidden'] ?? []);
    final visible = order.where((k) => !hidden.contains(k)).toList();
    final selected = visible.contains(current) ? current : visible.first;
    return Scaffold(
      body: page(selected),
      bottomNavigationBar: NavigationBar(
        selectedIndex: visible.indexOf(selected),
        onDestinationSelected: (i) => setState(() => current = visible[i]),
        destinations: visible
            .map(
              (k) => NavigationDestination(
                icon: Icon(switch (k) {
                  'home' => Icons.dashboard_outlined,
                  'entries' => Icons.receipt_long_outlined,
                  'customers' => Icons.people_outline,
                  'suppliers' => Icons.business_outlined,
                  _ => Icons.bar_chart_rounded,
                }),
                label: navLabels[k]!,
              ),
            )
            .toList(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Store s;
  const HomePage(this.s, {super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Currency currency = Currency.USD;
  Future<void> add() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إضافة جديدة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['ticket', 'hotel', 'visa', 'settlement', 'expense']
                  .map(
                    (kind) => ActionChip(
                      avatar: Icon(kindIcon(kind)),
                      label: Text(types[kind]!),
                      onPressed: () {
                        Navigator.pop(ctx);
                        newEntry(context, widget.s, kind);
                      },
                    ),
                  )
                  .toList(),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('زبون جديد'),
              onTap: () {
                Navigator.pop(ctx);
                editParty(context, widget.s, 'customer');
              },
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext c) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            tooltip: 'البحث الموحّد',
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => SearchPage(s)),
            ),
            icon: const Icon(Icons.search),
          ),
          TextButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: const Text('جديد'),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: navy),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flight_takeoff, color: gold, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Eslam Office',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Travel • Business • Finance',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              for (final k in [
                'ticket',
                'hotel',
                'visa',
                'settlement',
                'expense',
              ])
                ListTile(
                  leading: Icon(kindIcon(k)),
                  title: Text(types[k]!),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => EntriesPage(s, kind: k),
                      ),
                    );
                  },
                ),
              for (final p in {
                'passenger': 'المسافرون',
                'family': 'العائلات',
              }.entries)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(p.value),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => PartiesPage(s, p.key)),
                    );
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(c);
                  Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => SettingsPage(s)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: s.reload,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navy, Color(0xff1f557d)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلًا إسلام',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'مكتبك، حساباتك، وكل تفاصيل السفر',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'E S L A M   O F F I C E',
                          style: TextStyle(
                            color: gold,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: -.3,
                    child: const Icon(
                      Icons.flight_rounded,
                      size: 78,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.65,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: ['ticket', 'hotel', 'visa', 'settlement']
                  .map(
                    (kind) => Material(
                      color: kindColor(kind).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => newEntry(c, s, kind),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                kindIcon(kind),
                                color: kindColor(kind),
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  kind == 'hotel' ? 'حجز فندق' : '${types[kind]} جديدة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'نظرة على الحسابات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'إظهار / إخفاء المبالغ',
                  onPressed: () =>
                      s.set('hideAmounts', s.settings['hideAmounts'] != true),
                  icon: Icon(
                    s.settings['hideAmounts'] == true
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<Currency>(
              segments: Currency.values
                  .map((v) => ButtonSegment(value: v, label: Text(v.name)))
                  .toList(),
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
            const SizedBox(height: 14),
            FutureBuilder<Map<String, int>>(
              future: s.summary(currency),
              builder: (c, snapshot) {
                final data = snapshot.data ?? {};
                final order = List<String>.from(
                  s.settings['homeCards'] ??
                      ['owed', 'credit', 'profit', 'sale'],
                );
                return GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.65,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: order
                      .map(
                        (k) => AmountBox(
                          {
                            'owed': 'المطلوب من الزبائن',
                            'credit': 'أرصدة لصالح الزبائن',
                            'profit': 'ربح الخدمات',
                            'sale': 'مبيعات الخدمات',
                          }[k]!,
                          s.settings['hideAmounts'] == true
                              ? '••••'
                              : currency.format(data[k] ?? 0),
                          color: k == 'profit' ? const Color(0xff23836c) : null,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخر العمليات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${s.entries.length} عملية',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s.entries.isEmpty)
              const EmptyState(
                'جاهز لأول عملية',
                'ابدأ بإضافة زبون ثم تذكرة أو فندق أو فيزا.',
                icon: Icons.flight_takeoff_outlined,
              )
            else
              ...s.entries.take(5).map((e) => EntryTile(s, e)),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Eslam Holiday • جميع الحقوق محفوظة 2026',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
