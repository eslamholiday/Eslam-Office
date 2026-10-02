import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'domain.dart';

const navy = Color(0xFF123B5D), gold = Color(0xFFD4A84F);
IconData kindIcon(String kind) => switch (kind) {
  'ticket' => Icons.flight_takeoff_rounded,
  'hotel' => Icons.hotel_rounded,
  'visa' => Icons.badge_rounded,
  'settlement' => Icons.swap_horiz_rounded,
  'expense' => Icons.receipt_long_rounded,
  'refund' => Icons.undo_rounded,
  _ => Icons.account_balance_wallet_rounded,
};
Color kindColor(String kind) => switch (kind) {
  'ticket' => const Color(0xff2878bb),
  'hotel' => const Color(0xff9067be),
  'visa' => const Color(0xff249786),
  'settlement' => const Color(0xffbc8936),
  'refund' => const Color(0xffba5959),
  _ => navy,
};
void message(BuildContext c, Object e) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(e.toString().replaceFirst('FormatException: ', ''))),
  );
}

Future<void> guarded(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (c.mounted) message(c, e);
  }
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const Section(this.title, this.children, {super.key, this.trailing});
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(c).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? action;
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 66,
          color: Theme.of(c).colorScheme.primary.withValues(alpha: .45),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(c).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
            ),
          ),
      ],
    ),
  );
}

class AmountBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const AmountBox(this.label, this.value, {super.key, this.color});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: (color ?? Theme.of(c).colorScheme.primary).withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(c).textTheme.labelLarge),
        const SizedBox(height: 8),
        FittedBox(
          child: Text(
            value,
            textDirection: TextDirection.ltr,
            style: Theme.of(c).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? Theme.of(c).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget pair(Widget a, Widget b) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  ),
);
class ThousandsSeparatorFormatter extends TextInputFormatter {
  const ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalize(newValue.text).replaceAll('٫', '.');
    final whole = normalized.split('.').first;
    final digits = whole.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final value = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,##0', 'en').format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Widget textField(
  TextEditingController controller,
  String label, {
  bool number = false,
  bool grouped = false,
  ValueChanged<String>? onChanged,
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    textDirection: number ? TextDirection.ltr : null,
    inputFormatters: grouped ? const [ThousandsSeparatorFormatter()] : null,
    scrollPadding: const EdgeInsets.only(bottom: 140),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    onChanged: onChanged,
    maxLines: lines,
  ),
);

class DateField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;
  const DateField(
    this.label,
    this.value,
    this.onChanged, {
    super.key,
    this.optional = true,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: c,
          initialDate: DateTime.tryParse(value ?? '') ?? DateTime.now(),
          firstDate: DateTime(1990),
          lastDate: DateTime(2100),
        );
        if (selected != null) onChanged(day(selected));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null && optional
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value == null ? 'اختر التاريخ' : displayDate(value),
          style: value == null ? const TextStyle(color: Colors.grey) : null,
        ),
      ),
    ),
  );
}

