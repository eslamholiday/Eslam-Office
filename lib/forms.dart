import 'labels.dart';
import 'dart:convert';
import 'dart:async';
import 'input_schema.dart';
import 'input_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'experience.dart';
import 'date_range_field.dart';
import 'entry_matching.dart';

Future<int?> editParty(
  BuildContext c,
  Store s,
  String kind, {
  Map<String, dynamic>? party,
}) => Navigator.push<int>(
  c,
  MaterialPageRoute(builder: (_) => PartyForm(s, kind, party: party)),
);

class PartyForm extends StatefulWidget {
  final Store s;
  final String kind;
  final Map<String, dynamic>? party;
  final bool preview;
  const PartyForm(
    this.s,
    this.kind, {
    super.key,
    this.party,
    this.preview = false,
  });
  @override
  State<PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<PartyForm> {
  late final name = TextEditingController(
    text:
        widget.party?['name'] ??
        (widget.s.settings['defaults_${widget.kind}'] as Map?)?['name'] ??
        '',
  );
  late final phone = TextEditingController(
    text:
        widget.party?['phone'] ??
        (widget.s.settings['defaults_${widget.kind}'] as Map?)?['phone'] ??
        '',
  );
  late final notes = TextEditingController(
    text:
        widget.party?['notes'] ??
        (widget.s.settings['defaults_${widget.kind}'] as Map?)?['notes'] ??
        '',
  );
  late final passport = TextEditingController(
    text:
        widget.party?['passport'] ??
        (widget.s.settings['defaults_${widget.kind}'] as Map?)?['passport'] ??
        '',
  );
  late int? customer =
      widget.party?['customer'] ??
      (widget.s.settings['defaults_${widget.kind}'] as Map?)?['customer'];
  late List<String> attachments = List<String>.from(
    widget.party?['attachments'] ?? [],
  );
  late String? profileImage = widget.party?['profileImage'];
  late String? avatar = widget.party?['avatar'];
  late String? travelerType =
      widget.party?['travelerType'] ??
      (widget.s.settings['defaults_${widget.kind}'] as Map?)?['travelerType'];
  bool busy = false;
  final Set<String> revealed = {};
  final Map<String, GlobalKey> anchors = {};
  void revealField(String key) {
    setState(() => revealed.add(key));
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final target = anchors[key]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: .15,
        );
      }
    });
  }

  InputLayout get layout => InputLayout(widget.s.settings, widget.kind);
  Future<void> pickContact() async {
    try {
      final contact = await const MethodChannel(
        'eslam_money/contacts',
      ).invokeMapMethod<String, dynamic>('pickPhone');
      if (!mounted || contact == null) {
        return;
      }
      setState(() {
        name.text = (contact['name'] ?? '').toString();
        phone.text = normalizePhone((contact['phone'] ?? '').toString());
      });
    } on PlatformException {
      if (mounted) {
        message(
          context,
          'تعذر فتح جهات الاتصال، يمكنك إدخال الاسم والرقم يدويًا',
        );
      }
    } on MissingPluginException {
      if (mounted) message(context, 'اختيار جهات الاتصال متاح على Android');
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    passport.dispose();
    super.dispose();
  }

  Widget partyInput(InputSpec f) => KeyedSubtree(
    key: anchors.putIfAbsent(f.key, GlobalKey.new),
    child: AbsorbPointer(
      absorbing: widget.preview,
      child: partyInputContent(f),
    ),
  );
  Widget partyInputContent(InputSpec f) {
    final label = layout.label(f);
    return switch (f.key) {
      'name' => textField(name, label),
      'phone' => textField(phone, label, number: true),
      'passport' => textField(passport, label),
      'travelerType' => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ChoiceField<String>(
          fieldKey: 'travelerType',
          initialValue: travelerType,
          onClear: travelerType == null
              ? null
              : () => setState(() => travelerType = null),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(fieldIcon(label)),
          ),
          items:
              inputChoices(
                    widget.s.settings,
                    widget.kind,
                    f,
                    current: travelerType,
                  ).entries
                  .map(
                    (e) =>
                        DropdownMenuItem(value: e.key, child: UiText(e.value)),
                  )
                  .toList(),
          onChanged: (v) => setState(() => travelerType = v),
        ),
      ),
      'customer' => PickField(
        label,
        customer,
        widget.s.list('customer'),
        (v) => setState(() => customer = v),
        store: widget.s,
        listKey: 'customer',
        add: widget.preview
            ? null
            : () => editParty(context, widget.s, 'customer'),
      ),
      'notes' => textField(notes, label, lines: 3),
      'profile' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(label),
          ProfilePicker(
            imagePath: profileImage,
            avatar: avatar,
            onChanged: (image, selectedAvatar) => setState(() {
              profileImage = image;
              avatar = selectedAvatar;
            }),
          ),
        ],
      ),
      'attachments' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(label),
          Attachments(attachments, (v) => setState(() => attachments = v)),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Map<String, dynamic> partyValues() => {
    ...?widget.party,
    'kind': widget.kind,
    'name': name.text.trim(),
    'phone': normalizePhone(phone.text),
    'notes': notes.text,
    'passport': passport.text,
    'customer': customer,
    'attachments': attachments,
    'profileImage': profileImage,
    'avatar': avatar,
    'travelerType': travelerType,
  };
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (c, _) => Scaffold(
      appBar: ClayAppBar(
        title: UiText(
          '${widget.preview
              ? 'معاينة'
              : widget.party?['id'] == null
              ? 'إضافة'
              : 'تعديل'} ${inputScopes[widget.kind]}',
        ),
        actions: [
          if (widget.s.settings['showInputSearch'] != false)
            InputSearch(layout: layout, onSelect: revealField),
          if (!widget.preview)
            IconButton(
              tooltip: 'تخصيص الإدخالات',
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => FormCustomizationPage(widget.s, widget.kind),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.preview)
              const ListTile(
                leading: Icon(Icons.preview_outlined),
                title: UiText('معاينة فقط — لن تُحفظ بيانات'),
              ),
            if (widget.kind == 'customer')
              OutlinedButton.icon(
                onPressed: pickContact,
                icon: const Icon(Icons.contacts_outlined),
                label: const UiText('من جهات الاتصال'),
              ),

            for (final group in layout.groups)
              if (layout.fields.any(
                (f) =>
                    f.group == group &&
                    (revealed.contains(f.key) || layout.mode(f) != 'hidden'),
              ))
                Section(
                  inputGroupLabels[group] ?? group,
                  [
                    for (final f in layout.fields.where(
                      (f) =>
                          f.group == group &&
                          (revealed.contains(f.key) ||
                              layout.mode(f) != 'hidden'),
                    ))
                      if (layout.mode(f) != 'details' ||
                          revealed.contains(f.key))
                        partyInput(f),
                    if (layout.fields.any(
                      (f) =>
                          f.group == group &&
                          layout.mode(f) == 'details' &&
                          !revealed.contains(f.key),
                    ))
                      ExpansionTile(
                        title: const UiText('تفاصيل إضافية'),
                        children: layout.fields
                            .where(
                              (f) =>
                                  f.group == group &&
                                  layout.mode(f) == 'details' &&
                                  !revealed.contains(f.key),
                            )
                            .map(partyInput)
                            .toList(),
                      ),
                  ],
                  key: ValueKey('$group-${revealed.join(',')}'),
                  collapsible: true,
                  initiallyExpanded:
                      layout.expanded(group) ||
                      layout.fields.any(
                        (f) => f.group == group && revealed.contains(f.key),
                      ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: widget.preview
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final values = partyValues();
                          final missing = layout.missing(values);
                          if (missing.isNotEmpty) {
                            setState(() => revealed.addAll(missing));
                            message(
                              c,
                              'أكمل: ${layout.fields.where((f) => missing.contains(f.key)).map(layout.label).join('، ')}',
                            );
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            if (values['name'] == '') {
                              values['name'] = 'بدون اسم';
                            }
                            final id = await widget.s.saveParty(
                              values,
                              id: widget.party?['id'],
                            );
                            unawaited(Experience.fire('save'));
                            if (c.mounted) Navigator.pop(c, id);
                          } catch (e) {
                            if (c.mounted) message(c, e);
                          } finally {
                            if (mounted) {
                              setState(() => busy = false);
                            }
                          }
                        },
                  child: UiText(busy ? 'جارٍ الحفظ…' : 'حفظ'),
                ),
              ),
            ),
    ),
  );
}

