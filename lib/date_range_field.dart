import 'labels.dart';
import 'package:flutter/material.dart';
import 'domain.dart';
import 'ui.dart';

class TravelRange {
  final String? start, end;
  const TravelRange(this.start, this.end);
  String get tripType => end == null ? 'oneWay' : 'roundTrip';
  int? get nights => start == null || end == null
      ? null
      : DateTime.parse(end!).difference(DateTime.parse(start!)).inDays;
}

Future<TravelRange?> chooseTravelRange(
  BuildContext context, {
  String? start,
  String? end,
  bool hotel = false,
}) {
  DateTime? first = DateTime.tryParse(start ?? ''),
      last = DateTime.tryParse(end ?? '');
  DateTime shown = first ?? DateTime.now();
  bool selectEnd = first != null && last == null;
  return showModalBottomSheet<TravelRange>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiText(
                hotel ? 'الدخول والخروج' : 'الذهاب والعودة الاختيارية',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: UiText(
                      '${hotel ? 'الدخول' : 'الذهاب'}: ${first == null ? 'اختر التاريخ' : displayDate(day(first!), weekday: false)}',
                    ),
                    selected: !selectEnd,
                    onSelected: (_) => set(() => selectEnd = false),
                  ),
                  ChoiceChip(
                    label: UiText(
                      '${hotel ? 'الخروج' : 'العودة'}: ${last == null ? 'اختياري' : displayDate(day(last!), weekday: false)}',
                    ),
                    selected: selectEnd,
                    onSelected: (_) => set(() => selectEnd = true),
                  ),
                ],
              ),
              SizedBox(
                height: 310,
                child: CalendarDatePicker(
                  key: ValueKey(
                    '${first == null}-${selectEnd ? 'end' : 'start'}',
                  ),
                  initialDate:
                      selectEnd &&
                          hotel &&
                          first != null &&
                          !shown.isAfter(first!)
                      ? first!.add(const Duration(days: 1))
                      : shown,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                  selectableDayPredicate: (date) =>
                      !selectEnd ||
                      first == null ||
                      (hotel ? date.isAfter(first!) : !date.isBefore(first!)),
                  onDateChanged: (date) => set(() {
                    shown = date;
                    if (!selectEnd || first == null) {
                      first = date;
                      if (last != null &&
                          (hotel ? !last!.isAfter(date) : last!.isBefore(date)))
                        last = null;
                      selectEnd = true;
                    } else {
                      last = date;
                    }
                  }),
                ),
              ),
              if (first != null)
                UiText(
                  last == null
                      ? (hotel
                            ? 'تاريخ دخول فقط — لم تحدد مدة الإقامة'
                            : 'ذهاب فقط')
                      : hotel
                      ? '${last!.difference(first!).inDays} ليالٍ'
                      : 'ذهاب وعودة',
                ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  TextButton.icon(
                    onPressed: () => set(() {
                      last = null;
                      selectEnd = true;
                    }),
                    icon: const Icon(Icons.backspace_outlined),
                    label: UiText(hotel ? 'مسح الخروج' : 'مسح العودة'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, const TravelRange(null, null)),
                    icon: const Icon(Icons.clear),
                    label: const UiText('مسح التاريخين'),
                  ),
                  FilledButton.icon(
                    onPressed: first == null
                        ? null
                        : () => Navigator.pop(
                            ctx,
                            TravelRange(
                              day(first!),
                              last == null ? null : day(last!),
                            ),
                          ),
                    icon: const Icon(Icons.check),
                    label: const UiText('اعتماد التواريخ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TravelRangeField extends StatelessWidget {
  final String? start, end;
  final bool hotel;
  final ValueChanged<TravelRange> onChanged;
  final String? label;
  const TravelRangeField({
    super.key,
    this.start,
    this.end,
    this.hotel = false,
    required this.onChanged,
    this.label,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final range = await chooseTravelRange(
          context,
          start: start,
          end: end,
          hotel: hotel,
        );
        if (range != null) onChanged(range);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? (hotel ? 'فترة الإقامة' : 'تاريخ السفر'),
          prefixIcon: const Icon(Icons.date_range_rounded),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              start == null
                  ? 'اختر التاريخ'
                  : '${displayDate(start, weekday: false)}${end == null ? '' : '  ←  ${displayDate(end, weekday: false)}'}',
            ),
            if (start != null)
              UiText(
                hotel
                    ? (end == null
                          ? 'الدخول فقط'
                          : '${TravelRange(start, end).nights} ليالٍ')
                    : end == null
                    ? 'ذهاب فقط'
                    : 'ذهاب وعودة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ),
  );
}
