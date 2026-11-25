import 'labels.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'domain.dart';
import 'store.dart';
import 'visual_system.dart';
import 'experience.dart';
import 'geography.dart';
export 'visual_system.dart';

const navy = Color(0xFF123B5D), gold = Color(0xFFD4A84F);
IconData kindIcon(String kind) => switch (kind) {
  'ticket' => Icons.flight_takeoff_rounded,
  'change' => Icons.change_circle_outlined,
  'hotel' => Icons.hotel_rounded,
  'visa' => Icons.badge_rounded,
  'settlement' => Icons.swap_horiz_rounded,
  'expense' => Icons.receipt_long_rounded,
  'refund' => Icons.undo_rounded,
  _ => Icons.account_balance_wallet_rounded,
};
// Stable option keys own their default artwork; renaming a caption does not change its meaning.
const choiceArtwork = <String, Map<String, int>>{
  'paymentMethod': {
    'cash': 14,
    'bank': 6,
    'card': 20,
    'wallet': 3,
    'credit': 22,
  },
  'settlementMode': {'cash': 14, 'adjustment': 22},
  'direction': {'-1': 4, '1': 7},
  'currency': {'USD': 14, 'IQD': 3},
  'partyType': {'customer': 20, 'supplier': 6},
  'travelerType': {'ADT': 16, 'CHD': 17, 'INF': 18},
  'ticketType': {'ticket': 0, 'change': 4},
  'tripType': {'oneWay': 0, 'roundTrip': 21},
  'commissionMode': {'percent': 22, 'fee': 14},
};
int choiceArt(String? field, Object? value, String caption) =>
    ((displayPreferences['choices_$field'] as Map?)?['icons'] as Map?)?[value
            ?.toString()]
        as int? ??
    (displayPreferences['uiIcons'] as Map?)?[caption] as int? ??
    choiceArtwork[field]?[value?.toString()] ??
    titleArt(caption);

Color kindColor(String kind) =>
    kind == 'refund' ? const Color(0xffba5959) : artColor(artIndex(kind));
void message(BuildContext c, Object e) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      content: UiText(e.toString().replaceFirst('FormatException: ', '')),
    ),
  );
}

