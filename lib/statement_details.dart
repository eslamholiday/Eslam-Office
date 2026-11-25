import 'domain.dart';
import 'store.dart';
import 'labels.dart';

const statementDetails = <String, String>{
  'route': 'مدينتا المغادرة والوصول',
  'country': 'الدولة',
  'airline': 'شركة الطيران',
  'tripType': 'نوع الرحلة',
  'travelDates': 'الذهاب والعودة',
  'hotelName': 'اسم الفندق',
  'city': 'مدينة الفندق',
  'stayDates': 'الدخول والخروج',
  'nights': 'عدد الليالي',
  'rooms': 'عدد الغرف',
  'people': 'عدد الأشخاص',
  'meals': 'الوجبات',
  'visaType': 'نوع الفيزا',
  'visaDays': 'مدة الفيزا',
  'visaDates': 'تواريخ الفيزا',
  'entriesCount': 'عدد الدخولات',
  'settlementMode': 'نوع التسوية',
  'direction': 'أثر الحركة',
  'account': 'الحساب المرتبط',
  'supplier': 'جهة الإصدار',
};
String choiceLabel(
  Map<String, dynamic> settings,
  String field,
  Object? value,
  Map<String, String> defaults,
) {
  final custom = (settings['choices_$field'] as Map?)?['labels'] as Map?;
  return uiLabel(
    custom?['$value']?.toString() ??
        defaults['$value'] ??
        value?.toString() ??
        '',
    settings,
  );
}

Map<String, String> statementDetailValues(
  Store s,
  Entry e, [
  Map<String, dynamic>? preferences,
]) {
  final p = preferences ?? s.settings, d = e.data;
  String ref(String key) => s.reference(d[key] as int?);
  String text(String key) => d[key]?.toString() ?? '';
  String dates(String start, String end) => [
    if (text(start).isNotEmpty) displayDate(text(start), weekday: false),
    if (text(end).isNotEmpty) displayDate(text(end), weekday: false),
  ].join(' - ');
  final result = <String, String>{
    'country': ref('country'),
    'supplier': s.name(d['supplier'] as int?),
    if (e.kind == 'ticket') ...{
      'route': [ref('from'), ref('to')].where((v) => v.isNotEmpty).join(' - '),
      'airline': ref('airline'),
      'tripType': choiceLabel(
        p,
        'tripType',
        d['return'] == null ? 'oneWay' : 'roundTrip',
        {'oneWay': 'ذهاب فقط', 'roundTrip': 'ذهاب وعودة'},
      ),
      'travelDates': dates('depart', 'return'),
    },
    if (e.kind == 'hotel') ...{
      'hotelName': text('hotelName'),
      'city': ref('city'),
      'stayDates': dates('checkIn', 'checkOut'),
      'nights': d['checkIn'] != null && d['checkOut'] != null
          ? '${DateTime.parse(d['checkOut']).difference(DateTime.parse(d['checkIn'])).inDays}'
          : '',
      'rooms': text('rooms'),
      'people': text('people'),
      'meals': text('meals'),
    },
    if (e.kind == 'visa') ...{
      'visaType': text('visaType'),
      'visaDays': text('days'),
      'visaDates': [
        dates('applyDate', 'issueDate'),
        text('expiry'),
      ].where((v) => v.isNotEmpty).join(' · '),
      'entriesCount': text('entriesCount'),
    },
    if (['settlement', 'opening'].contains(e.kind)) ...{
      'settlementMode': choiceLabel(p, 'settlementMode', d['settlementMode'], {
        'cash': 'قبض / دفع نقدي',
        'adjustment': 'تسوية رصيد دون نقد',
      }),
      'direction': choiceLabel(p, 'direction', d['direction'], {
        '-1': 'تخفيض المستحق / إضافة رصيد',
        '1': 'زيادة المستحق',
      }),
      'account': s.name((d['customer'] ?? d['supplier']) as int?),
    },
  };
  result.removeWhere((key, value) => value.isEmpty);
  return result;
}

List<String> orderedStatementDetails(Map<String, dynamic> settings) => <String>{
  ...List<String>.from(settings['statementDetailOrder'] ?? []),
  ...statementDetails.keys,
}.where(statementDetails.containsKey).toList();
bool showStatementDetail(Map<String, dynamic> settings, String key) =>
    settings['statementDetail_$key'] as bool? ??
    (settings['statementShowTravel'] != false &&
        ![
          'supplier',
          'account',
          'pnr',
          'rooms',
          'people',
          'meals',
          'visaDates',
        ].contains(key));
String statementDescription(
  Store s,
  Entry e,
  Map<String, dynamic> settings, {
  bool details = true,
}) {
  final parts = <String>[
    [
      uiLabel(e.label, settings),
      if (settings['statementShowNumber'] != false) '#${e.id}',
      if (settings['statementShowQuantity'] != false &&
          ['ticket', 'visa', 'hotel'].contains(e.kind))
        '(${e.quantity})',
    ].join(' '),
    if (settings['statementShowPassengers'] != false && e.passengers.isNotEmpty)
      e.passengers.map(s.name).join('، '),
    if (settings['statementShowPayment'] != false &&
        e.data['paymentMethod'] != null)
      choiceLabel(
        settings,
        'paymentMethod',
        e.data['paymentMethod'],
        paymentMethods,
      ),
  ];
  if (details) {
    final values = statementDetailValues(s, e, settings);
    for (final key in orderedStatementDetails(settings)) {
      if (showStatementDetail(settings, key) && values[key] != null) {
        final value = values[key]!;
        parts.add(switch (key) {
          'nights' => '$value ${uiLabel('ليلة', settings)}',
          'rooms' => '$value ${uiLabel('غرفة', settings)}',
          'people' => '$value ${uiLabel('شخص', settings)}',
          'visaDays' => '$value ${uiLabel('يوم', settings)}',
          'entriesCount' => '$value ${uiLabel('دخول', settings)}',
          _ => value,
        });
      }
    }
  }
  if (settings['statementShowNotes'] == true &&
      (e.data['notes'] ?? '').toString().isNotEmpty) {
    parts.add('${e.data['notes']}');
  }
  return parts.join('\n');
}