class EntryForm extends StatefulWidget {
  final Store s;
  final String kind;
  final Entry? draft;
  final int? party;
  final bool supplier;
  final bool preview;
  final bool resume;
  const EntryForm(
    this.s,
    this.kind, {
    super.key,
    this.draft,
    this.party,
    this.supplier = false,
    this.preview = false,
    this.resume = false,
  });
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final Map<String, TextEditingController> controllers = {};
  late Map<String, dynamic> d;
  bool busy = false;
  String? calcError;
  bool editingCustomExpenseSubcategory = false;
  String baseline = '';
  bool allowLeave = false;
  final Set<String> revealed = {};
  final Map<String, GlobalKey> anchors = {};
  void revealField(String key) {
    setState(() {
      revealed.add(key);
      if (key == 'return') revealed.add('depart');
      if (key == 'checkOut') revealed.add('checkIn');
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final target =
          anchors[key]?.currentContext ??
          anchors[key == 'return'
                  ? 'depart'
                  : key == 'checkOut'
                  ? 'checkIn'
                  : key]
              ?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: .15,
        );
      }
    });
  }

  Timer? recoveryTimer;
  InputLayout get layout => InputLayout(widget.s.settings, widget.kind);
  String get recoveryKey =>
      'recovery_${widget.kind}_${widget.draft?.id ?? 'new'}';
  bool get dirty {
    try {
      return baseline != jsonEncode(collect());
    } catch (_) {
      return true;
    }
  }

  Future<void> confirmLeave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const UiText('تعديلات غير محفوظة'),
        content: UiText(
          widget.draft?.posted == true
              ? 'حفظ التعديلات أو تجاهلها؟'
              : 'حفظ كمسودة أو تجاهل التعديلات؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const UiText('متابعة التعديل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const UiText('تجاهل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const UiText('حفظ'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'save') {
      await save(widget.draft?.posted == true);
    }
    if (action == 'discard') {
      recoveryTimer?.cancel();
      unawaited(widget.s.set(recoveryKey, null).catchError((Object _) {}));
      setState(() => allowLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Currency get currency => Currency.values.byName(d['currency']);
  TextEditingController tc(String key, [String value = '']) =>
      controllers.putIfAbsent(key, () => TextEditingController(text: value));
  @override
  void initState() {
    super.initState();
    d = {
      ...Map<String, dynamic>.from(
        widget.s.settings['defaults_${widget.kind}'] ?? {},
      ),
      'kind': widget.kind,
      'currency':
          (widget.s.settings['defaults_${widget.kind}'] as Map?)?['currency'] ??
          widget.s.settings['defaultCurrency'] ??
          'USD',
      'date': day(DateTime.now()),
      'rate': 0,
      'fee': 0,
      'commissionMode': 'percent',
      'qty': 1,
      'partyType': widget.supplier ? 'supplier' : 'customer',
      'direction': -1,
      'settlementMode': 'cash',
      'paymentMethod': 'cash',
      'ticketType': 'ticket',
      'tripType': 'oneWay',
      'personal': widget.kind == 'expense',
      'attachments': <String>[],
      ...Map<String, dynamic>.from(
        widget.s.settings['defaults_${widget.kind}'] ?? {},
      ),
      ...?(widget.draft?.data),
    };
    if (widget.party != null) {
      d[widget.supplier ? 'supplier' : 'customer'] = widget.party;
    }
    for (final key in [
      'notes',
      'hotelName',
      'meals',
      'visaType',
      'days',
      'entriesCount',
      'expenseSubcategory',
      'rooms',
      'people',
    ]) {
      tc(key, '${d[key] ?? ''}');
    }
    for (final key in ['sell', 'costUnit', 'amount', 'fee']) {
      tc(key, currency.editInput(d[key] as int? ?? 0));
    }
    tc(
      'rate',
      (d['rate'] as int? ?? 0) == 0
          ? ''
          : ((d['rate'] as int) / 100).toString(),
    );
    tc('qty', '${d['qty'] ?? 1}');
    final lines =
        d['lines'] as List? ??
        [
          for (var i = 0; i < 3; i++)
            {
              'qty': d['q$i'] ?? (i == 0 ? 1 : 0),
              'base': d['base$i'] ?? 0,
              'gross': d['gross$i'] ?? 0,
              'sell': d['sell$i'] ?? 0,
            },
        ];
    for (var i = 0; i < 3; i++) {
      final row = i < lines.length ? lines[i] : <String, dynamic>{};
      tc('q$i', (row['qty'] ?? 0) == 0 ? '' : '${row['qty']}');
      for (final key in ['base', 'gross', 'sell']) {
        tc('$key$i', currency.editInput(row[key] as int? ?? 0));
      }
    }
    if (widget.draft == null &&
        d['airline'] != null &&
        widget.s.settings['autoCommission'] != false) {
      applyRule();
    }
    baseline = jsonEncode(collect());
    if (!widget.preview) {
      if (!widget.resume) {
        WidgetsBinding.instance.addPostFrameCallback((_) => offerRecovery());
      }
      recoveryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted &&
            !busy &&
            !allowLeave &&
            dirty &&
            widget.s.settings['autoRecoverForms'] != false) {
          try {
            unawaited(
              widget.s.set(recoveryKey, collect()).catchError((Object _) {}),
            );
          } catch (_) {}
        }
      });
    }
    for (final controller in controllers.values) {
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    recoveryTimer?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> offerRecovery() async {
    final saved = widget.s.settings[recoveryKey];
    if (saved is! Map ||
        widget.s.settings['autoRecoverForms'] == false ||
        !mounted) {
      return;
    }
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const UiText('إدخال غير مكتمل'),
        content: const UiText(
          'توجد بيانات محفوظة تلقائيًا لهذا النموذج. تريد استعادتها؟ لم تُسجَّل كحركة مالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const UiText('تجاهل المحفوظ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const UiText('استعادة'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (restore == true) {
      setState(() {
        d = {...d, ...Map<String, dynamic>.from(saved)};
        for (final key in [
          'notes',
          'hotelName',
          'meals',
          'visaType',
          'days',
          'entriesCount',
          'expenseSubcategory',
          'rooms',
          'people',
        ]) {
          tc(key).text = '${d[key] ?? ''}';
        }
        for (final key in ['sell', 'costUnit', 'amount', 'fee']) {
          tc(key).text = currency.editInput(d[key] as int? ?? 0);
        }
        tc('rate').text = ((d['rate'] as int? ?? 0) / 100).toString();
        tc('qty').text = '${d['qty'] ?? 1}';
        final rows = d['lines'] as List? ?? [];
        for (var i = 0; i < 3; i++) {
          final row = i < rows.length ? rows[i] as Map : <String, dynamic>{};
          tc('q$i').text = '${row['qty'] ?? 0}';
          for (final key in ['base', 'gross', 'sell']) {
            tc('$key$i').text = currency.editInput(row[key] as int? ?? 0);
          }
        }
      });
    } else if (restore == false) {
      await widget.s.set(recoveryKey, null);
    }
  }

  void applyRule() {
    final r = widget.s.commission(d['airline'], d['supplier']);
    tc('rate').text = (r['rate'] as int? ?? 0) == 0
        ? ''
        : ((r['rate'] as int) / 100).toString();
    d['commissionMode'] = r['commissionMode'] ?? 'percent';
    tc('fee').text = currency.editInput(
      r['currency'] == null || r['currency'] == currency.name
          ? r['fee'] as int? ?? 0
          : 0,
    );
  }

  Map<String, dynamic> collect() {
    final v = Map<String, dynamic>.from(d);
    if (widget.kind == 'ticket') {
      v['tripType'] = v['return'] == null ? 'oneWay' : 'roundTrip';
    }
    for (final key in [
      'notes',
      'hotelName',
      'meals',
      'visaType',
      'days',
      'entriesCount',
      'expenseSubcategory',
      'rooms',
      'people',
    ]) {
      v[key] = tc(key).text.trim();
    }
    if (widget.kind == 'ticket') {
      v['rate'] = decimalUnits(tc('rate').text, 2);
      v['fee'] = money(tc('fee').text, currency);
      v['lines'] = [
        for (var i = 0; i < 3; i++)
          {
            'qty': decimalUnits(tc('q$i').text, 0),
            'base': money(tc('base$i').text, currency),
            'gross': money(tc('gross$i').text, currency),
            'sell': money(tc('sell$i').text, currency),
          },
      ];
    }
    if (['visa', 'hotel'].contains(widget.kind)) {
      v['qty'] = decimalUnits(tc('qty').text, 0);
      v['sell'] = money(tc('sell').text, currency);
      v['costUnit'] = money(tc('costUnit').text, currency);
    }
    if (['expense', 'funding', 'settlement', 'opening'].contains(widget.kind)) {
      v['amount'] = money(tc('amount').text, currency);
    }
    return v;
  }

  Future<void> save(bool post, {bool another = false}) async {
    if (busy || widget.preview) {
      return;
    }
    setState(() => busy = true);
    try {
      final v = collect();
      v['posted'] = post;
      if (post) {
        final missing = layout.missing(v);
        if (missing.isNotEmpty) {
          setState(() => revealed.addAll(missing));
          throw FormatException(
            'أكمل: ${layout.fields.where((f) => missing.contains(f.key)).map(layout.label).join('، ')}',
          );
        }
      }
      final duplicate = post && widget.s.settings['duplicateWarn'] != false
          ? possibleDuplicate(widget.s.entries, v, excludeId: widget.draft?.id)
          : null;
      if (post &&
          (widget.s.settings['confirmPost'] != false || duplicate != null)) {
        final totals = ['ticket', 'hotel', 'visa'].contains(widget.kind)
            ? calculate(v)
            : null;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: UiText(
              duplicate == null ? 'مراجعة قبل الاعتماد' : 'عملية مشابهة مسجلة',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (duplicate != null)
                    UiText(
                      'توجد عملية مشابهة #${duplicate.id}. يمكنك الرجوع أو الاعتماد إذا كان التكرار مقصودًا.',
                      style: const TextStyle(color: Colors.deepOrange),
                    ),
                  UiText('${Entry(v).label} • ${displayDate(v['date'])}'),
                  UiText('الزبون: ${widget.s.name(v['customer'])}'),
                  UiText('جهة الإصدار: ${widget.s.name(v['supplier'])}'),
                  if (totals != null) ...[
                    UiText('العدد: ${Entry(v).quantity}'),
                    UiText('البيع: ${currency.format(totals.sale)}'),
                    UiText('التسديد: ${currency.format(totals.cost)}'),
                    UiText('الربح: ${currency.format(totals.profit)}'),
                    if (totals.profit < 0)
                      const UiText(
                        'تنبيه: العملية بخسارة',
                        style: TextStyle(color: Colors.red),
                      ),
                  ] else
                    UiText('المبلغ: ${currency.format(v['amount'] ?? 0)}'),
                  UiText('التسديد: ${paymentLabel(v['paymentMethod'])}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const UiText('رجوع للتعديل'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const UiText('اعتماد'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
      }
      final savedId = await widget.s.saveEntry(v, id: widget.draft?.id);
      unawaited(Experience.fire('save'));
      recoveryTimer?.cancel();
      await widget.s.set(recoveryKey, null);
      if (mounted) {
        setState(() => allowLeave = true);
        message(context, 'تم حفظ ${Entry(v).label}');
        if (another ||
            (post &&
                widget.draft?.id == null &&
                widget.s.settings['afterSave'] == 'another')) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EntryForm(
                widget.s,
                widget.kind,
                party: d['customer'] ?? d['supplier'],
                supplier: d['customer'] == null && d['supplier'] != null,
              ),
            ),
          );
        } else if (post && widget.s.settings['afterSave'] == 'detail') {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EntryDetail(
                widget.s,
                widget.s.entries.firstWhere((e) => e.id == savedId),
              ),
            ),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    } catch (e) {
      unawaited(Experience.fire('error'));
      if (mounted) {
        if (e.toString().contains('حساب الزبون')) {
          setState(() => revealed.add('customer'));
        }
        if (e.toString().contains('عدد التذاكر')) {
          setState(() => revealed.addAll(['q0', 'base0', 'gross0', 'sell0']));
        }
        if (e.toString().contains('مبلغًا أكبر')) {
          setState(() => revealed.add('amount'));
        }
        if (e.toString().contains('اختر الحساب')) {
          setState(() => revealed.add('account'));
        }
        message(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget passengerPicker() {
    final typeLabels = {
      ...travelerTypes,
      ...Map<String, String>.from(
        (widget.s.settings['choices_travelerType'] as Map?)?['labels'] ?? {},
      ),
    };
    final ids = List<int>.from(
      d['passengers'] ?? (d['passenger'] == null ? [] : [d['passenger']]),
    );
    int quantity = 0;
    try {
      quantity = widget.kind == 'ticket'
          ? [
              0,
              1,
              2,
            ].fold<int>(0, (sum, i) => sum + decimalUnits(tc('q$i').text, 0))
          : widget.kind == 'visa'
          ? decimalUnits(tc('qty').text, 0)
          : 1;
    } catch (_) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiText('تم تحديد ${ids.length} من $quantity مسافر'),
        const SizedBox(height: 8),
        if (ids.isEmpty)
          const UiText('لم تحدد أسماء بعد؛ العدد المالي من خانات الخدمة.'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ids
              .map(
                (id) => InputChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: UiText(
                          widget.s.name(id),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (typeLabels.containsKey(
                        widget.s.parties
                            .where((r) => r['id'] == id)
                            .firstOrNull?['travelerType'],
                      ))
                        UiText(
                          ' · ${typeLabels[widget.s.parties.where((r) => r['id'] == id).firstOrNull?['travelerType']]}',
                        ),
                    ],
                  ),
                  onPressed: widget.preview
                      ? null
                      : () async {
                          final person = widget.s.parties
                              .where((r) => r['id'] == id)
                              .firstOrNull;
                          if (person != null) {
                            await editParty(
                              context,
                              widget.s,
                              'passenger',
                              party: person,
                            );
                          }
                          if (mounted) {
                            setState(() {});
                          }
                        },
                  onDeleted: () => setState(() {
                    ids.remove(id);
                    d['passengers'] = ids;
                    d['passenger'] = null;
                  }),
                ),
              )
              .toList(),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.people_outline),
              label: const UiText('اختيار المسافرين'),
              onPressed: widget.preview || d['customer'] == null
                  ? null
                  : () async {
                      final selected = ids.toSet();
                      var query = '';
                      final result = await showModalBottomSheet<List<int>>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, set) {
                            final rows = widget.s
                                .list('passenger')
                                .where(
                                  (r) =>
                                      (r['customer'] == d['customer'] ||
                                          r['customer'] == null) &&
                                      normalize(
                                        '${r['name']} ${r['passport'] ?? ''} ${r['phone'] ?? ''}',
                                      ).contains(query),
                                )
                                .toList();
                            return SafeArea(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                                ),
                                child: SizedBox(
                                  height: MediaQuery.sizeOf(ctx).height * .65,
                                  child: Column(
                                    children: [
                                      UiText(
                                        'مسافرو ${widget.s.name(d['customer'])}',
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            labelText: 'بحث بالاسم أو الجواز',
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                          onChanged: (v) =>
                                              set(() => query = normalize(v)),
                                        ),
                                      ),
                                      UiText('المحدد: ${selected.length}'),
                                      Expanded(
                                        child: rows.isEmpty
                                            ? const Center(
                                                child: UiText(
                                                  'لا توجد أسماء مطابقة',
                                                ),
                                              )
                                            : ListView.builder(
                                                itemCount: rows.length,
                                                itemBuilder: (ctx, i) {
                                                  final r = rows[i];
                                                  return CheckboxListTile(
                                                    title: UiText(
                                                      '${r['name']}',
                                                    ),
                                                    subtitle: UiText(
                                                      r['customer'] == null
                                                          ? 'غير مرتبط — سيُربط بهذا الزبون عند الحفظ'
                                                          : 'تابع إلى: ${widget.s.name(r['customer'])}',
                                                    ),
                                                    value: selected.contains(
                                                      r['id'],
                                                    ),
                                                    onChanged: (v) => set(() {
                                                      v == true
                                                          ? selected.add(
                                                              r['id'] as int,
                                                            )
                                                          : selected.remove(
                                                              r['id'],
                                                            );
                                                    }),
                                                  );
                                                },
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: FilledButton(
                                          onPressed: () => Navigator.pop(
                                            ctx,
                                            selected.toList(),
                                          ),
                                          child: const UiText('تم الاختيار'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          d['passengers'] = result;
                          d['passenger'] = null;
                        });
                      }
                    },
            ),
            TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const UiText('إضافة مسافر للزبون'),
              onPressed: d['customer'] == null
                  ? null
                  : () async {
                      final id = await editParty(
                        context,
                        widget.s,
                        'passenger',
                        party: {'customer': d['customer']},
                      );
                      if (id != null && mounted) {
                        setState(() {
                          d['passengers'] = {...ids, id}.toList();
                          d['passenger'] = null;
                        });
                      }
                    },
            ),
          ],
        ),
        if (d['customer'] == null)
          const UiText('اختر حساب الزبون أولًا لإضافة أسمائه.'),
      ],
    );
  }

  Widget field(
    String key,
    String label, {
    bool number = false,
    bool grouped = false,
  }) => textField(
    tc(key),
    label,
    number: number,
    grouped: grouped,
    onChanged: (_) => setState(() {}),
  );
  Widget pick(String key, String label, String kind, {bool party = false}) =>
      PickField(
        label,
        d[key],
        party
            ? widget.s.parties
                  .where(
                    (r) =>
                        r['kind'] == kind &&
                        (r['archived'] == 0 || r['id'] == d[key]),
                  )
                  .toList()
            : widget.s.refs
                  .where(
                    (r) =>
                        r['kind'] == kind &&
                        (r['archived'] == 0 || r['id'] == d[key]),
                  )
                  .toList(),
        (v) => setState(() {
          d[key] = v;
          if (key == 'expenseCategory') {
            tc('expenseSubcategory').clear();
            editingCustomExpenseSubcategory = false;
            final ref = widget.s.refs.where((r) => r['id'] == v).firstOrNull;
            if (ref?['personal'] == true) {
              d['personal'] = true;
            }
          }
          if (key == 'customer') {
            d['passengers'] = <int>[];
            d['passenger'] = null;
          }
          if (key == 'airline') {
            final ref = widget.s.refs.where((r) => r['id'] == v).firstOrNull;
            final hasPrices = controllers.entries.any(
              (p) =>
                  RegExp(r'^(base|gross|sell)[0-2]$').hasMatch(p.key) &&
                  (double.tryParse(
                            normalize(
                              p.value.text,
                            ).replaceAll(',', '').replaceAll('٬', ''),
                          ) ??
                          0) !=
                      0,
            );
            if (!hasPrices &&
                ref != null &&
                widget.s.settings['autoAirlineCurrency'] != false) {
              d['currency'] = ref['currency'] ?? d['currency'];
            }
          }
          if ((key == 'airline' || key == 'supplier') &&
              widget.s.settings['autoCommission'] != false) {
            applyRule();
          }
        }),
        store: widget.s,
        listKey: kind,
        add: widget.preview
            ? null
            : party
            ? () => editParty(context, widget.s, kind)
            : () => addReference(context, widget.s, kind),
      );
  Widget expenseSubcategoryPicker([String label = 'التصنيف الفرعي']) {
    final category = widget.s.refs
        .where((r) => r['id'] == d['expenseCategory'])
        .firstOrNull;
    final names = List<String>.from(category?['subcategories'] ?? []);
    final current = tc('expenseSubcategory').text;
    final custom =
        current == 'أخرى' || (current.isNotEmpty && !names.contains(current));
    if (current.isNotEmpty && !names.contains(current)) names.add(current);
    final selected = names.indexOf(current);
    return Column(
      children: [
        PickField(
          label,
          selected < 0 ? null : selected,
          [
            for (var i = 0; i < names.length; i++) {'id': i, 'name': names[i]},
          ],
          (v) => setState(() {
            tc('expenseSubcategory').text = v == null ? '' : names[v];
            editingCustomExpenseSubcategory = v != null && names[v] == 'أخرى';
          }),
        ),
        if (editingCustomExpenseSubcategory ||
            custom ||
            (names.isEmpty && d['expenseCategory'] != null))
          field('expenseSubcategory', 'اكتب التصنيف الفرعي'),
      ],
    );
  }

  Widget date(String key, String label) =>
      DateField(label, d[key], (v) => setState(() => d[key] = v));
  Widget category(int i, String label) => Column(
    children: [
      field('q$i', 'العدد', number: true),
      pair(
        field('base$i', 'الأساسي للوحدة', number: true, grouped: true),
        field('gross$i', 'الشامل للوحدة', number: true, grouped: true),
      ),
      field('sell$i', 'سعر البيع للوحدة', number: true, grouped: true),
    ],
  );
  List<Widget> optionalFields() {
    final available = <String, Widget>{
      'passenger': passengerPicker(),
      'country': pick('country', 'الدولة', 'country'),
      'from': pick('from', 'مدينة المغادرة', 'city'),
      'to': pick('to', 'مدينة الوصول', 'city'),
      'depart': date('depart', 'تاريخ الذهاب'),
      'return': date('return', 'تاريخ العودة'),
      'city': pick('city', 'المدينة', 'city'),
      'meals': field('meals', 'الوجبات'),
      'rooms': field('rooms', 'عدد الغرف', number: true),
      'people': field('people', 'عدد الأشخاص', number: true),
      'applyDate': date('applyDate', 'تاريخ التقديم'),
      'issueDate': date('issueDate', 'تاريخ الإصدار'),
      'expiry': date('expiry', 'تاريخ الانتهاء'),
      'days': field('days', 'عدد الأيام', number: true),
      'entriesCount': field('entriesCount', 'عدد الدخولات', number: true),
    };
    final keys = switch (widget.kind) {
      'ticket' => ['passenger', 'country', 'from', 'to', 'depart', 'return'],
      'hotel' => ['passenger', 'country', 'city', 'rooms', 'people', 'meals'],
      'visa' => [
        'passenger',
        'country',
        'applyDate',
        'issueDate',
        'expiry',
        'days',
        'entriesCount',
      ],
      _ => <String>[],
    };
    final order = List<String>.from(
      widget.s.settings['fields_${widget.kind}'] ?? keys,
    );
    final hidden = List<String>.from(
      widget.s.settings['hidden_${widget.kind}'] ?? [],
    );
    return [
      ...{...order, ...keys}
          .where((k) => keys.contains(k) && !hidden.contains(k))
          .map((k) => available[k]!),
    ];
  }

  Widget input(InputSpec f) => KeyedSubtree(
    key: anchors.putIfAbsent(f.key, GlobalKey.new),
    child: AbsorbPointer(absorbing: widget.preview, child: inputContent(f)),
  );
  Widget inputContent(InputSpec f) {
    final label = layout.label(f);
    if ([
      'text',
      'multiline',
      'phone',
      'number',
      'count',
      'money',
    ].contains(f.type)) {
      if (f.key == 'expenseSubcategory') {
        return expenseSubcategoryPicker(label);
      }
      final presets = editableLists.containsKey(f.key)
          ? widget.s.referenceList(f.key)
          : <Map<String, dynamic>>[];
      return Column(
        children: [
          textField(
            tc(f.key),
            label,
            number: ['phone', 'number', 'count', 'money'].contains(f.type),
            grouped: f.type == 'money',
            lines: f.type == 'multiline' ? 3 : 1,
          ),
          if (editableLists.containsKey(f.key))
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: const Icon(Icons.list_alt, size: 18),
                label: const UiText('من قائمة محفوظة'),
                onPressed: () async {
                  final id = await chooseListItem(
                    context,
                    label,
                    presets,
                    null,
                    add: true,
                    store: widget.s,
                    listKey: f.key,
                  );
                  if (!mounted || id == null) {
                    return;
                  }
                  if (id == -2) {
                    final added = await addReference(context, widget.s, f.key);
                    if (added != null) {
                      tc(f.key).text = widget.s.reference(added);
                    }
                  } else if (id >= 0) {
                    tc(f.key).text = widget.s.reference(id);
                  }
                },
              ),
            ),
        ],
      );
    }
    if (f.type == 'reference') {
      return pick(
        f.key,
        label,
        f.reference!,
        party: ['customer', 'supplier'].contains(f.reference),
      );
    }
    if (f.type == 'account') {
      return pick(
        d['partyType'] ?? 'customer',
        label,
        d['partyType'] ?? 'customer',
        party: true,
      );
    }
    if (f.key == 'tripType') {
      return ListTile(
        leading: const Icon(Icons.route_rounded),
        title: UiText(label),
        subtitle: UiText(d['return'] == null ? 'ذهاب فقط' : 'ذهاب وعودة'),
      );
    }
    if ((widget.kind == 'ticket' && ['depart', 'return'].contains(f.key)) ||
        (widget.kind == 'hotel' && ['checkIn', 'checkOut'].contains(f.key))) {
      final hotel = widget.kind == 'hotel';
      return TravelRangeField(
        start: d[hotel ? 'checkIn' : 'depart'],
        end: d[hotel ? 'checkOut' : 'return'],
        hotel: hotel,
        label: label,
        onChanged: (range) => setState(() {
          d[hotel ? 'checkIn' : 'depart'] = range.start;
          d[hotel ? 'checkOut' : 'return'] = range.end;
          if (!hotel) d['tripType'] = range.tripType;
        }),
      );
    }
    if (f.type == 'date') {
      return DateField(
        label,
        d[f.key],
        (v) => setState(() => d[f.key] = v),
        optional: f.key != 'date',
      );
    }
    if (f.type == 'passengers') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [UiText(label), passengerPicker()],
      );
    }
    if (f.type == 'attachments') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(label),
          Attachments(
            List<String>.from(d['attachments'] ?? []),
            (v) => setState(() => d['attachments'] = v),
          ),
        ],
      );
    }
    if (f.type == 'bool') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: UiText(label),
        subtitle: f.key == 'personal'
            ? const UiText('الشخصي لا يخصم من صافي ربح المكتب')
            : null,
        value: d[f.key] == true,
        onChanged: (v) => setState(() => d[f.key] = v),
      );
    }
    final choices = inputChoices(
      widget.s.settings,
      widget.kind,
      f,
      current: d[f.key],
    );
    if (f.key == 'ticketType' && choices.isNotEmpty && choices.length <= 3) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiText(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: choices.entries
                  .map(
                    (e) => ButtonSegment(value: e.key, label: UiText(e.value)),
                  )
                  .toList(),
              selected: {d[f.key]?.toString() ?? choices.keys.first},
              onSelectionChanged: (v) => setState(() => d[f.key] = v.first),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ChoiceField<String>(
        fieldKey: f.key,
        initialValue: d[f.key]?.toString(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(fieldIcon(label)),
        ),
        items: choices.entries
            .map((e) => DropdownMenuItem(value: e.key, child: UiText(e.value)))
            .toList(),
        onChanged: (v) => setState(() {
          if (f.type == 'direction') {
            d[f.key] = int.parse(v!);
          } else {
            d[f.key] = v;
          }
          if (f.key == 'partyType') {
            d['customer'] = null;
            d['supplier'] = null;
          }
          if (f.key == 'commissionMode' && v == 'percent') {
            revealed.remove('fee');
          }
        }),
      ),
    );
  }

  bool showField(InputSpec f) =>
      revealed.contains(f.key) ||
      (layout.mode(f) != 'hidden' && layout.applicable(f, d));
  Widget formGroup(String group) {
    final dateKeys = widget.kind == 'ticket'
        ? ['depart', 'return']
        : widget.kind == 'hotel'
        ? ['checkIn', 'checkOut']
        : <String>[];
    final rangeFields = layout.fields
        .where((f) => dateKeys.contains(f.key) && showField(f))
        .toList();
    final primaryRange = rangeFields.firstOrNull?.key;
    final fields = layout.fields
        .where(
          (f) =>
              f.group == group &&
              showField(f) &&
              (!dateKeys.contains(f.key) || f.key == primaryRange),
        )
        .toList();
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }
    final regular = fields
        .where((f) => layout.mode(f) != 'details' || revealed.contains(f.key))
        .toList();
    final details = fields
        .where((f) => layout.mode(f) == 'details' && !revealed.contains(f.key))
        .toList();
    final ids = List<int>.from(
      d['passengers'] ?? (d['passenger'] == null ? [] : [d['passenger']]),
    );
    final subtitle = group == 'passengers' && ids.isNotEmpty
        ? ids.map(widget.s.name).join('، ')
        : null;
    return Section(
      inputGroupLabels[group] ?? group,
      [
        ...regular.map(input),
        if (details.isNotEmpty)
          ExpansionTile(
            title: const UiText('تفاصيل إضافية'),
            children: details.map(input).toList(),
          ),
        if (group == 'travel' && widget.kind == 'ticket')
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const UiText('تبديل المغادرة والوصول'),
            onPressed: () => setState(() {
              final from = d['from'];
              d['from'] = d['to'];
              d['to'] = from;
            }),
          ),
        if (group == 'booking' && d['checkIn'] != null && d['checkOut'] != null)
          UiText(
            'عدد الليالي: ${DateTime.parse(d['checkOut']).difference(DateTime.parse(d['checkIn'])).inDays}',
          ),
        if (group == 'payment')
          const UiText(
            'طريقة الدفع وصف للعملية؛ تسجيل القبض أو الدفع من التسويات.',
          ),
      ],
      key: ValueKey('$group-${revealed.join(',')}'),
      collapsible: true,
      subtitle: subtitle,
      initiallyExpanded:
          layout.expanded(group) || fields.any((f) => revealed.contains(f.key)),
    );
  }

  Widget summary(Totals? totals, {bool compact = false}) {
    if (totals == null) {
      return calcError == null
          ? const SizedBox.shrink()
          : UiText(calcError!, style: const TextStyle(color: Colors.red));
    }
    if (compact) {
      return Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          UiText('البيع ${currency.format(totals.sale)}'),
          UiText('الكلفة ${currency.format(totals.cost)}'),
          UiText(
            'الربح ${currency.format(totals.profit)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: totals.profit < 0 ? Colors.red : const Color(0xff23836c),
            ),
          ),
        ],
      );
    }
    return Section('النتيجة المباشرة', [
      pair(
        AmountBox('البيع', currency.format(totals.sale)),
        AmountBox('كلفة الشراء', currency.format(totals.cost)),
      ),
      pair(
        AmountBox('العمولة', currency.format(totals.commission)),
        AmountBox(
          'الربح',
          currency.format(totals.profit),
          color: totals.profit < 0 ? Colors.red : const Color(0xff23836c),
        ),
      ),
      const UiText(
        'كلفة الشراء هي مستحق المورد؛ الدفعات النقدية تُسجَّل كتسويات.',
      ),
    ]);
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (c, _) {
      final sale = ['ticket', 'hotel', 'visa'].contains(widget.kind);
      Totals? totals;
      var hiddenValues = <InputSpec>[];
      try {
        final values = collect();
        if (sale) totals = calculate(values);
        hiddenValues = layout.fields.where((f) {
          final value = layout.value(f, values);
          return layout.mode(f) == 'hidden' &&
              ['money', 'count', 'number'].contains(f.type) &&
              value is num &&
              value != 0;
        }).toList();
        calcError = null;
      } catch (e) {
        calcError = e.toString().replaceFirst('FormatException: ', '');
      }
      return PopScope(
        canPop: widget.preview || allowLeave || !dirty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !busy) confirmLeave();
        },
        child: Scaffold(
          appBar: ClayAppBar(
            title: UiText(
              '${widget.preview
                  ? 'معاينة'
                  : widget.draft == null
                  ? 'إضافة'
                  : 'تعديل'} ${types[widget.kind]}',
            ),
            backgroundColor: Color.alphaBlend(
              kindColor(widget.kind).withValues(alpha: .12),
              Theme.of(c).colorScheme.surface,
            ),
            actions: [
              if (widget.s.settings['showInputSearch'] != false)
                InputSearch(layout: layout, onSelect: revealField),
              if (!widget.preview)
                IconButton(
                  tooltip: 'تخصيص الإدخالات',
                  icon: const Icon(Icons.tune),
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) =>
                          FormCustomizationPage(widget.s, widget.kind),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServiceBanner(
                  kind: widget.kind,
                  title: types[widget.kind] ?? 'عملية',
                  subtitle: widget.preview
                      ? 'معاينة الإدخالات'
                      : 'بياناتك • حساباتك • بطريقتك',
                  height: 92,
                ),
                if (widget.preview)
                  const ListTile(
                    leading: Icon(Icons.preview_outlined),
                    title: UiText('معاينة فقط — لن تُحفظ عملية أو حركة مالية'),
                  ),

                if (hiddenValues.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: UiText(
                      'حقول مخفية بها قيم: ${hiddenValues.map(layout.label).join('، ')}',
                    ),
                    subtitle: const UiText(
                      'قيمها محفوظة وتدخل في الحساب. اضغط لإظهارها في هذه العملية.',
                    ),
                    onTap: () => setState(
                      () => revealed.addAll(hiddenValues.map((f) => f.key)),
                    ),
                  ),
                for (final group in layout.groups) formGroup(group),
                if (sale) summary(totals),
                if (!widget.preview)
                  TextButton.icon(
                    onPressed: busy ? null : () => save(true, another: true),
                    icon: const Icon(Icons.add_task),
                    label: const UiText('حفظ وإضافة أخرى'),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: widget.preview
              ? null
              : SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(c).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: Theme.of(c).dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sale &&
                              widget.s.settings['stickySummary'] != false)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: summary(totals, compact: true),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy ? null : () => save(true),
                                  icon: const Icon(Icons.check),
                                  label: UiText(
                                    busy
                                        ? 'جارٍ الحفظ…'
                                        : widget.draft?.posted == true
                                        ? 'حفظ التعديل'
                                        : 'حفظ واعتماد',
                                  ),
                                ),
                              ),
                              if (widget.draft?.posted != true) ...[
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: busy ? null : () => save(false),
                                  child: const UiText('مسودة'),
                                ),
                              ],
                            ],
                          ),
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