Future<void> guarded(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    unawaited(Experience.fire('error'));
    if (c.mounted) message(c, e);
  }
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final bool collapsible;
  final bool initiallyExpanded;
  final String? subtitle;
  const Section(
    this.title,
    this.children, {
    super.key,
    this.trailing,
    this.collapsible = false,
    this.initiallyExpanded = false,
    this.subtitle,
  });
  @override
  Widget build(BuildContext c) {
    LabelScope.watch(c);
    return collapsible
        ? Card(
            child: ExpansionTile(
              leading: ArtIcon(
                (displayPreferences['uiIcons'] as Map?)?[title] as int? ??
                    titleArt(title),
                size: 34,
              ),
              initiallyExpanded: initiallyExpanded,
              maintainState: true,
              subtitle: subtitle == null
                  ? null
                  : UiText(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              title: UiText(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              childrenPadding: EdgeInsets.all(
                displayPreferences['compactForms'] == true ? 10 : 16,
              ),
              children: children,
            ),
          )
        : Card(
            child: Padding(
              padding: EdgeInsets.all(
                displayPreferences['compactForms'] == true ? 10 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ArtIcon(
                        (displayPreferences['uiIcons'] as Map?)?[title]
                                as int? ??
                            titleArt(title),
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: UiText(
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
        const ArtIcon(15, size: 100),
        const SizedBox(height: 18),
        UiText(
          title,
          style: Theme.of(c).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        UiText(
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
              label: const UiText('إضافة'),
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
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          (color ?? Theme.of(c).colorScheme.secondary).withValues(alpha: .16),
          (color ?? Theme.of(c).colorScheme.secondary).withValues(alpha: .04),
        ],
      ),
      border: Border.all(
        color: (color ?? Theme.of(c).colorScheme.secondary).withValues(
          alpha: .2,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(label, style: Theme.of(c).textTheme.labelLarge),
        const SizedBox(height: 8),
        FittedBox(
          child: UiText(
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
    final decimal = normalized.contains('.')
        ? '.${normalized.split('.').skip(1).join().replaceAll(RegExp(r'[^0-9]'), '')}'
        : '';
    final formatted = '${NumberFormat('#,##0', 'en').format(value)}$decimal';
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
    decoration: InputDecoration(
      labelText: uiLabel(label),
      prefixIcon: Icon(fieldIcon(label)),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
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
          labelText: uiLabel(label),
          prefixIcon: Icon(fieldIcon(label)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: value != null && optional
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.expand_more),
        ),
        child: UiText(
          value == null ? 'اختر التاريخ' : displayDate(value),
          style: value == null ? const TextStyle(color: Colors.grey) : null,
        ),
      ),
    ),
  );
}

Future<int?> chooseListItem(
  BuildContext context,
  String label,
  List<Map<String, dynamic>> items,
  int? selected, {
  bool add = false,
  Store? store,
  String? listKey,
}) async {
  var query = '';
  final favorites = List<int>.from(store?.settings['favorites_$listKey'] ?? []);
  final recent = List<int>.from(store?.settings['recent_$listKey'] ?? []);
  final showFavorites = store?.settings['pickerFavorites'] != false;
  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final rows = items
            .where(
              (r) => normalize(
                '${r['name']} ${r['phone'] ?? ''} ${r['code'] ?? ''}',
              ).contains(normalize(query)),
            )
            .toList();
        final sort =
            store?.settings['pickerSort'] ??
            (store == null ? 'original' : 'recent');
        if (sort != 'original') {
          rows.sort((a, b) {
            if (sort == 'recent' && showFavorites) {
              int rank(Map<String, dynamic> r) => favorites.contains(r['id'])
                  ? -10000 + favorites.indexOf(r['id'])
                  : recent.contains(r['id'])
                  ? recent.indexOf(r['id'])
                  : 10000;
              final cmp = rank(a).compareTo(rank(b));
              if (cmp != 0) {
                return cmp;
              }
            }
            return sort == 'name'
                ? '${a['name']}'.compareTo('${b['name']}')
                : items.indexOf(a).compareTo(items.indexOf(b));
          });
        }
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * .65,
              child: Column(
                children: [
                  UiText(label, style: Theme.of(ctx).textTheme.titleLarge),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'بحث في القائمة',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => set(() => query = v),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, -1),
                        child: const UiText('بدون اختيار'),
                      ),
                      if (add)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(ctx, -2),
                          icon: const Icon(Icons.add),
                          label: const UiText('إضافة جديد'),
                        ),
                    ],
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: UiText('لا توجد نتائج'))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (ctx, i) {
                              final r = rows[i];
                              return ListTile(
                                title: Row(
                                  children: [
                                    CountryBadge(GeoCatalog.recordCode(r)),
                                    if (GeoCatalog.recordCode(r) != null)
                                      const SizedBox(width: 8),
                                    Expanded(child: UiText('${r['name']}')),
                                  ],
                                ),
                                subtitle: r['phone'] != null && r['phone'] != ''
                                    ? UiText('${r['phone']}')
                                    : r['code'] != null && r['code'] != ''
                                    ? UiText('${r['code']}')
                                    : null,
                                leading: selected == r['id']
                                    ? const Icon(Icons.check_circle_outline)
                                    : null,
                                trailing: store != null && showFavorites
                                    ? IconButton(
                                        tooltip: 'المفضلة',
                                        icon: Icon(
                                          favorites.contains(r['id'])
                                              ? Icons.star
                                              : Icons.star_border,
                                        ),
                                        onPressed: () async {
                                          set(() {
                                            favorites.contains(r['id'])
                                                ? favorites.remove(r['id'])
                                                : favorites.add(r['id'] as int);
                                          });
                                          await store.set(
                                            'favorites_$listKey',
                                            favorites,
                                          );
                                        },
                                      )
                                    : null,
                                onTap: () => Navigator.pop(ctx, r['id'] as int),
                              );
                            },
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
  if (result != null && result >= 0 && store != null) {
    unawaited(
      store
          .set(
            'recent_$listKey',
            [result, ...recent.where((id) => id != result)].take(15).toList(),
          )
          .catchError((Object _) {}),
    );
  }
  return result;
}

class PickField extends StatelessWidget {
  final String label;
  final int? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;
  final Future<int?> Function()? add;
  final Store? store;
  final String? listKey;
  const PickField(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    super.key,
    this.add,
    this.store,
    this.listKey,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        final result = await chooseListItem(
          c,
          label,
          items,
          value,
          add: add != null,
          store: store,
          listKey: listKey ?? label,
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
          labelText: uiLabel(label),
          prefixIcon: Icon(fieldIcon(label)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  tooltip: 'مسح الاختيار',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
        child: Row(
          children: [
            CountryBadge(
              GeoCatalog.recordCode(
                items.where((r) => r['id'] == value).firstOrNull ?? {},
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: UiText(
                items.where((r) => r['id'] == value).firstOrNull?['name'] ??
                    'اختياري',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const profileAvatars = <String>[
  '👨‍💼',
  '👩‍💼',
  '🧑‍💼',
  '👨🏻‍💼',
  '👩🏻‍💼',
  '👨🏽‍💼',
  '👩🏽‍💼',
  '👨🏿‍💼',
  '👩🏿‍💼',
  '🧑🏻‍💼',
  '👨‍✈️',
  '👩‍✈️',
  '🧑‍✈️',
  '👨🏻‍✈️',
  '👩🏻‍✈️',
  '👨🏽‍✈️',
  '👩🏽‍✈️',
  '👨🏿‍✈️',
  '👩🏿‍✈️',
  '🧑🏻‍✈️',
  '🧳',
  '✈️',
  '🌍',
  '🏨',
  '🛂',
  '🧑‍🚀',
  '👨‍🎓',
  '👩‍🎓',
  '🧑‍🎓',
  '🙂',
];

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String? avatar;
  final String? name;
  final double radius;
  const ProfileAvatar({
    super.key,
    this.imagePath,
    this.avatar,
    this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final file = imagePath == null || imagePath!.isEmpty
        ? null
        : File(imagePath!);
    final hasImage = file != null && file.existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .12),
      backgroundImage: hasImage ? FileImage(file) : null,
      child: hasImage
          ? null
          : UiText(
              avatar?.isNotEmpty == true
                  ? avatar!
                  : (name?.trim().isNotEmpty == true
                        ? name!
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((v) => v.characters.first)
                              .join()
                        : '👤'),
              style: TextStyle(fontSize: radius * .95),
            ),
    );
  }
}

class ProfilePicker extends StatelessWidget {
  final String? imagePath;
  final String? avatar;
  final void Function(String? imagePath, String? avatar) onChanged;
  const ProfilePicker({
    super.key,
    this.imagePath,
    this.avatar,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
      );
      if (picked == null) {
        return;
      }
      final base = (await getApplicationDocumentsDirectory()).path;
      final dir = Directory('$base/profiles');
      await dir.create(recursive: true);
      final target =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${p.basename(picked.path)}';
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
      Center(
        child: ProfileAvatar(imagePath: imagePath, avatar: avatar, radius: 42),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pick(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_outlined),
            label: const UiText('رفع صورة'),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const UiText('كاميرا'),
          ),
          if ((imagePath?.isNotEmpty ?? false) || (avatar?.isNotEmpty ?? false))
            TextButton.icon(
              onPressed: () => onChanged(null, null),
              icon: const Icon(Icons.delete_outline),
              label: const UiText('إزالة'),
            ),
        ],
      ),
      const SizedBox(height: 10),
      const UiText('أو اختر شخصية / ستكر'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: profileAvatars
            .map(
              (v) => ChoiceChip(
                label: UiText(v, style: const TextStyle(fontSize: 22)),
                selected: imagePath == null && avatar == v,
                onSelected: (_) => onChanged(null, v),
              ),
            )
            .toList(),
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
      if (mounted) {
        setState(() => busy = false);
      }
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
            label: const UiText('كاميرا'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => pick(1),
            icon: const Icon(Icons.image_outlined),
            label: const UiText('صورة'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => pick(2),
            icon: const Icon(Icons.attach_file),
            label: const UiText('ملف'),
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
          title: UiText(
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
          appBar: ClayAppBar(title: const UiText('معاينة الصورة')),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => const UiText('الصورة غير متوفرة'),
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

class ChoiceField<T> extends StatelessWidget {
  final bool isExpanded;
  final String? fieldKey;
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final VoidCallback? onClear;
  const ChoiceField({
    super.key,
    this.isExpanded = true,
    this.fieldKey,
    this.initialValue,
    this.items,
    this.onChanged,
    this.decoration,
    this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    final selected = items?.where((i) => i.value == initialValue).firstOrNull;
    return Semantics(
      container: true,
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () async {
                var query = '';
                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, set) => SafeArea(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(ctx).height * .65,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            MediaQuery.viewInsetsOf(ctx).bottom,
                          ),
                          child: Column(
                            children: [
                              UiText(
                                decoration?.labelText ?? 'اختر من القائمة',
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                              if ((items?.length ?? 0) > 5)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'بحث',
                                    ),
                                    onChanged: (v) =>
                                        set(() => query = normalize(v)),
                                  ),
                                ),
                              Expanded(
                                child: ListView(
                                  children: (items ?? <DropdownMenuItem<T>>[])
                                      .where(
                                        (i) =>
                                            query.isEmpty ||
                                            normalize(
                                              uiLabel(widgetCaption(i.child)),
                                            ).contains(query),
                                      )
                                      .map(
                                        (i) => ListTile(
                                          leading: ArtIcon(
                                            choiceArt(
                                              fieldKey,
                                              i.value,
                                              widgetCaption(i.child),
                                            ),
                                            size: 30,
                                          ),
                                          title: i.child,
                                          trailing: i.value == initialValue
                                              ? const Icon(
                                                  Icons.check_circle_outline,
                                                )
                                              : null,
                                          onTap: () {
                                            onChanged?.call(i.value);
                                            Navigator.pop(ctx);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
        child: InputDecorator(
          decoration: (decoration ?? const InputDecoration()).copyWith(
            labelText: decoration?.labelText == null
                ? null
                : uiLabel(decoration!.labelText!),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: onClear == null
                ? const Icon(Icons.expand_more)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'مسح الاختيار',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: onClear,
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
          ),
          child: selected?.child ?? const UiText('اختياري'),
        ),
      ),
    );
  }
}
