import 'dart:convert';
import 'domain.dart';

Entry? possibleDuplicate(
  List<Entry> entries,
  Map<String, dynamic> values, {
  int? excludeId,
}) {
  if (!['ticket', 'hotel', 'visa'].contains(values['kind'])) return null;
  final pnr = normalize('${values['pnr'] ?? ''}');
  String fingerprint(Map<String, dynamic> v) {
    final passengers = List<int>.from(v['passengers'] ?? [])..sort();
    return jsonEncode([
      v['kind'],
      v['ticketType'],
      v['currency'],
      v['customer'],
      v['supplier'],
      v['date'],
      v['from'],
      v['to'],
      v['depart'],
      v['return'],
      v['hotelName'],
      v['visaType'],
      v['checkIn'],
      v['checkOut'],
      passengers,
      v['lines'],
      v['qty'],
      v['sell'],
      v['costUnit'],
    ]);
  }

  final key = fingerprint(values);
  return entries
      .where(
        (e) =>
            e.posted &&
            e.id != excludeId &&
            e.kind == values['kind'] &&
            e.data['ticketType'] == values['ticketType'] &&
            ((pnr.isNotEmpty && pnr == normalize('${e.data['pnr'] ?? ''}')) ||
                fingerprint(e.data) == key),
      )
      .firstOrNull;
}