class PickField extends StatelessWidget {
  final String label;
  final int? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;
  final Future<int?> Function()? add;
  const PickField(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    super.key,
    this.add,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        var query = '';
        final result = await showModalBottomSheet<int>(
          context: c,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .75,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    MediaQuery.viewInsetsOf(ctx).bottom,
                  ),
                  child: Column(
                    children: [
                      Text(label, style: Theme.of(ctx).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: false,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'بحث في القائمة',
                        ),
                        onChanged: (s) => set(() => query = normalize(s)),
                      ),
                      if (add != null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx, -2);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة جديد'),
                        ),
                      Expanded(
                        child: ListView(
                          children: [
                            ListTile(
                              title: const Text('بدون اختيار'),
                              onTap: () => Navigator.pop(ctx, -1),
                            ),
                            ...items
                                .where(
                                  (r) => normalize(
                                    '${r['name']} ${r['phone'] ?? ''} ${r['code'] ?? ''}',
                                  ).contains(query),
                                )
                                .map(
                                  (r) => ListTile(
                                    title: Text(r['name']),
                                    subtitle:
                                        r['code'] != null && r['code'] != ''
                                        ? Text(r['code'])
                                        : null,
                                    trailing: value == r['id']
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () =>
                                        Navigator.pop(ctx, r['id'] as int),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (result == -2) {
          final id = await add!();
          if (id != null) onChanged(id);
        } else if (result != null) {
          onChanged(result == -1 ? null : result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          items.where((r) => r['id'] == value).firstOrNull?['name'] ??
              'اختياري',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

const profileAvatars = <String>[
  '👨‍💼','👩‍💼','🧑‍💼','👨🏻‍💼','👩🏻‍💼','👨🏽‍💼','👩🏽‍💼','👨🏿‍💼','👩🏿‍💼','🧑🏻‍💼',
  '👨‍✈️','👩‍✈️','🧑‍✈️','👨🏻‍✈️','👩🏻‍✈️','👨🏽‍✈️','👩🏽‍✈️','👨🏿‍✈️','👩🏿‍✈️','🧑🏻‍✈️',
  '🧳','✈️','🌍','🏨','🛂','🧑‍🚀','👨‍🎓','👩‍🎓','🧑‍🎓','🙂',
];

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String? avatar;
  final double radius;
  const ProfileAvatar({super.key, this.imagePath, this.avatar, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final file = imagePath == null || imagePath!.isEmpty ? null : File(imagePath!);
    final hasImage = file != null && file.existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      backgroundImage: hasImage ? FileImage(file!) : null,
      child: hasImage
          ? null
          : Text(
              avatar?.isNotEmpty == true ? avatar! : '👤',
              style: TextStyle(fontSize: radius * .95),
            ),
    );
  }
}

class ProfilePicker extends StatelessWidget {
  final String? imagePath;
  final String? avatar;
  final void Function(String? imagePath, String? avatar) onChanged;
  const ProfilePicker({super.key, this.imagePath, this.avatar, required this.onChanged});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
      if (picked == null) return;
      final base = (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$base/profiles');
      await dir.create(recursive: true);
      final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${p.basename(picked.path)}';
      await File(picked.path).copy(target);
      onChanged(target, null);
    } catch (e) {
      if (context.mounted) message(context, 'تعذر اختيار الصورة: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: ProfileAvatar(imagePath: imagePath, avatar: avatar, radius: 42)),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.gallery), icon: const Icon(Icons.photo_outlined), label: const Text('رفع صورة')),
          OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('كاميرا')),
          if ((imagePath?.isNotEmpty ?? false) || (avatar?.isNotEmpty ?? false))
            TextButton.icon(onPressed: () => onChanged(null, null), icon: const Icon(Icons.delete_outline), label: const Text('إزالة')),
        ],
      ),
      const SizedBox(height: 10),
      const Text('أو اختر شخصية / ستكر'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: profileAvatars.map((v) => ChoiceChip(
          label: Text(v, style: const TextStyle(fontSize: 22)),
          selected: imagePath == null && avatar == v,
          onSelected: (_) => onChanged(null, v),
        )).toList(),
      ),
    ],
  );
}

class Attachments extends StatefulWidget {
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  const Attachments(this.paths, this.onChanged, {super.key});
  @override
  State<Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<Attachments> {
  bool busy = false;
  Future<void> pick(int source) async {
    setState(() => busy = true);
    try {
      String? path;
      if (source == 2) {
        path = (await FilePicker.platform.pickFiles())?.files.single.path;
      } else {
        path = (await ImagePicker().pickImage(
          source: source == 0 ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 90,
        ))?.path;
      }
      if (path != null) {
        final dir = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/attachments',
        );
        await dir.create(recursive: true);
        final target =
            '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}';
        await File(path).copy(target);
        widget.onChanged([...widget.paths, target]);
      }
    } catch (e) {
      if (mounted) message(context, 'تعذر اختيار المرفق: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : () => pick(0),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('كاميرا'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => pick(1),
            icon: const Icon(Icons.image_outlined),
            label: const Text('صورة'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => pick(2),
            icon: const Icon(Icons.attach_file),
            label: const Text('ملف'),
          ),
        ],
      ),
      ...widget.paths.map(
        (path) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              RegExp(
                r'\.(jpg|jpeg|png|webp)$',
                caseSensitive: false,
              ).hasMatch(path)
              ? Image.file(
                  File(path),
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (_, e, s) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : const Icon(Icons.description_outlined),
          title: Text(
            p.basename(path).split('_').skip(1).join('_'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => openAttachment(c, path),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                widget.onChanged(widget.paths.where((s) => s != path).toList()),
          ),
        ),
      ),
    ],
  );
}

Future<void> openAttachment(BuildContext c, String path) async {
  if (RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(path)) {
    await Navigator.push(
      c,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('معاينة الصورة')),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => const Text('الصورة غير متوفرة'),
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    final r = await OpenFilex.open(path);
    if (r.type != ResultType.done && c.mounted) message(c, r.message);
  }
}
