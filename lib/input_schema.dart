import 'domain.dart';

const inputScopes = {
  'ticket': 'التذاكر والتغيير',
  'hotel': 'الفنادق',
  'visa': 'الفيزا',
  'settlement': 'التسويات',
  'opening': 'الأرصدة الافتتاحية',
  'expense': 'المصروفات',
  'funding': 'التمويل',
  'customer': 'الزبائن',
  'supplier': 'جهات الإصدار',
  'passenger': 'المسافرون',
  'family': 'العائلات',
};

const inputModes = {
  'visible': 'ظاهر دائمًا',
  'details': 'ضمن تفاصيل إضافية',
  'auto': 'حسب الحاجة',
  'hidden': 'مخفي',
};

const travelerTypes = {'ADT': 'بالغ', 'CHD': 'طفل', 'INF': 'رضيع'};

Map<String, String> inputChoices(
  Map<String, dynamic> settings,
  String scope,
  InputSpec f, {
  dynamic current,
}) {
  final config = Map<String, dynamic>.from(settings['choices_${f.key}'] ?? {});
  final labels = Map<String, String>.from(config['labels'] ?? {});
  final hidden = List<String>.from(config['hidden'] ?? []);
  final order = List<String>.from(config['order'] ?? []);
  final all = {...f.choices, ...labels};
  return {
    for (final key in {...order, ...all.keys})
      if (all.containsKey(key) &&
          (!hidden.contains(key) || current?.toString() == key))
        key: all[key]!,
    if (current != null && !all.containsKey(current.toString()))
      current.toString(): current.toString(),
  };
}

class InputSpec {
  final String key, label, group, type;
  final String? reference;
  final Map<String, String> choices;
  final bool requiredByDefault;
  const InputSpec(
    this.key,
    this.label,
    this.group, {
    this.type = 'text',
    this.reference,
    this.choices = const {},
    this.requiredByDefault = false,
  });
}

const inputGroupLabels = {
  'main': 'معلومات العملية',
  'commission': 'العمولة',
  'adult': 'بالغ / Adult',
  'child': 'طفل / Child',
  'infant': 'رضيع / Infant',
  'passengers': 'المسافرون',
  'travel': 'تفاصيل السفر',
  'booking': 'الحجز',
  'service': 'تفاصيل الفيزا',
  'movement': 'حركة الحساب',
  'expense': 'المصروف',
  'payment': 'طريقة التسديد',
  'notes': 'الملاحظات والمرفقات',
  'identity': 'البيانات الأساسية',
  'profile': 'صورة / شخصية الحساب',
};

