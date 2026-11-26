import 'package:flutter/material.dart';
import 'labels.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'pages.dart';

/// Operational follow-up is separate from accounting approval and balances.
class FollowUpPage extends StatefulWidget {
  final Store s;
  const FollowUpPage(this.s, {super.key});
  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  String filter = 'pending';
  static const filters = <String, (String, int)>{
    'pending': ('حجوزات معلّقة', 39),
    'missing': ('مستندات ناقصة', 49),
    'review': ('فيزا قيد التدقيق', 50),
    'issued': ('فيزا صادرة', 51),
    'due': ('مواعيد استحقاق', 57),
    'stays': ('إقامات وتمديدات', 45),
    'passport': ('انتهاء الجوازات', 53),
    'draft': ('المسودات', 60),
    'attachments': ('عمليات بمرفقات', 64),
  };
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.s,
    builder: (context, _) {
      final today = day(DateTime.now());
      final horizon = day(DateTime.now().add(const Duration(days: 180)));
      final entries = widget.s.entries
          .where(
            (e) => switch (filter) {
              'pending' =>
                e.kind == 'ticket' && e.data['bookingStatus'] == 'pending',
              'missing' =>
                e.kind == 'visa' && e.data['documentStatus'] == 'missing',
              'review' => e.kind == 'visa' && e.data['visaStatus'] == 'review',
              'issued' => e.kind == 'visa' && e.data['visaStatus'] == 'issued',
              'due' => e.data['dueDate'] != null,
              'stays' =>
                e.kind == 'hotel' &&
                    ((e.data['extensionUntil'] ?? e.data['checkOut'] ?? '')
                            .toString()
                            .compareTo(today) >=
                        0),
              'draft' => !e.posted,
              'attachments' =>
                (e.data['attachments'] as List? ?? []).isNotEmpty,
              _ => false,
            },
          )
          .toList();
      if (filter == 'due') {
        entries.sort(
          (a, b) => a.data['dueDate'].toString().compareTo(
            b.data['dueDate'].toString(),
          ),
        );
      }
      final people =
          widget.s
              .list('passenger')
              .where(
                (p) =>
                    p['passportExpiry'] != null &&
                    p['passportExpiry'].toString().compareTo(horizon) <= 0,
              )
              .toList()
            ..sort(
              (a, b) => a['passportExpiry'].toString().compareTo(
                b['passportExpiry'].toString(),
              ),
            );
      return Scaffold(
        appBar: const ClayAppBar(title: UiText('متابعة الشغل')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ChoiceField<String>(
                initialValue: filter,
                decoration: const InputDecoration(labelText: 'نوع المتابعة'),
                items: filters.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: UiText(e.value.$1),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => filter = v!),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: UiText(
                'حالة الخدمة لا تغيّر اعتماد العملية أو الرصيد. موعد الاستحقاق للتذكير داخل التطبيق، ويُراجع مع كشف الحساب.',
              ),
            ),
            Expanded(
              child: filter == 'passport'
                  ? people.isEmpty
                        ? const EmptyState(
                            'لا توجد جوازات قريبة الانتهاء',
                            'تُراجع الجوازات المنتهية والتي تنتهي خلال ١٨٠ يومًا.',
                          )
                        : ListView(
                            children: people
                                .map(
                                  (p) => ListTile(
                                    leading: const ArtIcon(53),
                                    title: UiText(p['name'] ?? ''),
                                    subtitle: UiText(
                                      'انتهاء الجواز: ${displayDate(p['passportExpiry'])}',
                                    ),
                                    trailing: const Icon(Icons.chevron_left),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AccountPage(widget.s, p['id']),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                  : entries.isEmpty
                  ? const EmptyState(
                      'لا توجد عمليات مطابقة',
                      'تظهر هنا العمليات حسب التفاصيل المحفوظة داخلها.',
                    )
                  : ListView(
                      children: entries
                          .map(
                            (e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (filter == 'due')
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: UiText(
                                      'موعد الاستحقاق: ${displayDate(e.data['dueDate'])}',
                                    ),
                                  ),
                                EntryTile(widget.s, e),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
