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
import 'experience.dart';

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
      final mode =
          s.settings['appearanceMode'] ??
          (s.settings['dark'] == true ? 'dark' : 'light');
      return MaterialApp(
        title: 'Eslam Money',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: packTheme(Brightness.light, s.settings),
        darkTheme: packTheme(Brightness.dark, s.settings),
        themeMode: mode == 'system'
            ? ThemeMode.system
            : mode == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light,
        navigatorObservers: [experienceObserver],
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(c).scale(1) *
                  (s.settings['textScale'] as num? ?? 1).toDouble(),
            ),
            disableAnimations:
                MediaQuery.disableAnimationsOf(c) ||
                s.settings['reduceMotion'] == true,
          ),
          child: ExperienceTapRegion(child: child!),
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
  Store get s => widget.s;
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
      body: AnimatedSwitcher(
        duration: Duration(
          milliseconds:
              s.settings['reduceMotion'] == true ||
                  MediaQuery.disableAnimationsOf(c)
              ? 0
              : s.settings['motionPace'] == 'quick'
              ? 130
              : 230,
        ),
        child: KeyedSubtree(key: ValueKey(selected), child: page(selected)),
      ),
      bottomNavigationBar: GestureDetector(
        onHorizontalDragEnd: s.settings['swipeTabs'] == false
            ? null
            : (details) {
                final speed = details.primaryVelocity ?? 0;
                if (speed.abs() < 180) return;
                final next = (visible.indexOf(selected) + (speed > 0 ? 1 : -1))
                    .clamp(0, visible.length - 1);
                if (visible[next] != selected) {
                  Experience.fire('navigate');
                  setState(() => current = visible[next]);
                }
              },
        child: NavigationBar(
          selectedIndex: visible.indexOf(selected),
          onDestinationSelected: (i) {
            if (current != visible[i]) Experience.fire('navigate');
            setState(() => current = visible[i]);
          },
          destinations: visible
              .map(
                (k) => NavigationDestination(
                  icon: ArtIcon(artIndex(k), size: 32),
                  selectedIcon: ArtIcon(artIndex(k), size: 40),
                  label: navLabels[k]!,
                ),
              )
              .toList(),
        ),
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
      appBar: ClayAppBar(
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [coral, Color(0xfffa986e)]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtIcon(0, size: 56),
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
                  applicationVersion: '2.0.0',
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
            const ServiceBanner(
              kind: 'expense',
              title: 'أهلًا إسلام',
              subtitle: 'Eslam Money • مكتبك بين إيديك',
              height: 140,
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
                      applicationVersion: '2.0.0',
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
            if (s.settings['homeServiceCards'] != false) ...[
              Tactile(
                child: ServiceBanner(
                  kind: 'ticket',
                  title: 'التذاكر',
                  subtitle: 'طيران • إصدار • تغيير',
                  onTap: () => open(EntryForm(s, 'ticket')),
                ),
              ),
              Tactile(
                child: ServiceBanner(
                  kind: 'visa',
                  title: 'الفيزا',
                  subtitle: 'جوازات • طلبات • مواعيد',
                  onTap: () => open(EntryForm(s, 'visa')),
                ),
              ),
              Tactile(
                child: ServiceBanner(
                  kind: 'hotel',
                  title: 'الفنادق',
                  subtitle: 'حجوزات • غرف • ضيافة',
                  onTap: () => open(EntryForm(s, 'hotel')),
                ),
              ),
            ],
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
                                    ArtIcon(switch (stat.$1) {
                                      'تذاكر' => 0,
                                      'فيز' => 1,
                                      'فنادق' => 2,
                                      'مسافرون' || 'زبائن' => 5,
                                      'شركات الإصدار' => 6,
                                      'التسوية' => 4,
                                      _ => 3,
                                    }, size: 42),
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
