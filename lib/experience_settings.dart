import 'labels.dart';
import 'package:flutter/material.dart';
import 'store.dart';
import 'ui.dart';
import 'experience.dart';

class PackAppearancePage extends StatelessWidget {
  final Store s;
  const PackAppearancePage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) => Scaffold(
      appBar: const ClayAppBar(title: UiText('حزم الأشكال والمظهر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ServiceBanner(
            kind: 'ticket',
            title: activePack.name,
            subtitle: 'هوية متكاملة لكل التطبيق',
            height: 150,
          ),
          Section('حزم الأشكال', [
            for (final pack in visualPacks.values)
              ListTile(
                leading: const ArtIcon(9),
                title: UiText(pack.name),
                subtitle: const UiText(
                  'الرسومات • القوائم • الأزرار • النماذج • الحركة',
                ),
                trailing: (s.settings['visualPack'] ?? 'clay') == pack.id
                    ? const Icon(Icons.check_circle_rounded, color: teal)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () => s.set('visualPack', pack.id),
              ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: UiText(
                'تظهر حزم الأشكال الجديدة هنا عند إضافتها في تحديث قادم، وتستخدم بياناتك وتخصيصاتك نفسها.',
              ),
            ),
          ]),
          Section('الإضاءة', [
            ChoiceField<String>(
              initialValue:
                  s.settings['appearanceMode'] ??
                  (s.settings['dark'] == true ? 'dark' : 'light'),
              decoration: const InputDecoration(
                labelText: 'وضع المظهر',
                prefixIcon: Icon(Icons.brightness_6_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'light', child: UiText('نهاري')),
                DropdownMenuItem(value: 'dark', child: UiText('ليلي')),
                DropdownMenuItem(value: 'system', child: UiText('حسب الجهاز')),
              ],
              onChanged: (value) => s.set('appearanceMode', value),
            ),
          ]),
          Section('مساحة الواجهة', [
            ChoiceField<String>(
              initialValue: s.settings['uiDensity'] ?? 'normal',
              decoration: const InputDecoration(labelText: 'كثافة الواجهة'),
              items: const [
                DropdownMenuItem(value: 'compact', child: UiText('مدمجة')),
                DropdownMenuItem(value: 'normal', child: UiText('متوسطة')),
                DropdownMenuItem(value: 'spacious', child: UiText('واسعة')),
              ],
              onChanged: (v) async {
                await s.set('uiDensity', v);
                await s.set('compact', v == 'compact');
              },
            ),
            const UiText('حجم الرسومات والبطاقات الرئيسية'),
            Slider(
              min: .7,
              max: 1.2,
              divisions: 10,
              value: (s.settings['heroScale'] as num? ?? 1).toDouble().clamp(
                .7,
                1.2,
              ),
              onChanged: (v) => s.set('heroScale', v),
            ),
            if (activePack.id == 'glass') ...[
              const UiText('وضوح البطاقات الزجاجية'),
              Slider(
                min: .75,
                max: 1,
                divisions: 5,
                value: (s.settings['glassOpacity'] as num? ?? .92)
                    .toDouble()
                    .clamp(.75, 1),
                onChanged: (v) => s.set('glassOpacity', v),
              ),
            ],
          ]),
          Section('اللون والخط والحواف', [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final color in [
                  coral,
                  teal,
                  violet,
                  const Color(0xffd38d31),
                  Colors.indigo,
                  Colors.blue,
                  Colors.deepOrange,
                  Colors.green,
                  Colors.pink,
                  Colors.blueGrey,
                ])
                  Semantics(
                    label: 'اللون ${color.toARGB32()}',
                    selected:
                        s.settings['packAccent_${activePack.id}'] ==
                        color.toARGB32(),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => s.set(
                        'packAccent_${activePack.id}',
                        color.toARGB32(),
                      ),
                      icon: Icon(
                        s.settings['packAccent_${activePack.id}'] ==
                                color.toARGB32()
                            ? Icons.check
                            : Icons.palette_outlined,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const UiText('حجم الخط'),
            Slider(
              value: (s.settings['textScale'] as num? ?? 1).toDouble().clamp(
                .85,
                1.4,
              ),
              min: .85,
              max: 1.4,
              divisions: 11,
              label:
                  '${((s.settings['textScale'] as num? ?? 1) * 100).round()}٪',
              onChanged: (value) => s.set('textScale', value),
            ),
            const UiText('استدارة البطاقات'),
            Slider(
              value: (s.settings['packRadius'] as num? ?? 26).toDouble().clamp(
                16,
                32,
              ),
              min: 16,
              max: 32,
              divisions: 8,
              onChanged: (value) => s.set('packRadius', value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.view_compact_alt_outlined),
              title: const UiText('قوائم مدمجة'),
              value: s.settings['compact'] == true,
              onChanged: (value) => s.set('compact', value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.speed_rounded),
              title: const UiText('رسومات خفيفة'),
              subtitle: const UiText(
                'أيقونات واضحة بدل الرسومات المجسّمة والخلفيات',
              ),
              value: s.settings['liteGraphics'] == true,
              onChanged: (value) => s.set('liteGraphics', value),
            ),
          ]),
          Section('الرسومات والعناوين', [
            const UiText('وضوح خلفيات الخدمات'),
            Slider(
              value: (s.settings['artStrength'] as num? ?? 1).toDouble().clamp(
                0,
                1,
              ),
              onChanged: (value) => s.set('artStrength', value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.translate_rounded),
              title: const UiText('إظهار العناوين الإنجليزية الثانوية'),
              value: s.settings['showEnglishLabels'] != false,
              onChanged: (value) => s.set('showEnglishLabels', value),
            ),
          ]),
          TextButton.icon(
            onPressed: () async {
              await s.set('packAccent_${activePack.id}', null);
              await s.set('packRadius', activePack.radius);
              await s.set('textScale', 1);
              await s.set('appearanceMode', 'light');
              await s.set('liteGraphics', false);
              await s.set('artStrength', 1);
            },
            icon: const Icon(Icons.restart_alt),
            label: const UiText('استعادة مظهر الحزمة'),
          ),
        ],
      ),
    ),
  );
}