Future<void> newEntry(
  BuildContext c,
  Store s,
  String kind, {
  Entry? draft,
  int? party,
  bool supplier = false,
}) async {
  await Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) =>
          EntryForm(s, kind, draft: draft, party: party, supplier: supplier),
    ),
  );
}

Future<void> refundDialog(BuildContext c, Store s, Entry e) async {
  final previous = s.entries.where(
    (r) => r.kind == 'refund' && r.posted && r.data['original'] == e.id,
  );
  final remainingSale = e.sale - previous.fold<int>(0, (a, r) => a + r.sale),
      remainingCost = e.cost - previous.fold<int>(0, (a, r) => a + r.cost);
  final sale = TextEditingController(text: e.currency.editInput(remainingSale)),
      cost = TextEditingController(text: e.currency.editInput(remainingCost)),
      note = TextEditingController();
  String date = day(DateTime.now());
  bool busy = false;
  await showDialog(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: UiText('استرجاع العملية #${e.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UiText(
                'يُخفض حساب الزبون والمورد والربح. إعادة النقد تُسجل بتسوية منفصلة.',
              ),
              const SizedBox(height: 16),
              textField(
                sale,
                'المبلغ المسترجع للزبون',
                number: true,
                grouped: true,
              ),
              textField(
                cost,
                'المبلغ المسترجع من المورد',
                number: true,
                grouped: true,
              ),
              DateField(
                'التاريخ',
                date,
                (v) => set(() => date = v!),
                optional: false,
              ),
              textField(note, 'السبب'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const UiText('إلغاء'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    try {
                      await s.saveEntry({
                        'kind': 'refund',
                        'original': e.id,
                        'customer': e.data['customer'],
                        'supplier': e.data['supplier'],
                        'currency': e.currency.name,
                        'date': date,
                        'sale': money(sale.text, e.currency),
                        'cost': money(cost.text, e.currency),
                        'notes': note.text,
                        'posted': true,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      if (ctx.mounted) message(ctx, error);
                    } finally {
                      if (ctx.mounted) set(() => busy = false);
                    }
                  },
            child: const UiText('اعتماد الاسترجاع'),
          ),
        ],
      ),
    ),
  );
  // Controllers are owned by the dialog and released after its exit animation.
  Future.delayed(const Duration(milliseconds: 400), () {
    sale.dispose();
    cost.dispose();
    note.dispose();
  });
}