List<InputSpec> inputSpecs(String scope) {
  if (['customer', 'supplier', 'passenger', 'family'].contains(scope)) {
    return [
      const InputSpec('name', 'الاسم', 'identity', requiredByDefault: true),
      if (scope != 'family')
        const InputSpec('phone', 'رقم الهاتف', 'identity', type: 'phone'),
      if (scope == 'passenger') ...[
        const InputSpec(
          'travelerType',
          'نوع المسافر',
          'identity',
          type: 'choice',
          choices: travelerTypes,
        ),
        const InputSpec(
          'customer',
          'حساب الزبون',
          'identity',
          type: 'reference',
          reference: 'customer',
        ),
        const InputSpec('passport', 'رقم الجواز', 'identity'),
      ],
      const InputSpec('notes', 'ملاحظات', 'notes', type: 'multiline'),
      const InputSpec('attachments', 'المرفقات', 'notes', type: 'attachments'),
      if (scope == 'customer' || scope == 'supplier')
        const InputSpec(
          'profile',
          'صورة / شخصية الحساب',
          'profile',
          type: 'profile',
        ),
    ];
  }
  final sale = ['ticket', 'hotel', 'visa'].contains(scope);
  return [
    if (scope == 'ticket') ...[
      const InputSpec(
        'ticketType',
        'نوع العملية',
        'main',
        type: 'choice',
        choices: {'ticket': 'تذكرة', 'change': 'تغيير'},
      ),
      const InputSpec(
        'tripType',
        'نوع الرحلة',
        'travel',
        type: 'choice',
        choices: {'oneWay': 'ذهاب فقط', 'roundTrip': 'ذهاب وعودة'},
      ),
    ],
    if (sale)
      const InputSpec(
        'customer',
        'حساب الزبون',
        'main',
        type: 'reference',
        reference: 'customer',
        requiredByDefault: true,
      ),
    if (scope == 'settlement' || scope == 'opening') ...[
      const InputSpec(
        'partyType',
        'نوع الحساب',
        'main',
        type: 'choice',
        choices: {'customer': 'زبون', 'supplier': 'جهة إصدار'},
      ),
      const InputSpec(
        'account',
        'الحساب',
        'main',
        type: 'account',
        requiredByDefault: true,
      ),
    ],
    const InputSpec(
      'currency',
      'العملة',
      'main',
      type: 'choice',
      choices: {'USD': 'USD — دولار', 'IQD': 'IQD — دينار'},
      requiredByDefault: true,
    ),
    const InputSpec(
      'date',
      'تاريخ العملية',
      'main',
      type: 'date',
      requiredByDefault: true,
    ),
    if (sale)
      const InputSpec(
        'supplier',
        'جهة الإصدار / المورد',
        'main',
        type: 'reference',
        reference: 'supplier',
      ),
    if (scope == 'ticket') ...[
      const InputSpec(
        'airline',
        'شركة الطيران',
        'main',
        type: 'reference',
        reference: 'airline',
      ),
      const InputSpec(
        'commissionMode',
        'طريقة احتساب العمولة',
        'commission',
        type: 'choice',
        choices: {'percent': 'خصم عمولة', 'fee': 'رسم إصدار إضافي'},
      ),
      const InputSpec(
        'rate',
        'نسبة العمولة من السعر الأساسي %',
        'commission',
        type: 'number',
      ),
      const InputSpec(
        'fee',
        'رسم الإصدار لكل تذكرة',
        'commission',
        type: 'money',
      ),
      for (var i = 0; i < 3; i++) ...[
        InputSpec(
          'q$i',
          'العدد',
          ['adult', 'child', 'infant'][i],
          type: 'count',
        ),
        InputSpec(
          'base$i',
          'الأساسي للوحدة',
          ['adult', 'child', 'infant'][i],
          type: 'money',
        ),
        InputSpec(
          'gross$i',
          'الشامل للوحدة',
          ['adult', 'child', 'infant'][i],
          type: 'money',
        ),
        InputSpec(
          'sell$i',
          'سعر البيع للوحدة',
          ['adult', 'child', 'infant'][i],
          type: 'money',
        ),
      ],
    ],
    if (sale)
      const InputSpec(
        'passenger',
        'أسماء المسافرين',
        'passengers',
        type: 'passengers',
      ),
    if (scope == 'hotel') ...[
      const InputSpec('hotelName', 'اسم الفندق', 'booking'),
      const InputSpec('checkIn', 'تاريخ الدخول', 'booking', type: 'date'),
      const InputSpec('checkOut', 'تاريخ الخروج', 'booking', type: 'date'),
      const InputSpec(
        'costUnit',
        'التكلفة الكاملة للحجز',
        'booking',
        type: 'money',
      ),
      const InputSpec('sell', 'البيع الكامل للحجز', 'booking', type: 'money'),
    ],
    if (scope == 'visa') ...[
      const InputSpec('visaType', 'نوع الفيزا', 'service'),
      const InputSpec('qty', 'العدد', 'service', type: 'count'),
      const InputSpec('costUnit', 'تكلفة الواحدة', 'service', type: 'money'),
      const InputSpec('sell', 'بيع الواحدة', 'service', type: 'money'),
    ],
    if (sale)
      const InputSpec(
        'country',
        'الدولة',
        'travel',
        type: 'reference',
        reference: 'country',
      ),
    if (scope == 'ticket') ...[
      const InputSpec(
        'from',
        'مدينة المغادرة',
        'travel',
        type: 'reference',
        reference: 'city',
      ),
      const InputSpec(
        'to',
        'مدينة الوصول',
        'travel',
        type: 'reference',
        reference: 'city',
      ),
      const InputSpec('depart', 'تاريخ الذهاب', 'travel', type: 'date'),
      const InputSpec('return', 'تاريخ العودة', 'travel', type: 'date'),
    ],
    if (scope == 'hotel') ...[
      const InputSpec(
        'city',
        'المدينة',
        'travel',
        type: 'reference',
        reference: 'city',
      ),
      const InputSpec('rooms', 'عدد الغرف', 'travel', type: 'count'),
      const InputSpec('people', 'عدد الأشخاص', 'travel', type: 'count'),
      const InputSpec('meals', 'الوجبات', 'travel'),
    ],
    if (scope == 'visa') ...[
      const InputSpec('applyDate', 'تاريخ التقديم', 'travel', type: 'date'),
      const InputSpec('issueDate', 'تاريخ الإصدار', 'travel', type: 'date'),
      const InputSpec('expiry', 'تاريخ الانتهاء', 'travel', type: 'date'),
      const InputSpec('days', 'عدد الأيام', 'travel', type: 'count'),
      const InputSpec('entriesCount', 'عدد الدخولات', 'travel', type: 'count'),
    ],
    if (['settlement', 'opening', 'expense', 'funding'].contains(scope))
      const InputSpec(
        'amount',
        'المبلغ',
        'movement',
        type: 'money',
        requiredByDefault: true,
      ),
    if (scope == 'settlement' || scope == 'opening') ...[
      const InputSpec(
        'direction',
        'أثر الحركة',
        'movement',
        type: 'direction',
        choices: {'-1': 'تخفيض المستحق / إضافة رصيد', '1': 'زيادة المستحق'},
      ),
      if (scope == 'settlement')
        const InputSpec(
          'settlementMode',
          'نوع التسوية',
          'movement',
          type: 'choice',
          choices: {
            'cash': 'قبض / دفع نقدي',
            'adjustment': 'تسوية رصيد دون نقد',
          },
        ),
    ],
    if (scope == 'expense') ...[
      const InputSpec(
        'expenseCategory',
        'تصنيف المصروف',
        'expense',
        type: 'reference',
        reference: 'expenseCategory',
      ),
      const InputSpec('expenseSubcategory', 'التصنيف الفرعي', 'expense'),
      const InputSpec('personal', 'مصروف شخصي', 'expense', type: 'bool'),
    ],
    if (scope != 'opening')
      const InputSpec(
        'paymentMethod',
        'طريقة التسديد',
        'payment',
        type: 'choice',
        choices: paymentMethods,
      ),
    const InputSpec(
      'notes',
      'ملاحظات / سبب الحركة',
      'notes',
      type: 'multiline',
    ),
    const InputSpec('attachments', 'المرفقات', 'notes', type: 'attachments'),
  ];
}