class ExperienceSettingsPage extends StatelessWidget {
  final Store s;
  final String initial;
  const ExperienceSettingsPage(this.s, {super.key, this.initial = 'sound'});
  Widget toggle(
    String title,
    String key,
    IconData icon, {
    String? subtitle,
    bool fallback = true,
  }) => SwitchListTile(
    title: UiText(title),
    subtitle: subtitle == null ? null : UiText(subtitle),
    secondary: Icon(icon),
    value: s.settings[key] as bool? ?? fallback,
    onChanged: (value) => s.set(key, value),
  );
  Widget eventOptions(String kind) => Wrap(
    spacing: 8,
    runSpacing: 5,
    children: [
      for (final event in Experience.events)
        FilterChip(
          label: UiText(Experience.eventLabels[event]!),
          selected: s.settings['${kind}_$event'] != false,
          onSelected: (value) => s.set('${kind}_$event', value),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) => DefaultTabController(
      length: 3,
      initialIndex: ['sound', 'haptic', 'gesture'].indexOf(initial).clamp(0, 2),
      child: Scaffold(
        appBar: const ClayAppBar(
          title: UiText('الصوت والاهتزاز والإيماءات'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.volume_up_rounded), text: 'الصوت'),
              Tab(icon: Icon(Icons.vibration_rounded), text: 'الاهتزاز'),
              Tab(icon: Icon(Icons.swipe_rounded), text: 'الإيماءات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(child: ArtIcon(10, size: 100)),
                Section('الصوت', [
                  toggle(
                    'تفعيل المؤثرات الصوتية',
                    'soundEnabled',
                    Icons.volume_up_rounded,
                    subtitle: 'أصوات محلية قصيرة تحترم الوضع الصامت للجهاز',
                  ),
                  const UiText('مستوى الصوت'),
                  Slider(
                    value: (s.settings['soundVolume'] as num? ?? .25)
                        .toDouble()
                        .clamp(0, 1),
                    onChanged: (value) => s.set('soundVolume', value),
                  ),
                  ChoiceField<String>(
                    initialValue: s.settings['soundStyle'] ?? 'silk',
                    decoration: const InputDecoration(
                      labelText: 'طابع الصوت',
                      prefixIcon: Icon(Icons.music_note_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'silk',
                        child: UiText('نسيم هادئ'),
                      ),
                      DropdownMenuItem(
                        value: 'wood',
                        child: UiText('نقرات خشبية'),
                      ),
                      DropdownMenuItem(
                        value: 'crystal',
                        child: UiText('زجاج كريستالي'),
                      ),
                      DropdownMenuItem(
                        value: 'water',
                        child: UiText('قطرات ناعمة'),
                      ),
                      DropdownMenuItem(value: 'soft', child: UiText('ناعم')),
                      DropdownMenuItem(value: 'pop', child: UiText('مرح')),
                      DropdownMenuItem(
                        value: 'bell',
                        child: UiText('رنين خفيف'),
                      ),
                    ],
                    onChanged: (value) => s.set('soundStyle', value),
                  ),
                  const SizedBox(height: 12),
                  eventOptions('sound'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final event in Experience.events)
                        OutlinedButton.icon(
                          onPressed: () =>
                              Experience.fire(event, preview: 'sound'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: UiText(Experience.eventLabels[event]!),
                        ),
                    ],
                  ),
                ]),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(child: ArtIcon(11, size: 100)),
                Section('الاهتزاز', [
                  toggle(
                    'تفعيل الاهتزاز',
                    'hapticEnabled',
                    Icons.vibration_rounded,
                  ),
                  const UiText('قوة الاهتزاز'),
                  Slider(
                    value: (s.settings['hapticIntensity'] as num? ?? .45)
                        .toDouble()
                        .clamp(0, 1),
                    onChanged: (value) => s.set('hapticIntensity', value),
                  ),
                  eventOptions('haptic'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Experience.fire('save', preview: 'haptic'),
                    icon: const Icon(Icons.vibration_rounded),
                    label: const UiText('تجربة الاهتزاز'),
                  ),
                ]),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(child: ArtIcon(12, size: 100)),
                Section('حيوية الواجهة', [
                  ChoiceField<int>(
                    initialValue: (s.settings['ambientLevel'] as num? ?? 2)
                        .toInt(),
                    decoration: const InputDecoration(
                      labelText: 'مستوى الحيوية',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: UiText('متوقفة')),
                      DropdownMenuItem(value: 1, child: UiText('هادئة')),
                      DropdownMenuItem(value: 2, child: UiText('متوسطة')),
                      DropdownMenuItem(value: 3, child: UiText('واضحة')),
                    ],
                    onChanged: (v) => s.set('ambientLevel', v),
                  ),
                  toggle('حركة الأيقونات', 'ambientIcons', Icons.animation),
                  toggle(
                    'حركة الرسومات والخلفيات',
                    'ambientBackgrounds',
                    Icons.landscape_outlined,
                  ),
                  toggle(
                    'انتقال الأرقام عند تغيّرها',
                    'animateNumbers',
                    Icons.numbers,
                  ),
                  const UiText('سرعة الحركة'),
                  Slider(
                    min: .5,
                    max: 2,
                    divisions: 6,
                    value: (s.settings['ambientSpeed'] as num? ?? 1)
                        .toDouble()
                        .clamp(.5, 2),
                    onChanged: (v) => s.set('ambientSpeed', v),
                  ),
                ]),
                Section('التنقل والحركة', [
                  toggle(
                    'السحب بين الصفحات الرئيسية',
                    'swipeTabs',
                    Icons.swipe_rounded,
                    subtitle:
                        'اسحب من طرف شريط التنقل؛ داخل النماذج تبقى حركة التمرير طبيعية',
                  ),
                  toggle(
                    'السحب على بطاقة العملية',
                    'swipeCards',
                    Icons.swipe_left_alt_rounded,
                    subtitle:
                        'يُظهر اختصارات العرض والتعديل، ويظل الاعتماد داخل النموذج',
                  ),
                  toggle(
                    'حركة الضغط على البطاقات',
                    'pressMotion',
                    Icons.touch_app_rounded,
                  ),
                  toggle(
                    'تقليل الحركة',
                    'reduceMotion',
                    Icons.accessibility_new_rounded,
                    fallback: false,
                    subtitle: 'تُحترم أيضًا إعدادات تقليل الحركة في الجهاز',
                  ),
                  const UiText('إيقاع التنقل'),
                  ChoiceField<String>(
                    initialValue: s.settings['motionPace'] ?? 'smooth',
                    decoration: const InputDecoration(labelText: 'سرعة الحركة'),
                    items: const [
                      DropdownMenuItem(
                        value: 'smooth',
                        child: UiText('انسيابي'),
                      ),
                      DropdownMenuItem(value: 'quick', child: UiText('سريع')),
                    ],
                    onChanged: (value) => s.set('motionPace', value),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
