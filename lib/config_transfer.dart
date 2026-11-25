import 'labels.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'store.dart';
import 'domain.dart';
import 'input_schema.dart';
import 'ui.dart';

class ConfigTransfer {
  static bool portableKey(String key) =>
      ![
        'moneyMigration',
        'personalExpenseSeed',
        'experience21',
        'logo',
        'statementTemplatesOwner',
      ].contains(key) &&
      !key.startsWith('recovery_') &&
      !key.startsWith('statement_party_');
  static Map<String, dynamic> exportData(Store s) {
    final settings = <String, dynamic>{
      for (final e in s.settings.entries)
        if (portableKey(e.key)) e.key: e.value,
    };
    for (final scope in inputScopes.keys) {
      final key = 'defaults_$scope';
      if (settings[key] is! Map) continue;
      final values = Map<String, dynamic>.from(settings[key]);
      for (final f in inputSpecs(scope).where((f) => f.reference != null)) {
        final value = values[f.key];
        if (value is! int) continue;
        final candidates =
            ['customer', 'supplier', 'passenger'].contains(f.reference)
            ? s.parties
            : s.refs;
        final record = candidates.where((r) => r['id'] == value).firstOrNull;
        values[f.key] = record == null
            ? null
            : {'referenceKind': f.reference, 'referenceName': record['name']};
      }
      settings[key] = values;
    }
    return {
      'format': 'EslamMoneyPreferences',
      'version': 1,
      'settings': settings,
      'geography': [
        for (final r in s.refs.where(
          (r) => ['city', 'country'].contains(r['kind']),
        ))
          {
            'kind': r['kind'],
            'name': r['name'],
            if (r.containsKey('countryCode')) 'countryCode': r['countryCode'],
            if (r.containsKey('flagCode')) 'flagCode': r['flagCode'],
          },
      ],
      'accounts': [
        for (final e in s.settings.entries.where(
          (e) => e.key.startsWith('statement_party_') && e.value is Map,
        ))
          {
            'name': s.name(
              int.tryParse(e.key.substring('statement_party_'.length)),
            ),
            'config': e.value,
          },
      ],
    };
  }

  static Future<void> importData(Store s, Map<String, dynamic> data) async {
    if (data['format'] != 'EslamMoneyPreferences' ||
        data['version'] != 1 ||
        data['settings'] is! Map)
      throw const FormatException('ملف تخصيصات غير مدعوم');
    final settings = Map<String, dynamic>.from(data['settings']);
    for (final scope in inputScopes.keys) {
      final key = 'defaults_$scope';
      if (settings[key] is! Map) continue;
      final values = Map<String, dynamic>.from(settings[key]);
      for (final e in values.entries.toList()) {
        if (e.value is! Map || e.value['referenceKind'] == null) continue;
        final ref = e.value as Map;
        final candidates =
            ['customer', 'supplier', 'passenger'].contains(ref['referenceKind'])
            ? s.parties
            : s.refs;
        final matches = candidates
            .where(
              (r) =>
                  r['kind'] == ref['referenceKind'] &&
                  normalize(r['name']) == normalize(ref['referenceName']) &&
                  r['archived'] == 0,
            )
            .toList();
        values[e.key] = matches.length == 1 ? matches.single['id'] : null;
      }
      settings[key] = values;
    }
    for (final e in settings.entries) {
      if (portableKey(e.key)) await s.set(e.key, e.value);
    }
    for (final value in data['geography'] as List? ?? []) {
      final r = Map<String, dynamic>.from(value as Map);
      if (!['city', 'country'].contains(r['kind'])) continue;
      final matches = s.refs
          .where(
            (v) =>
                v['kind'] == r['kind'] &&
                normalize(v['name']) == normalize(r['name']),
          )
          .toList();
      if (matches.length != 1) continue;
      final old = matches.single;
      final payload = Map<String, dynamic>.from(old)..remove('payload');
      for (final key in ['countryCode', 'flagCode'])
        if (r.containsKey(key)) payload[key] = r[key];
      await s.saveRef(old['kind'], old['name'], payload, id: old['id']);
    }
    for (final value in data['accounts'] as List? ?? []) {
      final r = Map<String, dynamic>.from(value as Map);
      final matches = s
          .list('customer')
          .where((v) => normalize(v['name']) == normalize(r['name']))
          .toList();
      if (matches.length == 1 && r['config'] is Map)
        await s.set('statement_party_${matches.single['id']}', r['config']);
    }
  }
}

class ConfigTransferPage extends StatelessWidget {
  final Store s;
  const ConfigTransferPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClayAppBar(title: UiText('نقل تخصيصات التطبيق')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section('حفظ إعداداتك', [
          const UiText(
            'العناوين والخيارات والحقول وقوالب الكشف والأشكال والأعلام والمؤثرات. لا يتضمن الملف العمليات أو القيود المالية.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => guarded(context, () async {
              final bytes = utf8.encode(
                const JsonEncoder.withIndent(
                  '  ',
                ).convert(ConfigTransfer.exportData(s)),
              );
              await FilePicker.platform.saveFile(
                dialogTitle: 'تصدير التخصيصات',
                fileName: 'Eslam-Money-settings.json',
                type: FileType.custom,
                allowedExtensions: ['json'],
                bytes: bytes,
              );
            }),
            icon: const Icon(Icons.file_upload_outlined),
            label: const UiText('تصدير التخصيصات'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => guarded(context, () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                withData: true,
              );
              if (result == null) return;
              final file = result.files.single;
              final bytes = file.bytes ?? await File(file.path!).readAsBytes();
              final data = jsonDecode(utf8.decode(bytes));
              if (data is! Map) throw const FormatException('ملف غير صالح');
              if (!context.mounted) return;
              final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const UiText('تطبيق التخصيصات من الملف؟'),
                  content: const UiText(
                    'تُحدّث إعدادات الواجهة والخيارات؛ تُربط الأسماء المطابقة الموجودة فقط، وتبقى قوائمك وعملياتك محفوظة.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const UiText('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const UiText('تطبيق'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await ConfigTransfer.importData(
                  s,
                  Map<String, dynamic>.from(data),
                );
                if (context.mounted) message(context, 'تم استيراد التخصيصات');
              }
            }),
            icon: const Icon(Icons.file_download_outlined),
            label: const UiText('استيراد التخصيصات'),
          ),
        ]),
      ],
    ),
  );
}
