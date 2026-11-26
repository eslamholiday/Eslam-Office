import 'package:flutter/material.dart';
import 'domain.dart';
import 'input_schema.dart';
import 'input_settings.dart';
import 'labels.dart';
import 'label_catalog.dart';
import 'store.dart';
import 'ui.dart';

Future<int?> chooseUiIcon(BuildContext context, int selected) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
          itemCount: 68,
          itemBuilder: (_, index) => InkWell(
            onTap: () => Navigator.pop(ctx, index),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: index == selected
                    ? Theme.of(ctx).colorScheme.primaryContainer
                    : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: ArtIcon(index, size: 58)),
            ),
          ),
        ),
      ),
    );

class UiLabelsPage extends StatefulWidget {
  final Store s;
  const UiLabelsPage(this.s, {super.key});
  @override
  State<UiLabelsPage> createState() => _UiLabelsPageState();
}

class _UiLabelsPageState extends State<UiLabelsPage> {
  String query = '', group = 'الرئيسية والتنقل';
  Future<void> edit(String original) async {
    final controller = TextEditingController(text: uiLabel(original));
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const UiText('تعديل التسمية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiText('الاسم الأصلي: $original'),
            const SizedBox(height: 12),
            textField(controller, 'الاسم الذي يظهر في التطبيق'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const UiText('استعادة الأصلي'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const UiText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const UiText('حفظ'),
          ),
        ],
      ),
    );
    if (value != null) {
      final labels = Map<String, dynamic>.from(
        widget.s.settings['uiLabels'] ?? {},
      );
      if (value.isEmpty || value == original) {
        labels.remove(original);
      } else {
        labels[original] = value;
      }
      await widget.s.set('uiLabels', labels);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.s,
    builder: (context, _) => DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const ClayAppBar(
          title: UiText('العناوين ومحتويات القوائم'),
          bottom: TabBar(
            tabs: [
              Tab(child: UiText('العناوين')),
              Tab(child: UiText('الخيارات')),
              Tab(child: UiText('الحقول')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: ChoiceField<String>(
                    initialValue: group,
                    decoration: const InputDecoration(
                      labelText: 'مجموعة العناوين',
                    ),
                    items: uiLabelGroups.keys
                        .map(
                          (g) => DropdownMenuItem(value: g, child: UiText(g)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => group = value!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث في كل العناوين والأزرار والحالات',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = normalize(v)),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children:
                        (query.isEmpty ? uiLabelGroups[group]! : uiLabelCatalog)
                            .where(
                              (v) =>
                                  normalize('$v ${uiLabel(v)}').contains(query),
                            )
                            .map(
                              (original) => ListTile(
                                leading: IconButton(
                                  tooltip: 'اختيار الأيقونة',
                                  icon: ArtIcon(
                                    (widget.s.settings['uiIcons']
                                                as Map?)?[original]
                                            as int? ??
                                        titleArt(original),
                                    size: 32,
                                  ),
                                  onPressed: () async {
                                    final icon = await chooseUiIcon(
                                      context,
                                      titleArt(original),
                                    );
                                    if (icon != null) {
                                      await widget.s.set('uiIcons', {
                                        ...?widget.s.settings['uiIcons']
                                            as Map?,
                                        original: icon,
                                      });
                                    }
                                  },
                                ),
                                title: UiText(uiLabel(original)),
                                subtitle: uiLabel(original) == original
                                    ? null
                                    : UiText(original),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => edit(original),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
            ListView(
              children: [
                for (final entry in <String, InputSpec>{
                  for (final scope in inputScopes.keys)
                    for (final f in inputSpecs(scope))
                      if (f.choices.isNotEmpty) f.key: f,
                }.entries)
                  ListTile(
                    leading: ArtIcon(titleArt(entry.value.label), size: 36),
                    title: UiText(entry.value.label),
                    subtitle: const UiText(
                      'تسمية الخيارات وترتيبها وإظهارها وأيقوناتها',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChoiceOptionsPage(widget.s, entry.value),
                      ),
                    ),
                  ),
              ],
            ),
            ListView(
              children: inputScopes.entries
                  .map(
                    (e) => ListTile(
                      leading: ArtIcon(artIndex(e.key), size: 36),
                      title: UiText(e.value),
                      subtitle: const UiText('العناوين والترتيب والافتراضيات'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FormCustomizationPage(widget.s, e.key),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