class InputLayout {
  final String scope;
  final Map<String, dynamic> settings;
  InputLayout(this.settings, this.scope);
  Map<String, dynamic> get config =>
      Map<String, dynamic>.from(settings['input_$scope'] ?? {});
  Map<String, dynamic> get defaults =>
      Map<String, dynamic>.from(settings['defaults_$scope'] ?? {});
  List<InputSpec> get fields {
    final all = inputSpecs(scope);
    final legacy = List<String>.from(settings['fields_$scope'] ?? []);
    final order = List<String>.from(config['order'] ?? legacy);
    return [
          ...{...order, ...all.map((f) => f.key)},
        ]
        .map((key) => all.where((f) => f.key == key).firstOrNull)
        .whereType<InputSpec>()
        .toList();
  }

  List<String> get groups {
    final all = inputSpecs(scope).map((f) => f.group).toSet();
    final order = List<String>.from(
      config['groups'] ??
          [
            'identity',
            'main',
            'passengers',
            'adult',
            'child',
            'infant',
            'commission',
            'booking',
            'service',
            'movement',
            'expense',
            'travel',
            'payment',
            'notes',
            'profile',
          ],
    );
    return [
      ...{...order, ...all},
    ].where(all.contains).toList();
  }

  Map<String, dynamic> fieldConfig(String key) =>
      Map<String, dynamic>.from((config['fields'] as Map?)?[key] ?? {});
  String label(InputSpec f) =>
      displayLabel(fieldConfig(f.key)['label'] ?? f.label);
  String mode(InputSpec f) =>
      fieldConfig(f.key)['mode'] ??
      (List<String>.from(settings['hidden_$scope'] ?? []).contains(f.key)
          ? 'hidden'
          : (f.key == 'return' ? 'auto' : 'visible'));
  bool requiredField(InputSpec f) =>
      fieldConfig(f.key)['required'] ?? f.requiredByDefault;
  bool expanded(String group) =>
      (config['expanded'] as Map?)?[group] ??
      !['child', 'infant', 'notes'].contains(group);
  List<String> missing(Map<String, dynamic> data) => fields
      .where((f) {
        if (!requiredField(f) || !applicable(f, data)) {
          return false;
        }
        final v = value(f, data);
        return v == null ||
            v == '' ||
            (v is List && v.isEmpty) ||
            ((f.type == 'count' || f.type == 'money') && v is num && v <= 0);
      })
      .map((f) => f.key)
      .toList();

  dynamic value(InputSpec f, Map<String, dynamic> data) {
    if (f.key == 'profile') return data['profileImage'] ?? data['avatar'];
    if (f.key == 'account') {
      return data[data['partyType'] ?? 'customer'];
    }
    if (f.key == 'passenger') {
      return data['passengers'] ??
          (data['passenger'] == null ? [] : [data['passenger']]);
    }
    final match = RegExp(r'^(q|base|gross|sell)([0-2])$').firstMatch(f.key);
    if (match != null) {
      final lines = data['lines'] as List? ?? [];
      final i = int.parse(match[2]!);
      return i < lines.length
          ? lines[i][match[1] == 'q' ? 'qty' : match[1]]
          : null;
    }
    return data[f.key];
  }

  bool applicable(InputSpec f, Map<String, dynamic> data) {
    if (f.key == 'rate') {
      return data['commissionMode'] != 'fee';
    }
    if (f.key == 'fee') {
      return data['commissionMode'] == 'fee';
    }
    if (f.key == 'return') {
      return data['tripType'] != 'oneWay' || data['return'] != null;
    }
    return true;
  }
}
