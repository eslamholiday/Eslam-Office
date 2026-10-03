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
      final history = widget.s
          .history(widget.party)
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

      if (widget.s.settings['statementShowPrevious'] != false) {
        rows.add(['—', 'رصيد سابق للفترة', render(openings), render(totals)]);
      }
      for (final e in history.where(
        (e) =>
            (from == null || e.date.compareTo(from!) >= 0) &&
            (to == null || e.date.compareTo(to!) <= 0),
      )) {
        final move = widget.s.movement(e, widget.party);
        totals[e.currency] = totals[e.currency]! + move;
        final detail = [
          e.label,
          if (widget.s.settings['statementShowNumber'] != false) '#${e.id}',
          if (widget.s.settings['statementShowQuantity'] != false &&
              ['ticket', 'visa', 'hotel'].contains(e.kind))
            'العدد: ${e.quantity}',
          if (widget.s.settings['statementShowPassengers'] != false &&
              e.passengers.isNotEmpty)
            e.passengers.map(widget.s.name).join('، '),
          if (widget.s.settings['statementShowPayment'] != false &&
              e.data['paymentMethod'] != null)
            paymentMethods[e.data['paymentMethod']] ?? '',
          if (widget.s.settings['statementShowNotes'] == true &&
              (e.data['notes'] ?? '').isNotEmpty)
            e.data['notes'],
          if (widget.s.settings['statementShowTravel'] != false) ...[
            if (e.data['hotelName'] != null && e.data['hotelName'] != '')
              e.data['hotelName'],
            if (e.data['from'] != null) widget.s.reference(e.data['from']),
            if (e.data['to'] != null) widget.s.reference(e.data['to']),
          ],
        ].join(' • ');
        rows.add([
          displayDate(e.date, weekday: false),
          detail,
          target == null
              ? e.currency.format(move)
              : target.format(
                  displayConvert(move, e.currency, target, exchange),
                ),
          render(totals),
        ]);
      }
      final summary = <String>[
        if (widget.s.settings['statementShowFinal'] != false)
          'الرصيد النهائي: ${render(totals)}',
      ];
      if (permille != 0) {
        if (target != null) {
          final total = totals.entries.fold<int>(
            0,
            (sum, p) => sum + displayConvert(p.value, p.key, target, exchange),
          );
          final charge = roundedRatio(total * permille, 100000);
          if (widget.s.settings['statementShowFee'] != false) {
            summary.add('عمولة التحويل ${fee.text}‰: ${target.format(charge)}');
          }
          if (widget.s.settings['statementShowFinal'] != false) {
            summary.add('الإجمالي للعرض: ${target.format(total + charge)}');
          }
        } else {
          final fees = {
            for (final p in totals.entries)
              p.key: roundedRatio(p.value * permille, 100000),
          };
          if (widget.s.settings['statementShowFee'] != false) {
            summary.add('عمولة التحويل ${fee.text}‰: ${render(fees)}');
          }
          if (widget.s.settings['statementShowFinal'] != false) {
            summary.add(
              'الإجمالي للعرض: ${render({for (final p in totals.entries) p.key: p.value + fees[p.key]!})}',
            );
          }
        }
      }
      final foot = [
        if (target != null &&
            widget.s.settings['statementShowExchange'] != false)
          'تحويل العرض: 100 USD = ${Currency.IQD.format(exchange)}',
        if ((target != null || permille != 0) &&
            widget.s.settings['statementShowExchange'] != false)
          'التحويل وعمولته للعرض فقط؛ الأرصدة الأصلية محفوظة.',
        if (widget.s.settings['statementShowPeriod'] != false)
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
                if (widget.s.settings['statementShowDate'] != false) 'التاريخ',
                'العملية',
                'الحركة',
                if (widget.s.settings['statementShowBalance'] != false)
                  'الرصيد',
              ],
              rows
                  .map(
                    (r) => [
                      if (widget.s.settings['statementShowDate'] != false) r[0],
                      r[1],
                      r[2],
                      if (widget.s.settings['statementShowBalance'] != false)
                        r[3],
                    ],
                  )
                  .toList(),
              [...summary, ...foot],
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
    appBar: AppBar(title: const Text('إعداد كشف الحساب')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Section(widget.s.name(widget.party), [
          ChoiceField<String>(
            isExpanded: true,
            initialValue: mode,
            decoration: const InputDecoration(labelText: 'عرض العملة'),
            items: const [
              DropdownMenuItem(
                value: 'original',
                child: Text('كل عملة بقيمتها الأصلية'),
              ),
              DropdownMenuItem(value: 'USD', child: Text('USD فقط')),
              DropdownMenuItem(value: 'IQD', child: Text('IQD فقط')),
              DropdownMenuItem(
                value: 'allUSD',
                child: Text('عرض الكل بالدولار'),
              ),
              DropdownMenuItem(
                value: 'allIQD',
                child: Text('عرض الكل بالدينار'),
              ),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 18),
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
                      (item) => ChoiceChip(
                        label: Text(item.value),
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
          if (mode.startsWith('all'))
            pair(
              textField(rate, '100 USD = دينار', number: true, grouped: true),
              textField(fee, 'عمولة التحويل ‰', number: true),
            ),
          ExpansionTile(
            title: const Text('تفاصيل وأعمدة الكشف'),
            children: [
              ...statementOptions.entries.map(
                (e) => SwitchListTile(
                  title: Text(e.value),
                  value: e.key == 'statementShowNotes'
                      ? widget.s.settings[e.key] == true
                      : widget.s.settings[e.key] != false,
                  onChanged: (v) async {
                    await widget.s.set(e.key, v);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Text(
            'كشف الحساب الخارجي لا يتضمن التكلفة أو الربح أو العمولة الداخلية.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: preview,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('معاينة الكشف'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const SavedStatementsPage()),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('الكشوف المحفوظة كصور'),
          ),
        ]),
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
  const PdfPage(
    this.s,
    this.title,
    this.headers,
    this.rows,
    this.summary, {
    super.key,
  });
  Future<Uint8List> document(PdfPageFormat format) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo.ttf'));
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      if (s.settings['logo'] != null && s.settings['showLogo'] != false) {
        logo = pw.MemoryImage(await File(s.settings['logo']).readAsBytes());
      }
    } catch (_) {
      /* A missing logo must never prevent a statement. */
    }
    final logoWidth = switch (s.settings['logoSize']) {
      'small' => 42.0,
      'large' => 90.0,
      _ => 60.0,
    };
    final logoAlignment = switch (s.settings['logoAlign']) {
      'left' => pw.Alignment.centerLeft,
      'center' => pw.Alignment.center,
      _ => pw.Alignment.centerRight,
    };
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        textDirection: pw.TextDirection.rtl,
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
            if (s.settings['statementShowOffice'] != false)
              pw.Text(
                s.settings['office'] ?? 'Eslam Holiday',
                style: pw.TextStyle(
                  fontSize: 20,
                  color: PdfColor.fromInt(0xff123b5d),
                ),
              ),
            pw.Text(
              [
                if (s.settings['statementShowPhone'] != false)
                  s.settings['phone'] ?? '07713414312',
                if (s.settings['statementShowWebsite'] != false)
                  s.settings['website'] ?? 'Eslamholiday.com',
              ].join('  •  '),
              textDirection: pw.TextDirection.ltr,
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (s.settings['statementShowTransferAccount'] != false &&
                (s.settings['transferAccount'] ?? '9645239113')
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
                      s.settings['transferAccount'] ?? '9645239113',
                      textDirection: pw.TextDirection.ltr,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            pw.SizedBox(height: 12),
            pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
            pw.Divider(color: PdfColor.fromInt(0xffd4a84f)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (s.settings['statementShowFooter'] != false)
              pw.Text(
                s.settings['footer'] ?? 'جميع الحقوق محفوظة 2026',
                style: const pw.TextStyle(fontSize: 8),
              ),
            if (s.settings['statementShowPage'] != false)
              pw.Text(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                textDirection: pw.TextDirection.ltr,
                style: const pw.TextStyle(fontSize: 8),
              ),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers.reversed.toList(),
            data: rows.map((r) => r.reversed.toList()).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: PdfColors.white,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xff123b5d),
            ),
            cellAlignment: pw.Alignment.centerRight,
            cellPadding: const pw.EdgeInsets.all(7),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xfff3f6f8),
            ),
          ),
          pw.SizedBox(height: 18),
          ...summary.map(
            (text) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xffeef3f8),
                ),
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
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
                Text('حفظ صفحات الكشف… $count'),
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
        dpi: (s.settings['imageDpi'] as num? ?? 180).toDouble(),
      )) {
        final png = await page.toPng();
        final name = '${filename}_p${count + 1}.png';
        await File('${dir.path}/$name').writeAsBytes(png, flush: true);
        if (gallery &&
            !await Gallery.save(
              png,
              name,
              album: s.settings['galleryAlbum'] ?? 'Eslam Money',
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

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('معاينة الكشف'),
      actions: [
        IconButton(
          tooltip: 'حفظ كصورة داخل التطبيق',
          icon: const Icon(Icons.image_outlined),
          onPressed: () => guarded(
            c,
            () => saveImages(c, gallery: s.settings['autoGallery'] == true),
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
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: () => guarded(c, () => saveImages(c, gallery: true)),
          icon: const Icon(Icons.download_outlined),
          label: const Text('حفظ صورة في معرض الهاتف'),
        ),
      ),
    ),
    body: PdfPreview(
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
    appBar: AppBar(title: const Text('الكشوف المحفوظة')),
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
                title: Text('صورة كشف ${i + 1}'),
                subtitle: Text(p.basename(file.path)),
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
      appBar: AppBar(
        title: const Text('الأرباح والتقارير'),
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
            Text(
              'عدد الحركات: ${rows.length} • المصروف الشخصي: ${currency.format(personal)}',
            ),
            Text('العمولات المسجلة: ${currency.format(commission)}'),
          ]),
          Section('الفترة والفلاتر', [
            SegmentedButton<Currency>(
              segments: Currency.values
                  .map((v) => ButtonSegment(value: v, label: Text(v.name)))
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
                          label: Text(item.value),
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
                const DropdownMenuItem(value: '', child: Text('كل العمليات')),
                ...types.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
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
                    title: Text(
                      '#${e.id} ${e.label} • ${widget.s.name(e.data['customer'])}',
                    ),
                    subtitle: Text(
                      '${displayDate(e.date)} • ${widget.s.name(e.data['supplier'])}',
                    ),
                    trailing: Text(
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
