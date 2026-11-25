import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'pages.dart';
import 'gallery.dart';
import 'statement_image.dart';
import 'statement_details.dart';
import 'date_range_field.dart';
import 'labels.dart';

int displayConvert(
  int amount,
  Currency from,
  Currency target,
  int dinarsPer100Dollars,
) {
  if (from == target) return amount;
  if (dinarsPer100Dollars <= 0) {
    throw const FormatException('أدخل سعر صرف أكبر من صفر');
  }
  return target == Currency.IQD
      ? roundedRatio(amount * dinarsPer100Dollars, 10000)
      : roundedRatio(amount * 10000, dinarsPer100Dollars);
}

List<String?> quickDateRange(String key) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (key) {
    case 'today':
      return <String?>[day(today), day(today)];
    case 'week':
      return <String?>[
        day(today.subtract(Duration(days: now.weekday - 1))),
        day(today),
      ];
    case 'month':
      return <String?>[
        day(DateTime(now.year, now.month, 1)),
        day(DateTime(now.year, now.month + 1, 0)),
      ];
    case 'previous':
      return <String?>[
        day(DateTime(now.year, now.month - 1, 1)),
        day(DateTime(now.year, now.month, 0)),
      ];
    case 'year':
      return <String?>[
        day(DateTime(now.year, 1, 1)),
        day(DateTime(now.year, 12, 31)),
      ];
    default:
      return <String?>[null, null];
  }
}

class StatementPage extends StatefulWidget {
  final Store s;
  final int party;
  const StatementPage(this.s, this.party, {super.key});
  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  String mode = 'original';
  String quickRange = 'all';
  String? from, to;
  Set<String> kinds = {};
  int? passenger;
  bool includeDrafts = false, personal = false;
  Map<String, dynamic> options = {};
  @override
  void initState() {
    super.initState();
    final saved = widget.s.settings['statement_party_${widget.party}'];
    personal = saved is Map;
    options = Map<String, dynamic>.from(widget.s.settings);
    final templates = widget.s.settings['statementTemplates'] as Map?;
    final defaultTemplate =
        templates?[widget.s.settings['statementDefaultTemplate']];
    if (defaultTemplate is Map) {
      options.addAll(Map<String, dynamic>.from(defaultTemplate));
    }
    if (saved is Map) options.addAll(Map<String, dynamic>.from(saved));
    mode = options['statementMode'] ?? 'original';
  }

  Future<void> option(String key, dynamic value) async {
    options[key] = value;
    if (personal) {
      await widget.s.set('statement_party_${widget.party}', {
        for (final e in options.entries)
          if (e.key.startsWith('statement') &&
              !e.key.startsWith('statement_party_') &&
              e.key != 'statementTemplates')
            e.key: e.value,
      });
    } else {
      await widget.s.set(key, value);
    }
    if (mounted) setState(() {});
  }

