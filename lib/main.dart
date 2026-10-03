import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'domain.dart';
import 'forms.dart';
import 'store.dart';
import 'ui.dart';
import 'pages.dart';
import 'reports.dart';
import 'settings.dart';
import 'money_pages.dart';

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
                            'Eslam Money',
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
      final radius = (s.settings['radius'] as num? ?? 14).toDouble();
      return MaterialApp(
        title: 'Eslam Money',
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
            color: dark ? const Color(0xff1c2937) : Colors.white,
            surfaceTintColor: Colors.transparent,
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
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(
              color: dark ? Colors.white70 : const Color(0xff465568),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
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
          listTileTheme: ListTileThemeData(
            titleTextStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : const Color(0xff1b2b3c),
            ),
            subtitleTextStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: dark ? Colors.white70 : const Color(0xff526273),
            ),
          ),
          iconTheme: const IconThemeData(size: 24),
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
    'customers' => PartiesPage(widget.s, 'customer'),
    'statements' => StatementsHub(widget.s),
    'settings' => SettingsPage(widget.s),
    _ => HomePage(widget.s),
  };
  @override
  Widget build(BuildContext c) {
    final order = List<String>.from(
      widget.s.settings['navOrder'] ?? navLabels.keys.toList(),
    );
    final hidden = List<String>.from(widget.s.settings['navHidden'] ?? []);
    final visible = order
        .where((k) => navLabels.containsKey(k) && !hidden.contains(k))
        .toList();
    if (visible.length < 2) {
      visible.clear();
      visible.addAll(navLabels.keys);
    }
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
                  'statements' => Icons.receipt_long_outlined,
                  'customers' => Icons.people_outline,
                  'settings' => Icons.settings_outlined,
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

class HomePage extends StatelessWidget {
  final Store s;
  const HomePage(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    void open(Widget page) =>
        Navigator.push(c, MaterialPageRoute(builder: (_) => page));
    final shortcuts = <(String, IconData, Widget)>[
      ('المسافرون', Icons.people_outline, PartiesPage(s, 'passenger')),
      ('جهات الإصدار', Icons.business_outlined, PartiesPage(s, 'supplier')),
      ('المصروف', Icons.account_balance_wallet_outlined, ExpensesPage(s)),
      ('الحركات', Icons.history, EntriesPage(s)),
      ('مركز التدقيق', Icons.fact_check_outlined, ReviewPage(s)),
    ];
    final shortcutKeys = [
      'passengers',
      'suppliers',
      'expense',
      'movements',
      'review',
    ];
    final visibleShortcuts = [
      for (var i = 0; i < shortcuts.length; i++)
        if (!List<String>.from(
          s.settings['homeShortcutHidden'] ?? [],
        ).contains(shortcutKeys[i]))
          shortcuts[i],
    ];
    final sales = s.entries.where((e) => e.posted);
    final counts = {
      'تذاكر': sales
          .where((e) => e.kind == 'ticket' && e.data['ticketType'] != 'change')
          .fold<int>(0, (a, e) => a + e.quantity),
      'فيز': sales
          .where((e) => e.kind == 'visa')
          .fold<int>(0, (a, e) => a + e.quantity),
      'فنادق': sales.where((e) => e.kind == 'hotel').length,
      'مسافرون': s.list('passenger').length,
      'زبائن': s.list('customer').length,
      'شركات الإصدار': s.list('supplier').length,
      'التسوية': sales.where((e) => e.kind == 'settlement').length,
      'المصاريف': sales.where((e) => e.kind == 'expense').length,
    };
    final statActions = <(String, IconData, Color, Widget)>[
      (
        'تذاكر',
        Icons.flight_takeoff,
        const Color(0xff388bd1),
        EntryForm(s, 'ticket'),
      ),
      (
        'فيز',
        Icons.badge_outlined,
        const Color(0xff24a58f),
        EntryForm(s, 'visa'),
      ),
      ('فنادق', Icons.hotel, const Color(0xffa474ce), EntryForm(s, 'hotel')),
      (
        'مسافرون',
        Icons.people_outline,
        const Color(0xffdc8b50),
        PartyForm(s, 'passenger'),
      ),
      (
        'زبائن',
        Icons.person_outline,
        const Color(0xff649fe2),
        PartyForm(s, 'customer'),
      ),
      (
        'شركات الإصدار',
        Icons.business_outlined,
        const Color(0xff7894c9),
        PartyForm(s, 'supplier'),
      ),
      (
        'التسوية',
        Icons.swap_horiz,
        const Color(0xffd4a84f),
        EntryForm(s, 'settlement'),
      ),
      (
        'المصاريف',
        Icons.account_balance_wallet_outlined,
        const Color(0xffd3778e),
        EntryForm(s, 'expense'),
      ),
    ];
    const labels = {
      'owed': 'المطلوب من الزبائن',
      'profit': 'ربح الخدمات',
      'payable': 'مستحقات الإصدار',
      'expenses': 'المصروفات',
    };
    final cards =
        List<String>.from(
          s.settings['homeCards'] ?? labels.keys.toList(),
        ).where(
          (k) =>
              labels.containsKey(k) &&
              !List<String>.from(
                s.settings['homeCardsHidden'] ?? [],
              ).contains(k),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            tooltip: 'البحث الموحّد',
            icon: const Icon(Icons.search),
            onPressed: () => open(SearchPage(s)),
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
                    Icon(Icons.flight_takeoff_rounded, color: gold, size: 46),
                    SizedBox(height: 12),
                    Text(
                      'Eslam Money',
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
                    Text(
                      'Travel • Business • Finance',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ...shortcuts.map(
                (e) => ListTile(
                  leading: Icon(e.$2),
                  title: Text(e.$1),
                  onTap: () {
                    Navigator.pop(c);
                    open(e.$3);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('الأرباح والتقارير'),
                onTap: () {
                  Navigator.pop(c);
                  open(ReportsPage(s));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('نبذة التطبيق'),
                onTap: () => showAboutDialog(
                  context: c,
                  applicationName: 'Eslam Money',
                  applicationVersion: '1.3.0',
                  children: [
                    const Text(
                      'Eslam Holiday\nEslamholiday.com\n07713414312\nجميع الحقوق محفوظة 2026',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: s.reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navy, Color(0xff1f557d)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلًا إسلام',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'E S L A M   M O N E Y',
                    style: TextStyle(color: gold, letterSpacing: 2),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'حسابات مكتبك في مكان واحد',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visibleShortcuts.map(
                  (e) => ActionChip(
                    avatar: Icon(e.$2),
                    label: Text(e.$1),
                    onPressed: () => open(e.$3),
                  ),
                ),
                if (!List<String>.from(
                  s.settings['homeShortcutHidden'] ?? [],
                ).contains('about'))
                  ActionChip(
                    avatar: const Icon(Icons.info_outline),
                    label: const Text('نبذة التطبيق'),
                    onPressed: () => showAboutDialog(
                      context: c,
                      applicationName: 'Eslam Money',
                      applicationVersion: '1.3.0',
                      children: [const Text('Eslamholiday.com • 07713414312')],
                    ),
                  ),
              ],
            ),
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
                  icon: Icon(
                    s.settings['hideAmounts'] == true
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      s.set('hideAmounts', s.settings['hideAmounts'] != true),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, int>>>(
              future: Future.wait(Currency.values.map(s.summary)),
              builder: (c, snap) => LayoutBuilder(
                builder: (c, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: cards
                      .map(
                        (key) => SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => open(
                                key == 'payable'
                                    ? SupplierBalances(s)
                                    : key == 'expenses'
                                    ? ExpensesPage(s)
                                    : key == 'owed'
                                    ? PartiesPage(s, 'customer')
                                    : ReportsPage(s),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      labels[key]!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    for (var i = 0; i < 2; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            s.settings['hideAmounts'] == true
                                                ? '••••'
                                                : Currency.values[i].format(
                                                    snap.data?[i][key] ?? 0,
                                                  ),
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            if (s.settings['showHomeStats'] != false) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: statActions
                      .map(
                        (stat) => SizedBox(
                          width:
                              (constraints.maxWidth -
                                  (MediaQuery.textScalerOf(context).scale(1) >
                                          1.1
                                      ? 10
                                      : 30)) /
                              (MediaQuery.textScalerOf(context).scale(1) > 1.1
                                  ? 2
                                  : 4),
                          child: Material(
                            color: Color.alphaBlend(
                              stat.$3.withValues(alpha: .14),
                              Theme.of(context).colorScheme.surface,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('home-stat-${stat.$1}'),
                              onTap: () => open(stat.$4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(stat.$2, color: stat.$3, size: 22),
                                    Text(
                                      '${counts[stat.$1]}',
                                      style: TextStyle(
                                        color: stat.$3,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      stat.$1,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخر الحركات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => open(EntriesPage(s)),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s.entries.isEmpty)
              const EmptyState(
                'جاهز لأول عملية',
                'أضف زبونًا من قسم الزبائن ثم أضف خدماته.',
              )
            else
              ...s.entries.take(5).map((e) => EntryTile(s, e)),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Eslam Holiday • جميع الحقوق محفوظة 2026',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