  Future<void> saveTemplate() async {
    final name = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const UiText('حفظ قالب الكشف'),
        content: textField(name, 'اسم القالب'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const UiText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const UiText('حفظ'),
          ),
        ],
      ),
    );
    if (yes == true && name.text.trim().isNotEmpty) {
      final templates = Map<String, dynamic>.from(
        widget.s.settings['statementTemplates'] ?? {},
      );
      templates[name.text.trim()] = {
        for (final e in options.entries)
          if (e.key.startsWith('statement') &&
              !e.key.startsWith('statement_party_') &&
              e.key != 'statementTemplates')
            e.key: e.value,
      };
      await widget.s.set('statementTemplates', templates);
      if (mounted) setState(() {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
  }

  void applyQuickRange(String key) {
    final values = quickDateRange(key);
    setState(() {
      quickRange = key;
      from = values[0];
      to = values[1];
    });
  }

  final rate = TextEditingController(text: '150000'),
      fee = TextEditingController();
  @override
  void dispose() {
    rate.dispose();
    fee.dispose();
    super.dispose();
  }

  Future<void> preview() async {
    try {
      if (from != null && to != null && from!.compareTo(to!) > 0) {
        throw const FormatException('بداية الفترة بعد نهايتها');
      }
      final target = mode.startsWith('all')
          ? Currency.values.byName(mode.substring(3))
          : null;
      final exchange = target == null ? 0 : decimalUnits(rate.text, 0),
          permille = target == null ? 0 : decimalUnits(fee.text, 2);
      if (target != null && exchange <= 0) {
        throw const FormatException('أدخل سعر الصرف');
      }
      options['statementMode'] = mode;
      if (personal) await option('statementMode', mode);
      final allHistory = includeDrafts
          ? widget.s.entries
                .where(
                  (e) =>
                      e.data['customer'] == widget.party ||
                      e.data['supplier'] == widget.party,
                )
                .toList()
          : widget.s.history(widget.party);
      allHistory.sort(
        (a, b) => a.date == b.date
            ? a.id!.compareTo(b.id!)
            : a.date.compareTo(b.date),
      );
      final history = allHistory
          .where(
            (e) =>
                (kinds.isEmpty || kinds.contains(e.kind)) &&
                (passenger == null || e.passengers.contains(passenger)),
          )
          .where(
            (e) =>
                mode == 'original' || target != null || e.currency.name == mode,
          )
          .toList();
      final openings = <Currency, int>{for (final c in Currency.values) c: 0};
      final totals = <Currency, int>{for (final c in Currency.values) c: 0};
      for (final e in history) {
        if (from != null && e.date.compareTo(from!) < 0) {
          openings[e.currency] =
              openings[e.currency]! + widget.s.movement(e, widget.party);
        }
      }
      totals.addAll(openings);
      final columns = options['statementDetailLayout'] == 'columns'
          ? orderedStatementDetails(options)
                .where(
                  (key) =>
                      showStatementDetail(options, key) &&
                      history.any(
                        (e) => statementDetailValues(
                          widget.s,
                          e,
                          options,
                        ).containsKey(key),
                      ),
                )
                .toList()
          : <String>[];
      final rows = <List<String>>[];
      String render(Map<Currency, int> amounts) {
        if (target != null) {
          final value = amounts.entries.fold<int>(
            0,
            (sum, p) => sum + displayConvert(p.value, p.key, target, exchange),
          );
          return target.format(value);
        }
        return amounts.entries
            .where((p) => mode == 'original' || p.key.name == mode)
            .map((p) => p.key.format(p.value))
            .join('  |  ');
      }

      if (options['statementShowPrevious'] != false) {
        rows.add([
          '—',
          'رصيد سابق للفترة',
          render(openings),
          render(totals),
          ...columns.map((_) => ''),
        ]);
      }
      for (final e in history.where(
        (e) =>
            (from == null || e.date.compareTo(from!) >= 0) &&
            (to == null || e.date.compareTo(to!) <= 0),
      )) {
        final move = widget.s.movement(e, widget.party);
        totals[e.currency] = totals[e.currency]! + move;
        final detail = statementDescription(
          widget.s,
          e,
          options,
          details: options['statementDetailLayout'] != 'columns',
        );
        rows.add([
          displayDate(e.date, weekday: false),
          detail,
          target == null
              ? e.currency.format(move)
              : target.format(
                  displayConvert(move, e.currency, target, exchange),
                ),
          render(totals),
          ...columns.map(
            (key) => statementDetailValues(widget.s, e, options)[key] ?? '',
          ),
        ]);
      }
      final summary = <String>[
        if (options['statementShowFinal'] != false)
          'الرصيد النهائي: ${render(totals)}',
      ];
      if (permille != 0) {
        if (target != null) {
          final total = totals.entries.fold<int>(
            0,
            (sum, p) => sum + displayConvert(p.value, p.key, target, exchange),
          );
          final charge = roundedRatio(total * permille, 100000);
          if (options['statementShowFee'] != false) {
            summary.add('عمولة التحويل ${fee.text}‰: ${target.format(charge)}');
          }
          if (options['statementShowFinal'] != false) {
            summary.add('الإجمالي للعرض: ${target.format(total + charge)}');
          }
        } else {
          final fees = {
            for (final p in totals.entries)
              p.key: roundedRatio(p.value * permille, 100000),
          };
          if (options['statementShowFee'] != false) {
            summary.add('عمولة التحويل ${fee.text}‰: ${render(fees)}');
          }
          if (options['statementShowFinal'] != false) {
            summary.add(
              'الإجمالي للعرض: ${render({for (final p in totals.entries) p.key: p.value + fees[p.key]!})}',
            );
          }
        }
      }
      final foot = [
        if (target != null && options['statementShowExchange'] != false)
          'تحويل العرض: 100 USD = ${Currency.IQD.format(exchange)}',
        if ((target != null || permille != 0) &&
            options['statementShowExchange'] != false)
          'التحويل وعمولته للعرض فقط؛ الأرصدة الأصلية محفوظة.',
        if (kinds.isNotEmpty || passenger != null)
          'كشف مصفّى؛ الرصيد يخص العمليات المعروضة فقط.',
        if (options['statementShowPeriod'] != false)
          'الفترة: ${from == null ? 'من البداية' : displayDate(from, weekday: false)} — '
              '${to == null ? 'كامل السجل' : displayDate(to, weekday: false)}',
      ];
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPage(
              widget.s,
              'كشف حساب ${widget.s.name(widget.party)}',
              [
                if (options['statementShowDate'] != false) 'التاريخ',
                'العملية',
                'الحركة',
                if (options['statementShowBalance'] != false) 'الرصيد',
                ...columns.map(
                  (key) => uiLabel(statementDetails[key]!, options),
                ),
              ],
              rows
                  .map(
                    (r) => [
                      if (options['statementShowDate'] != false) r[0],
                      r[1],
                      r[2],
                      if (options['statementShowBalance'] != false) r[3],
                      ...r.skip(4),
                    ],
                  )
                  .toList(),
              [...summary, ...foot],
              preferences: options,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) message(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: const ClayAppBar(title: UiText('إعداد كشف الحساب')),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Section(widget.s.name(widget.party), [
          ChoiceField<String>(
            initialValue: mode,
            decoration: const InputDecoration(
              labelText: 'عرض العملة',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'original',
                child: UiText('كل عملة بقيمتها الأصلية'),
              ),
              DropdownMenuItem(value: 'USD', child: UiText('USD فقط')),
              DropdownMenuItem(value: 'IQD', child: UiText('IQD فقط')),
              DropdownMenuItem(
                value: 'allUSD',
                child: UiText('عرض الكل بالدولار'),
              ),
              DropdownMenuItem(
                value: 'allIQD',
                child: UiText('عرض الكل بالدينار'),
              ),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          if (mode.startsWith('all'))
            pair(
              textField(rate, '100 USD = دينار', number: true, grouped: true),
              textField(fee, 'عمولة التحويل ‰', number: true),
            ),
          SwitchListTile(
            title: const UiText('إعدادات خاصة بهذا الحساب'),
            subtitle: const UiText('تُحفظ الأعمدة والتنسيق لهذا الحساب'),
            value: personal,
            onChanged: (v) async {
              personal = v;
              if (!v) {
                await widget.s.set('statement_party_${widget.party}', null);
                options = Map<String, dynamic>.from(widget.s.settings);
                final defaults =
                    (widget.s.settings['statementTemplates'] as Map?)?[widget
                        .s
                        .settings['statementDefaultTemplate']];
                if (defaults is Map) {
                  options.addAll(Map<String, dynamic>.from(defaults));
                }
                mode = options['statementMode'] ?? 'original';
              } else {
                await option('statementMode', mode);
              }
              if (mounted) setState(() {});
            },
          ),
          ChoiceField<String>(
            initialValue: options['statementPreset'] ?? 'detailed',
            decoration: const InputDecoration(labelText: 'نمط الكشف'),
            items: const [
              DropdownMenuItem(value: 'brief', child: UiText('مختصر')),
              DropdownMenuItem(value: 'detailed', child: UiText('مفصّل')),
            ],
            onChanged: (v) async {
              await option('statementPreset', v);
              for (final key in statementDetails.keys) {
                await option('statementDetail_$key', v != 'brief');
              }
            },
          ),
        ]),
        Section(
          'الفترة والفلاتر',
          [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  const {
                        'all': 'من البداية',
                        'today': 'اليوم',
                        'week': 'هذا الأسبوع',
                        'month': 'هذا الشهر',
                        'previous': 'الشهر السابق',
                        'year': 'هذه السنة',
                      }.entries
                      .map(
                        (e) => ChoiceChip(
                          label: UiText(e.value),
                          selected: quickRange == e.key,
                          onSelected: (_) => applyQuickRange(e.key),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            TravelRangeField(
              start: from,
              end: to,
              label: 'فترة الكشف',
              onChanged: (r) => setState(() {
                from = r.start;
                to = r.end;
                quickRange = 'custom';
              }),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: types.entries
                  .where((e) => e.key != 'change')
                  .map(
                    (e) => FilterChip(
                      label: UiText(e.value),
                      selected: kinds.contains(e.key),
                      onSelected: (v) => setState(
                        () => v ? kinds.add(e.key) : kinds.remove(e.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ChoiceField<int>(
              initialValue: passenger,
              decoration: const InputDecoration(labelText: 'المسافر'),
              onClear: () => setState(() => passenger = null),
              items: widget.s
                  .list('passenger')
                  .where(
                    (p) => widget.s
                        .history(widget.party)
                        .any((e) => e.passengers.contains(p['id'])),
                  )
                  .map(
                    (p) => DropdownMenuItem<int>(
                      value: p['id'],
                      child: UiText(p['name']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => passenger = v),
            ),
            SwitchListTile(
              title: const UiText('تضمين المسودات للعرض فقط'),
              value: includeDrafts,
              onChanged: (v) => setState(() => includeDrafts = v),
            ),
          ],
          collapsible: true,
          subtitle: from == null && to == null
              ? 'كامل الحساب'
              : '${from ?? 'من البداية'} ← ${to ?? 'إلى اليوم'}',
        ),
        Section('تفاصيل وأعمدة الكشف', [
          ChoiceField<String>(
            initialValue: options['statementDetailLayout'] ?? 'inline',
            decoration: const InputDecoration(labelText: 'طريقة عرض التفاصيل'),
            items: const [
              DropdownMenuItem(
                value: 'inline',
                child: UiText('تفاصيل تحت اسم العملية'),
              ),
              DropdownMenuItem(value: 'columns', child: UiText('أعمدة مستقلة')),
            ],
            onChanged: (v) => option('statementDetailLayout', v),
          ),
          ...statementOptions.entries.map(
            (e) => SwitchListTile(
              title: UiText(e.value),
              value: e.key == 'statementShowNotes'
                  ? options[e.key] == true
                  : options[e.key] != false,
              onChanged: (v) => option(e.key, v),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (a, b) {
              final order = orderedStatementDetails(options);
              if (b > a) b--;
              order.insert(b, order.removeAt(a));
              option('statementDetailOrder', order);
            },
            children: [
              for (final key in orderedStatementDetails(options))
                SwitchListTile(
                  key: ValueKey(key),
                  secondary: const Icon(Icons.drag_handle),
                  title: UiText(statementDetails[key]!),
                  value: showStatementDetail(options, key),
                  onChanged: (v) => option('statementDetail_$key', v),
                ),
            ],
          ),
        ], collapsible: true),
        Section('تنسيق الكشف', [
          ChoiceField<String>(
            initialValue: options['statementFont'] ?? 'naskh',
            decoration: const InputDecoration(labelText: 'الخط العربي'),
            items: const [
              DropdownMenuItem(value: 'naskh', child: UiText('نسخ عربي واضح')),
              DropdownMenuItem(value: 'sans', child: UiText('عربي حديث')),
              DropdownMenuItem(value: 'cairo', child: UiText('Cairo')),
            ],
            onChanged: (v) => option('statementFont', v),
          ),
          const UiText('حجم الخط'),
          Slider(
            min: 9,
            max: 16,
            divisions: 7,
            value: (options['statementFontSize'] as num? ?? 12)
                .toDouble()
                .clamp(9, 16),
            onChanged: (v) => option('statementFontSize', v),
          ),
          const UiText('تباعد السطور'),
          Slider(
            min: 1,
            max: 1.7,
            divisions: 7,
            value: (options['statementLineSpacing'] as num? ?? 1.25)
                .toDouble()
                .clamp(1, 1.7),
            onChanged: (v) => option('statementLineSpacing', v),
          ),
          ChoiceField<String>(
            initialValue: options['statementPaper'] ?? 'a4',
            decoration: const InputDecoration(labelText: 'حجم الصفحة'),
            items: const [
              DropdownMenuItem(value: 'a4', child: UiText('A4')),
              DropdownMenuItem(value: 'a5', child: UiText('A5')),
              DropdownMenuItem(value: 'letter', child: UiText('Letter')),
            ],
            onChanged: (v) => option('statementPaper', v),
          ),
          SwitchListTile(
            title: const UiText('اتجاه أفقي'),
            value: options['statementLandscape'] == true,
            onChanged: (v) => option('statementLandscape', v),
          ),
          SwitchListTile(
            title: const UiText('الحركة بعمودي عليه / له'),
            value: options['statementSplitMovement'] == true,
            onChanged: (v) => option('statementSplitMovement', v),
          ),
        ], collapsible: true),
        Section('قوالب الكشف', [
          ...Map<String, dynamic>.from(
            widget.s.settings['statementTemplates'] ?? {},
          ).entries.map(
            (e) => ListTile(
              leading: const Icon(Icons.style_outlined),
              title: UiText(e.key),
              onTap: () async {
                options.addAll(Map<String, dynamic>.from(e.value));
                if (mounted) setState(() {});
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'القالب الافتراضي',
                    icon: Icon(
                      widget.s.settings['statementDefaultTemplate'] == e.key
                          ? Icons.star
                          : Icons.star_border,
                    ),
                    onPressed: () async {
                      await widget.s.set(
                        'statementDefaultTemplate',
                        widget.s.settings['statementDefaultTemplate'] == e.key
                            ? null
                            : e.key,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف القالب',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final templates = Map<String, dynamic>.from(
                        widget.s.settings['statementTemplates'] ?? {},
                      )..remove(e.key);
                      await widget.s.set('statementTemplates', templates);
                      if (widget.s.settings['statementDefaultTemplate'] ==
                          e.key) {
                        await widget.s.set('statementDefaultTemplate', null);
                      }
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: saveTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const UiText('حفظ الإعدادات كقالب'),
          ),
        ], collapsible: true),
        const Padding(
          padding: EdgeInsets.all(8),
          child: UiText(
            'كشف الزبون لا يتضمن التكلفة أو الربح أو العمولة الداخلية.',
          ),
        ),
        FilledButton.icon(
          onPressed: preview,
          icon: const Icon(Icons.preview_outlined),
          label: const UiText('معاينة الكشف'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const SavedStatementsPage()),
          ),
          icon: const Icon(Icons.photo_library_outlined),
          label: const UiText('الكشوف المحفوظة كصور'),
        ),
      ],
    ),
  );
}

class PdfPage extends StatelessWidget {
  final Store s;
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> summary;
  final Map<String, dynamic>? preferences;
  Map<String, dynamic> get config => preferences ?? s.settings;
  const PdfPage(
    this.s,
    this.title,
    this.headers,
    this.rows,
    this.summary, {
    super.key,
    this.preferences,
  });
  Future<Uint8List> document(PdfPageFormat format) async {
    final family = config['statementFont'] == 'sans'
        ? 'NotoSansArabic'
        : 'NotoNaskhArabic';
    final font = pw.Font.ttf(
      await rootBundle.load(
        config['statementFont'] == 'cairo'
            ? 'assets/fonts/Cairo.ttf'
            : 'assets/fonts/$family-Regular.ttf',
      ),
    );
    final bold = config['statementFont'] == 'cairo'
        ? font
        : pw.Font.ttf(await rootBundle.load('assets/fonts/$family-Bold.ttf'));
    final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo.ttf'));
    final fontSize = (config['statementFontSize'] as num? ?? 12)
        .toDouble()
        .clamp(9, 16)
        .toDouble();
    final lineSpacing = (config['statementLineSpacing'] as num? ?? 1.25)
        .toDouble()
        .clamp(0, 3)
        .toDouble();
    format = config['statementPaper'] == 'a5'
        ? PdfPageFormat.a5
        : config['statementPaper'] == 'letter'
        ? PdfPageFormat.letter
        : format;
    if (config['statementLandscape'] == true && format.height > format.width) {
      format = format.landscape;
    }
    pw.Widget cell(String text, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        uiLabel(text, config),
        textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(text)
            ? pw.TextDirection.rtl
            : pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: header ? bold : font,
          fontFallback: [latin],
          fontSize: header ? fontSize : fontSize,
          lineSpacing: lineSpacing,
          color: header ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
    final split =
        config['statementSplitMovement'] == true && headers.contains('الحركة');
    final movementIndex = headers.indexOf('الحركة');
    final finalHeaders = [
      for (var i = 0; i < headers.length; i++)
        if (split && i == movementIndex) ...['عليه', 'له'] else headers[i],
    ];
    final finalRows = rows
        .map(
          (r) => [
            for (var i = 0; i < r.length; i++)
              if (split && i == movementIndex) ...[
                r[i].contains('-') ? '—' : r[i],
                r[i].contains('-') ? r[i].replaceFirst('-', '') : '—',
              ] else
                r[i],
          ],
        )
        .toList();
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      if (config['logo'] != null && config['showLogo'] != false) {
        logo = pw.MemoryImage(await File(config['logo']).readAsBytes());
      }
    } catch (_) {
      /* A missing logo must never prevent a statement. */
    }
    final logoWidth = switch (config['logoSize']) {
      'small' => 42.0,
      'large' => 90.0,
      _ => 60.0,
    };
    final logoAlignment = switch (config['logoAlign']) {
      'left' => pw.Alignment.centerLeft,
      'center' => pw.Alignment.center,
      _ => pw.Alignment.centerRight,
    };
    doc.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageTheme: pw.PageTheme(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: bold,
            fontFallback: [latin],
          ),
          textDirection: pw.TextDirection.rtl,
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logo != null) ...[
              pw.Align(
                alignment: logoAlignment,
                child: pw.Image(
                  logo,
                  width: logoWidth,
                  height: logoWidth * .82,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 8),
            ],
            if (config['statementShowOffice'] != false)
              pw.Text(
                config['office'] ?? 'Eslam Holiday',
                textDirection:
                    RegExp(
                      r'[\u0600-\u06ff]',
                    ).hasMatch(config['office'] ?? 'Eslam Holiday')
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
                style: pw.TextStyle(
                  fontSize: 20,
                  color: PdfColor.fromInt(activePack.secondary.toARGB32()),
                ),
              ),
            pw.Text(
              [
                if (config['statementShowPhone'] != false)
                  config['phone'] ?? '07713414312',
                if (config['statementShowWebsite'] != false)
                  config['website'] ?? 'Eslamholiday.com',
              ].join('  •  '),
              textDirection: pw.TextDirection.ltr,
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (config['statementShowTransferAccount'] != false &&
                (config['transferAccount'] ?? '9645239113')
                    .toString()
                    .trim()
                    .isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'للتحويل الإلكتروني رقم حساب: ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      config['transferAccount'] ?? '9645239113',
                      textDirection: pw.TextDirection.ltr,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            pw.SizedBox(height: 12),
            pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
            pw.Divider(color: PdfColor.fromInt(activePack.primary.toARGB32())),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (config['statementShowFooter'] != false)
              pw.Text(
                config['footer'] ?? 'جميع الحقوق محفوظة 2026',
                style: const pw.TextStyle(fontSize: 8),
              ),
            if (config['statementShowPage'] != false)
              pw.Text(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                textDirection: pw.TextDirection.ltr,
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ),
        build: (_) => [
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xffb6c6d8),
              width: .45,
            ),
            columnWidths: {
              for (var i = 0; i < finalHeaders.length; i++)
                i: pw.FlexColumnWidth(
                  finalHeaders.reversed.toList()[i] == 'العملية'
                      ? 4
                      : finalHeaders.reversed.toList()[i] == 'التاريخ'
                      ? 1.6
                      : 2.1,
                ),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(activePack.primary.toARGB32()),
                ),
                children: finalHeaders.reversed
                    .map((v) => cell(v, header: true))
                    .toList(),
              ),
              for (var i = 0; i < finalRows.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isOdd
                        ? PdfColor.fromInt(0xfff1f6ff)
                        : PdfColors.white,
                  ),
                  children: finalRows[i].reversed.map(cell).toList(),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          ...summary.map(
            (text) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(activePack.canvas.toARGB32()),
                ),
                child: pw.Text(
                  uiLabel(text, config),
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontFallback: [latin],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> saveImages(BuildContext context, {required bool gallery}) async {
    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, count, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                UiText('حفظ صفحات الكشف… $count'),
              ],
            ),
          ),
        ),
      ),
    );
    var count = 0;
    try {
      final bytes = await document(PdfPageFormat.a4);
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/saved_statements');
      await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final filename = Gallery.safeName('$title-${day(DateTime.now())}-$stamp');
      await for (final page in Printing.raster(
        bytes,
        dpi: statementImageDpi(config['imageDpi']).toDouble(),
      )) {
        final png = await whiteStatementPng(await page.toPng());
        final name = '${filename}_p${count + 1}.png';
        await File('${dir.path}/$name').writeAsBytes(png, flush: true);
        if (gallery &&
            !await Gallery.save(
              png,
              name,
              album: config['galleryAlbum'] ?? 'Eslam Money',
            )) {
          break;
        }
        count++;
        progress.value = count;
      }
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      // The dialog owns the listener until its closing animation finishes.
      Future.delayed(const Duration(seconds: 1), progress.dispose);
    }
    if (context.mounted) {
      message(
        context,
        count == 0
            ? 'لم يتم الحفظ في المعرض'
            : gallery
            ? 'تم حفظ $count صفحة في معرض الهاتف وداخل التطبيق'
            : 'تم حفظ $count صفحة داخل التطبيق',
      );
    }
  }

  Future<void> shareImages(BuildContext context) async {
    final images = <Uint8List>[];
    final bytes = await document(PdfPageFormat.a4);
    await for (final page in Printing.raster(bytes, dpi: 36)) {
      images.add(await page.toPng());
    }
    if (!context.mounted || images.isEmpty) return;
    final selected = <int>{for (var i = 0; i < images.length; i++) i};
    if (images.length > 1) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: const UiText('مشاركة صفحات الكشف كصور'),
            content: SizedBox(
              width: 340,
              height: 360,
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const UiText('جميع الصفحات'),
                    value: selected.length == images.length,
                    onChanged: (v) => set(() {
                      selected.clear();
                      if (v == true) {
                        selected.addAll(List.generate(images.length, (i) => i));
                      }
                    }),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, i) => CheckboxListTile(
                        secondary: Image.memory(
                          images[i],
                          width: 42,
                          cacheWidth: 100,
                        ),
                        title: UiText('الصفحة ${i + 1}'),
                        value: selected.contains(i),
                        onChanged: (v) => set(
                          () =>
                              v == true ? selected.add(i) : selected.remove(i),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const UiText('إلغاء'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const UiText('مشاركة الصور'),
              ),
            ],
          ),
        ),
      );
      if (yes != true) return;
    }
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/statement_share');
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final paths = <String>[];
    final pages = selected.toList()..sort();
    var index = 0;
    await for (final page in Printing.raster(
      bytes,
      pages: pages,
      dpi: statementImageDpi(config['imageDpi']).toDouble(),
    )) {
      final file = File(
        '${dir.path}/statement-$stamp-p${pages[index++] + 1}.png',
      );
      await file.writeAsBytes(
        await whiteStatementPng(await page.toPng()),
        flush: true,
      );
      paths.add(file.path);
    }
    await Gallery.shareImages(paths);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: ClayAppBar(
      title: const UiText('معاينة الكشف'),
      actions: [
        IconButton(
          tooltip: 'حفظ كصورة داخل التطبيق',
          icon: const Icon(Icons.image_outlined),
          onPressed: () => guarded(
            c,
            () => saveImages(c, gallery: config['autoGallery'] == true),
          ),
        ),
        IconButton(
          tooltip: 'حفظ PDF',
          icon: const Icon(Icons.save_alt),
          onPressed: () => guarded(c, () async {
            final bytes = await document(PdfPageFormat.a4);
            await FilePicker.platform.saveFile(
              dialogTitle: 'حفظ كشف الحساب',
              fileName: 'Eslam-Money-${day(DateTime.now())}.pdf',
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              bytes: bytes,
            );
          }),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => guarded(c, () async {
                      await Printing.layoutPdf(
                        onLayout: document,
                        name: Gallery.safeName('$title.pdf'),
                      );
                    }),
                    icon: const Icon(Icons.print_outlined),
                    label: const UiText('طباعة PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => guarded(c, () async {
                      await Printing.sharePdf(
                        bytes: await document(PdfPageFormat.a4),
                        filename: Gallery.safeName('$title.pdf'),
                      );
                    }),
                    icon: const Icon(Icons.share_outlined),
                    label: const UiText('مشاركة PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        guarded(c, () => saveImages(c, gallery: true)),
                    icon: const Icon(Icons.download_outlined),
                    label: const UiText('حفظ الصورة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => guarded(c, () => shareImages(c)),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const UiText('مشاركة الصورة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    body: PdfPreview(
      allowPrinting: false,
      allowSharing: false,
      build: document,
      initialPageFormat: PdfPageFormat.a4,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      pdfFileName: 'Eslam-Money-statement.pdf',
    ),
  );
}

class SavedStatementsPage extends StatefulWidget {
  const SavedStatementsPage({super.key});
  @override
  State<SavedStatementsPage> createState() => _SavedStatementsPageState();
}

class _SavedStatementsPageState extends State<SavedStatementsPage> {
  Future<List<File>> files() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/saved_statements');
    if (!await dir.exists()) return <File>[];
    final rows = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.png'))
        .cast<File>()
        .toList();
    rows.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClayAppBar(title: const UiText('الكشوف المحفوظة')),
    body: FutureBuilder<List<File>>(
      future: files(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <File>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rows.isEmpty) {
          return const Center(
            child: EmptyState(
              'لا توجد كشوف محفوظة',
              'استخدم خيار حفظ كصورة من معاينة الكشف.',
              icon: Icons.photo_library_outlined,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final file = rows[i];
            return Card(
              child: ListTile(
                leading: Image.file(
                  file,
                  width: 50,
                  height: 60,
                  fit: BoxFit.contain,
                ),
                title: UiText('صورة كشف ${i + 1}'),
                subtitle: UiText(p.basename(file.path)),
                onTap: () => openAttachment(context, file.path),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'حفظ في معرض الهاتف',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => guarded(context, () async {
                        final saved = await Gallery.save(
                          await file.readAsBytes(),
                          p.basename(file.path),
                        );
                        if (saved && context.mounted) {
                          message(context, 'تم حفظ الصورة في معرض الهاتف');
                        }
                      }),
                    ),
                    IconButton(
                      tooltip: 'حذف الصورة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await file.delete();
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class ReportsPage extends StatefulWidget {
  final Store s;
  const ReportsPage(this.s, {super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Currency currency = Currency.USD;
  String quickRange = 'all';
  String? from, to, kind;
  int? customer, supplier;

  void applyQuickRange(String key) {
    final values = quickDateRange(key);
    setState(() {
      quickRange = key;
      from = values[0];
      to = values[1];
    });
  }

  @override
  Widget build(BuildContext c) {
    final rows = widget.s.entries
        .where(
          (e) =>
              e.posted &&
              e.currency == currency &&
              (from == null || e.date.compareTo(from!) >= 0) &&
              (to == null || e.date.compareTo(to!) <= 0) &&
              (kind == null || e.kind == kind) &&
              (customer == null || e.data['customer'] == customer) &&
              (supplier == null || e.data['supplier'] == supplier),
        )
        .toList();
    int sale = 0, cost = 0, expenses = 0, personal = 0, commission = 0;
    for (final e in rows) {
      if (['ticket', 'visa', 'hotel', 'refund'].contains(e.kind)) {
        final sign = e.kind == 'refund' ? -1 : 1;
        sale += e.sale * sign;
        cost += e.cost * sign;
        commission += (e.data['commission'] as int? ?? 0) * sign;
      }
      if (e.kind == 'expense') {
        if (e.data['personal'] == true) {
          personal += e.data['amount'] as int;
        } else {
          expenses += e.data['amount'] as int;
        }
      }
    }
    final summaries = [
      'البيع: ${currency.format(sale)}',
      'التكلفة: ${currency.format(cost)}',
      'ربح الخدمات: ${currency.format(sale - cost)}',
      'مصروف المكتب: ${currency.format(expenses)}',
      'صافي الربح: ${currency.format(sale - cost - expenses)}',
      'المصروف الشخصي: ${currency.format(personal)}',
    ];
    return Scaffold(
      appBar: ClayAppBar(
        title: const UiText('الأرباح والتقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => PdfPage(
                  widget.s,
                  'تقرير الأرباح الداخلي — ${currency.name}',
                  ['التاريخ', 'العملية', 'الزبون', 'البيع', 'التكلفة', 'الربح'],
                  rows
                      .where(
                        (e) => [
                          'ticket',
                          'visa',
                          'hotel',
                          'refund',
                        ].contains(e.kind),
                      )
                      .map(
                        (e) => [
                          displayDate(e.date, weekday: false),
                          '#${e.id} ${e.label}',
                          widget.s.name(e.data['customer']),
                          currency.format(
                            e.sale * (e.kind == 'refund' ? -1 : 1),
                          ),
                          currency.format(
                            e.cost * (e.kind == 'refund' ? -1 : 1),
                          ),
                          currency.format(
                            e.profit * (e.kind == 'refund' ? -1 : 1),
                          ),
                        ],
                      )
                      .toList(),
                  summaries,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Section('نتائج فعلية — ${currency.name}', [
            pair(
              AmountBox('المبيعات', currency.format(sale)),
              AmountBox('التكلفة', currency.format(cost)),
            ),
            pair(
              AmountBox('ربح الخدمات', currency.format(sale - cost)),
              AmountBox('مصروف المكتب', currency.format(expenses)),
            ),
            AmountBox(
              'صافي الربح',
              currency.format(sale - cost - expenses),
              color: sale - cost - expenses < 0
                  ? Colors.red
                  : const Color(0xff23836c),
            ),
            const SizedBox(height: 10),
            UiText(
              'عدد الحركات: ${rows.length} • المصروف الشخصي: ${currency.format(personal)}',
            ),
            UiText('العمولات المسجلة: ${currency.format(commission)}'),
          ]),
          Section('الفترة والفلاتر', [
            SegmentedButton<Currency>(
              segments: Currency.values
                  .map((v) => ButtonSegment(value: v, label: UiText(v.name)))
                  .toList(),
              selected: {currency},
              onSelectionChanged: (v) => setState(() => currency = v.first),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  const {
                        'all': 'الكل',
                        'today': 'اليوم',
                        'week': 'هذا الأسبوع',
                        'month': 'هذا الشهر',
                        'previous': 'الشهر السابق',
                        'year': 'هذه السنة',
                      }.entries
                      .map(
                        (item) => ChoiceChip(
                          label: UiText(item.value),
                          selected: quickRange == item.key,
                          onSelected: (_) => applyQuickRange(item.key),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            pair(
              DateField(
                'من تاريخ',
                from,
                (v) => setState(() {
                  from = v;
                  quickRange = 'custom';
                }),
              ),
              DateField(
                'إلى تاريخ',
                to,
                (v) => setState(() {
                  to = v;
                  quickRange = 'custom';
                }),
              ),
            ),
            PickField(
              'الزبون',
              customer,
              widget.s.list('customer'),
              (v) => setState(() => customer = v),
            ),
            PickField(
              'جهة الإصدار',
              supplier,
              widget.s.list('supplier'),
              (v) => setState(() => supplier = v),
            ),
            ChoiceField<String>(
              isExpanded: true,
              initialValue: kind ?? '',
              decoration: const InputDecoration(labelText: 'نوع العملية'),
              items: [
                const DropdownMenuItem(value: '', child: UiText('كل العمليات')),
                ...types.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: UiText(e.value)),
                ),
              ],
              onChanged: (v) => setState(() => kind = v == '' ? null : v),
            ),
          ], collapsible: true),
          Section(
            'مصادر الربح',
            rows
                .where(
                  (e) => ['ticket', 'hotel', 'visa', 'refund'].contains(e.kind),
                )
                .map(
                  (e) => ListTile(
                    title: UiText(
                      '#${e.id} ${e.label} • ${widget.s.name(e.data['customer'])}',
                    ),
                    subtitle: UiText(
                      '${displayDate(e.date)} • ${widget.s.name(e.data['supplier'])}',
                    ),
                    trailing: UiText(
                      currency.format(e.profit * (e.kind == 'refund' ? -1 : 1)),
                    ),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => EntryDetail(widget.s, e),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
