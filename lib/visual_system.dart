import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'office_material.dart';
export 'office_material.dart';
import 'ambient_motion.dart';
import 'labels.dart';

// A pack owns artwork, colors, geometry and motion together. Future packs plug
// into this registry without rewriting forms, routes or the accounting model.
class VisualPack {
  final String id, name, icons, scenes;
  final String? extraIcons;
  final Color primary, secondary, canvas, surface;
  final double radius,
      fieldRadius,
      buttonRadius,
      heroRadius,
      elevation,
      routeOffset;
  final Curve motionCurve;
  final List<Color> categoryColors;
  final bool ticketCutouts;
  const VisualPack({
    required this.id,
    required this.name,
    required this.icons,
    this.extraIcons,
    required this.scenes,
    required this.primary,
    required this.secondary,
    required this.canvas,
    required this.surface,
    required this.radius,
    this.fieldRadius = 18,
    this.buttonRadius = 20,
    this.heroRadius = 28,
    this.elevation = 3,
    this.routeOffset = .08,
    this.motionCurve = Curves.easeOutCubic,
    this.ticketCutouts = true,
    this.categoryColors = const [
      Color(0xff089b9e),
      Color(0xff9b68cf),
      Color(0xffdf945a),
      Color(0xffef635a),
    ],
  });
}

const visualPacks = <String, VisualPack>{
  'office': VisualPack(
    id: 'office',
    extraIcons: 'assets/visuals/clay/icons_extra.webp',
    name: 'المكتب المجسّم',
    icons: 'assets/visuals/clay/icons.webp',
    scenes: 'assets/visuals/clay/scenes.webp',
    primary: Color(0xff174632),
    secondary: Color(0xff986c2b),
    canvas: Color(0xff56321f),
    surface: Color(0xfff4e8d0),
    radius: 16,
    fieldRadius: 10,
    buttonRadius: 10,
    heroRadius: 16,
    elevation: 4,
    routeOffset: .035,
    categoryColors: [
      Color(0xff174632),
      Color(0xff8a3a29),
      Color(0xff92632f),
      Color(0xff39634b),
    ],
  ),
  'glass': VisualPack(
    id: 'glass',
    name: 'الفضاء الهادئ',
    icons: 'assets/visuals/glass/icons.webp',
    extraIcons: 'assets/visuals/glass/icons_extra.webp',
    scenes: 'assets/visuals/glass/scenes.webp',
    primary: Color(0xff2867d8),
    secondary: Color(0xff159c9b),
    canvas: Color(0xffe7efff),
    surface: Color(0xfff4f8ff),
    radius: 24,
    fieldRadius: 17,
    buttonRadius: 22,
    heroRadius: 28,
    elevation: 3,
    routeOffset: .06,
    categoryColors: [
      Color(0xff316fdc),
      Color(0xff8270d4),
      Color(0xff2c9ba6),
      Color(0xff3a76c8),
    ],
  ),
  'clay': VisualPack(
    id: 'clay',
    name: 'المجسّمات الملونة',
    icons: 'assets/visuals/clay/icons.webp',
    extraIcons: 'assets/visuals/clay/icons_extra.webp',
    scenes: 'assets/visuals/clay/scenes.webp',
    primary: Color(0xffef635a),
    secondary: Color(0xff089b9e),
    canvas: Color(0xffffefe4),
    surface: Color(0xfffffaf2),
    radius: 26,
  ),
};
VisualPack get activePack =>
    visualPacks[displayPreferences['visualPack']] ?? visualPacks['clay']!;
bool get officeTheme => activePack.id == 'office';
const coral = Color(0xffef635a),
    teal = Color(0xff089b9e),
    violet = Color(0xff9b68cf);
bool get illustrationsEnabled => displayPreferences['liteGraphics'] != true;
int artIndex(String kind) => switch (kind) {
  'home' => 26,
  'ticket' || 'change' => 0,
  'visa' => 1,
  'hotel' => 2,
  'expense' || 'owed' => 3,
  'settlement' || 'refund' => 4,
  'customer' || 'customers' => 20,
  'passenger' => 19,
  'adult' => 16,
  'child' => 17,
  'infant' => 18,
  'opening' || 'funding' => 14,
  'supplier' || 'payable' => 6,
  'profit' || 'reports' => 7,
  'settings' => 8,
  'appearance' => 9,
  'sound' => 10,
  'haptic' => 11,
  'gesture' => 12,
  'statements' || 'review' || 'operations' => 13,
  'expenses' => 14,
  _ => 15,
};
int captionArt(String text, {int? fallback}) =>
    (displayPreferences['uiIcons'] as Map?)?[text] as int? ??
    fallback ??
    titleArt(text);
int titleArt(String text) {
  if (text.contains('العمليات') || text.contains('الحركات')) return 13;
  if (text.contains('بالغ')) return 16;
  if (text.contains('طفل')) return 17;
  if (text.contains('رضيع')) return 18;
  if (text.contains('مسافر')) return 19;
  if (text.contains('زبون') ||
      text.contains('زبائن') ||
      text.contains('ملف الحساب')) {
    return 20;
  }
  if (text.contains('تفاصيل السفر') || text.contains('الوجهة')) return 21;
  if (text.contains('معلومات العملية') || text.contains('البيانات الأساسية')) {
    return 13;
  }
  if (text.contains('عمولة') || text.contains('النتيجة')) return 22;
  if (text.contains('ملاحظ') || text.contains('مرفقات')) return 23;
  if (text.contains('تاريخ') ||
      text.contains('الفترة') ||
      text.contains('الإضاءة')) {
    return 24;
  }
  if (text.contains('أعلام') || text.contains('دول') || text.contains('مدن')) {
    return 25;
  }
  if (text.contains('قوالب')) return 31;
  if (text.contains('الرئيسية')) return 26;
  if (text.contains('تذكر') ||
      text.contains('تذاكر') ||
      text.contains('طيران')) {
    return 0;
  }
  if (text.contains('فيز')) {
    return 1;
  }
  if (text.contains('فندق') || text.contains('فنادق')) {
    return 2;
  }
  if (text.contains('مصروف') || text.contains('مصاري')) {
    return 3;
  }
  if (text.contains('تسوية') || text.contains('تغيير')) {
    return 4;
  }
  if (text.contains('مسافر') ||
      text.contains('زبون') ||
      text.contains('زبائن') ||
      text.contains('بالغ') ||
      text.contains('طفل') ||
      text.contains('رضيع')) {
    return 5;
  }
  if (text.contains('مكتب') || text.contains('إصدار')) {
    return 6;
  }
  if (text.contains('ربح') ||
      text.contains('تقارير') ||
      text.contains('نتيجة')) {
    return 7;
  }
  if (text.contains('مظهر') || text.contains('ثيم') || text.contains('شكل')) {
    return 9;
  }
  if (text.contains('صوت')) {
    return 10;
  }
  if (text.contains('اهتزاز')) {
    return 11;
  }
  if (text.contains('تنقل') || text.contains('إيماء')) {
    return 12;
  }
  if (text.contains('كشف') ||
      text.contains('كشوف') ||
      text.contains('تاريخ') ||
      text.contains('ملاحظ')) {
    return 13;
  }
  if (text.contains('عمولة') ||
      text.contains('أرقام') ||
      text.contains('تسديد') ||
      text.contains('سعر')) {
    return 14;
  }
  if (text.contains('أرشيف') || text.contains('محذوف')) {
    return 15;
  }
  return 8;
}

Color artColor(int index) =>
    activePack.categoryColors[switch (index) {
      0 || 3 || 4 || 6 || 14 => 0,
      1 || 7 || 8 || 9 || 11 || 12 => 1,
      2 => 2,
      _ => 3,
    }];
IconData fieldIcon(String label) {
  if (label.contains('العدد') || label.contains('عدد')) {
    return Icons.numbers_rounded;
  }
  if (label.contains('اسم') ||
      label.contains('مسافر') ||
      label.contains('زبون') ||
      label.contains('العدد')) {
    return Icons.person_outline_rounded;
  }
  if (label.contains('هاتف') || label.contains('واتساب')) {
    return Icons.phone_rounded;
  }
  if (label.contains('تاريخ') || label.contains('يوم')) {
    return Icons.calendar_month_rounded;
  }
  if (label.contains('مغادرة') || label.contains('ذهاب')) {
    return Icons.flight_takeoff_rounded;
  }
  if (label.contains('وصول') || label.contains('عودة')) {
    return Icons.flight_land_rounded;
  }
  if (label.contains('سعر') ||
      label.contains('مبلغ') ||
      label.contains('عملة') ||
      label.contains('عمولة')) {
    return Icons.payments_outlined;
  }
  if (label.contains('دولة') || label.contains('مدينة')) {
    return Icons.location_on_outlined;
  }
  return Icons.edit_note_rounded;
}

class _AtlasCache {
  static final Map<String, Future<ui.Image>> images = {};
  static Future<ui.Image> load(String path) =>
      images.putIfAbsent(path, () async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        return image;
      });
}

class AtlasArt extends StatelessWidget {
  final String asset;
  final int index, columns;
  final bool mirror;
  final BoxFit fit;
  const AtlasArt({
    super.key,
    required this.asset,
    required this.index,
    required this.columns,
    this.mirror = false,
    this.fit = BoxFit.contain,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FutureBuilder<ui.Image>(
      future: _AtlasCache.load(asset),
      builder: (_, snapshot) => snapshot.hasData
          ? CustomPaint(
              painter: _AtlasPainter(
                snapshot.data!,
                index,
                columns,
                mirror,
                fit,
              ),
              size: Size.infinite,
            )
          : const SizedBox.expand(),
    ),
  );
}

class _AtlasPainter extends CustomPainter {
  final ui.Image image;
  final int index, columns;
  final bool mirror;
  final BoxFit fit;
  const _AtlasPainter(
    this.image,
    this.index,
    this.columns,
    this.mirror,
    this.fit,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(image.width / columns, image.height / columns);
    final fitted = applyBoxFit(fit, cell, size);
    final source = Alignment.center
        .inscribe(fitted.source, Offset.zero & cell)
        .shift(
          Offset(
            (index % columns) * cell.width,
            (index ~/ columns) * cell.height,
          ),
        );
    final target = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AtlasPainter old) =>
      old.image != image ||
      old.index != index ||
      old.mirror != mirror ||
      old.fit != fit;
}

IconData officeIcon(int index) => switch (index) {
  0 => Icons.flight,
  1 => Icons.badge_outlined,
  2 => Icons.hotel,
  3 || 14 => Icons.account_balance_wallet_outlined,
  4 => Icons.swap_horiz,
  5 => Icons.people,
  6 => Icons.business,
  7 => Icons.bar_chart,
  8 => Icons.settings,
  9 => Icons.palette_outlined,
  10 => Icons.volume_up,
  11 => Icons.vibration,
  12 => Icons.swipe,
  13 => Icons.receipt_long,
  15 => Icons.inventory_2_outlined,
  16 => Icons.person,
  17 => Icons.child_care,
  18 => Icons.child_friendly,
  19 => Icons.luggage,
  20 => Icons.badge,
  21 => Icons.route,
  22 => Icons.calculate_outlined,
  23 => Icons.notes,
  24 => Icons.calendar_month,
  25 => Icons.public,
  26 => Icons.home,
  27 => Icons.save,
  28 => Icons.search,
  29 => Icons.filter_alt,
  30 => Icons.fact_check,
  _ => Icons.edit_document,
};

class ArtIcon extends StatelessWidget {
  final int index;
  final double size;
  const ArtIcon(this.index, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) {
    LabelScope.watch(context);
    if (officeTheme) {
      return OfficeSurface(
        material: 3,
        radius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            officeIcon(index),
            color: const Color(0xff34271a),
            size: size * .62,
          ),
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: illustrationsEnabled
          ? AmbientMotion(
              seed: index,
              child: AtlasArt(
                asset: index >= 16
                    ? activePack.extraIcons ?? activePack.icons
                    : activePack.icons,
                index: index % 16,
                columns: 4,
              ),
            )
          : Icon(
              switch (index) {
                16 => Icons.person,
                17 => Icons.child_care,
                18 => Icons.baby_changing_station,
                19 => Icons.luggage,
                20 => Icons.badge_outlined,
                21 => Icons.route,
                22 => Icons.calculate_outlined,
                23 => Icons.notes,
                24 => Icons.calendar_month,
                25 => Icons.public,
                26 => Icons.home_rounded,
                27 => Icons.save,
                28 => Icons.search,
                29 => Icons.filter_alt,
                30 => Icons.fact_check,
                31 => Icons.edit_document,
                0 => Icons.flight,
                1 => Icons.badge,
                2 => Icons.hotel,
                3 => Icons.wallet,
                4 => Icons.swap_horiz,
                5 => Icons.people,
                6 => Icons.business,
                7 => Icons.bar_chart,
                9 => Icons.palette,
                10 => Icons.volume_up,
                11 => Icons.vibration,
                12 => Icons.swipe,
                13 => Icons.receipt_long,
                14 => Icons.paid,
                15 => Icons.archive,
                _ => Icons.settings,
              },
              size: size * .7,
              color: artColor(index),
            ),
    );
  }
}

class ClayTransitions extends PageTransitionsBuilder {
  const ClayTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (displayPreferences['reduceMotion'] == true ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0,
        displayPreferences['motionPace'] == 'quick' ? .55 : 1,
        curve: activePack.motionCurve,
      ),
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(-activePack.routeOffset, .015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData packTheme(Brightness brightness, Map<String, dynamic> preferences) {
  final pack = visualPacks[preferences['visualPack']] ?? visualPacks['clay']!;
  final dark = brightness == Brightness.dark;
  final glass = pack.id == 'glass';
  final accent =
      preferences['packAccent_${pack.id}'] ??
      (pack.id == 'clay' ? preferences['packAccent'] : null);
  final primary = accent is int ? Color(accent) : pack.primary;
  final radius = (preferences['packRadius'] as num? ?? pack.radius).toDouble();
  final surface = dark
      ? (glass ? const Color(0xff172846) : const Color(0xff302b39))
      : pack.surface.withValues(
          alpha: glass
              ? (preferences['glassOpacity'] as num? ?? .92).toDouble().clamp(
                  .75,
                  1,
                )
              : 1,
        );
  final ink = pack.id == 'office'
      ? (dark ? const Color(0xfff4e8d0) : const Color(0xff32291f))
      : dark
      ? (glass ? const Color(0xffeef5ff) : const Color(0xfffff0e4))
      : glass
      ? const Color(0xff1c3155)
      : const Color(0xff49394b);
  final border = dark
      ? (glass ? const Color(0xff3b5783) : const Color(0xff514455))
      : glass
      ? const Color(0xffc6d8f4)
      : const Color(0xffefd4bf);
  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: dark
            ? (glass ? const Color(0xff8abaff) : const Color(0xffff9d8e))
            : primary,
        secondary: dark ? const Color(0xff65d8d4) : pack.secondary,
        surface: surface,
        onSurface: ink,
        surfaceTint: Colors.transparent,
        onPrimary: dark
            ? (glass ? const Color(0xff102547) : const Color(0xff422c30))
            : Colors.white,
      );
  final theme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? (glass ? const Color(0xff0d192d) : const Color(0xff211e29))
        : pack.canvas,
    visualDensity: preferences['uiDensity'] == 'spacious'
        ? VisualDensity.comfortable
        : preferences['compact'] == true
        ? VisualDensity.compact
        : VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ClayTransitions(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ClayTransitions(),
        TargetPlatform.windows: ClayTransitions(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      foregroundColor: glass ? ink : Colors.white,
      backgroundColor: glass ? pack.canvas : pack.primary,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w800,
        fontSize: 21,
        color: glass ? ink : Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 1 : pack.elevation,
      shadowColor: dark ? Colors.black38 : const Color(0x337b493b),
      margin: EdgeInsets.only(
        bottom: preferences['uiDensity'] == 'compact'
            ? 8
            : preferences['uiDensity'] == 'spacious'
            ? 18
            : 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: dark ? border : Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? (glass ? const Color(0xff13233e) : const Color(0xff26232e))
          : glass
          ? const Color(0xffedf4ff)
          : const Color(0xfffff2e7),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: ink.withValues(alpha: .8),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      prefixIconColor: scheme.secondary,
      suffixIconColor: scheme.secondary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: preferences['compactForms'] == true ? 10 : 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pack.fieldRadius),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pack.fieldRadius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pack.fieldRadius),
        borderSide: BorderSide(color: scheme.secondary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shadowColor: primary.withValues(alpha: .4),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pack.buttonRadius),
          side: BorderSide(color: dark ? Colors.white12 : Colors.white54),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.secondary,
        backgroundColor: scheme.secondary.withValues(alpha: .09),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.secondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: ink.withValues(alpha: .7),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: .22),
      elevation: 8,
      height: 78,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      modalElevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xff53465b) : const Color(0xff49394b),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: border.withValues(alpha: .6)),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.secondary : border,
      ),
    ),
  );
  if (pack.id != 'office') return theme;
  final officeInk = dark ? const Color(0xfff4e8d0) : const Color(0xff32291f);
  final officePaper = dark ? const Color(0xff2c281f) : pack.surface;
  final officeScheme = theme.colorScheme.copyWith(
    primary: dark ? const Color(0xffb8d4b0) : primary,
    secondary: dark ? const Color(0xffd1b47a) : pack.secondary,
    onSurface: officeInk,
    surface: officePaper,
    onPrimary: dark ? const Color(0xff173828) : Colors.white,
  );
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: officeScheme,
    textTheme: theme.textTheme.apply(
      bodyColor: officeInk,
      displayColor: officeInk,
    ),
    cardTheme: theme.cardTheme.copyWith(
      color: officePaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffb39460)),
      ),
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      backgroundColor: dark ? const Color(0xff143426) : const Color(0xfff1e4c7),
      indicatorColor: const Color(0xffbca16b).withValues(alpha: .3),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      fillColor: dark ? const Color(0xff342d22) : const Color(0xfff7efd9),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: officeInk,
        fontSize: 13,
      ),
      prefixIconColor: officeScheme.secondary,
      suffixIconColor: officeScheme.secondary,
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      backgroundColor: officePaper,
    ),
    dialogTheme: theme.dialogTheme.copyWith(backgroundColor: officePaper),
    chipTheme: theme.chipTheme.copyWith(
      backgroundColor: officePaper,
      selectedColor: dark ? const Color(0xff31563d) : const Color(0xffb7c7a1),
      labelStyle: TextStyle(fontFamily: 'Cairo', color: officeInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff174632),
        foregroundColor: const Color(0xfffff1d3),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xffb39460)),
        ),
      ),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: officeInk,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: officeInk,
      ),
    ),
  );
}

class PackPaper extends StatelessWidget {
  final Widget child;
  const PackPaper({super.key, required this.child});
  @override
  Widget build(BuildContext context) => officeTheme
      ? OfficeSurface(radius: BorderRadius.circular(16), child: child)
      : child;
}

class ClayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title, leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading, centerTitle;
  const ClayAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
  });
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0) + 8);
  @override
  Widget build(BuildContext context) {
    if (officeTheme) {
      return AppBar(
        title: title,
        leading: leading,
        actions: actions,
        bottom: bottom,
        automaticallyImplyLeading: automaticallyImplyLeading,
        centerTitle: centerTitle,
        toolbarHeight: kToolbarHeight + 8,
        backgroundColor: const Color(0xff174632),
        foregroundColor: const Color(0xffffedc9),
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: Color(0xffffedc9),
        ),
        flexibleSpace: const OfficeSurface(
          material: 1,
          stitched: true,
          child: SizedBox.expand(),
        ),
      );
    }
    final index = titleArt(widgetCaption(title));
    final glass = activePack.id == 'glass';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = glass
        ? (dark ? const Color(0xffeef5ff) : const Color(0xff193764))
        : Colors.white;
    final color = widgetCaption(title) == 'الرئيسية'
        ? activePack.primary
        : artColor(index);
    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: foreground.withValues(alpha: .07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: foreground,
          unselectedLabelColor: foreground.withValues(alpha: .6),
          indicatorColor: glass ? activePack.primary : Colors.white,
        ),
      ),
      child: AppBar(
        title: title,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        centerTitle: centerTitle,
        toolbarHeight: kToolbarHeight + 8,
        actions: actions,
        foregroundColor: foreground,
        bottom: bottom,
        backgroundColor: glass
            ? Theme.of(context).scaffoldBackgroundColor
            : color,
        iconTheme: IconThemeData(color: foreground),
        actionsIconTheme: IconThemeData(color: foreground),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: glass
                ? const BorderRadius.vertical(bottom: Radius.circular(28))
                : null,
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: glass
                  ? (dark
                        ? [const Color(0xff203d67), const Color(0xff162941)]
                        : [const Color(0xfff8fbff), const Color(0xffcddfff)])
                  : [
                      Color.lerp(color, Colors.white, .14)!,
                      color,
                      Color.lerp(color, coral, .35)!,
                    ],
            ),
            border: const Border(
              bottom: BorderSide(color: Colors.white38, width: 2),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 24,
                bottom: -10,
                child: Opacity(
                  opacity: glass ? .09 : .13,
                  child: ArtIcon(index, size: 125),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceBanner extends StatelessWidget {
  final String kind, title, subtitle;
  final VoidCallback? onTap;
  final double height;
  const ServiceBanner({
    super.key,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.height = 122,
  });
  @override
  Widget build(BuildContext context) {
    LabelScope.watch(context);
    if (officeTheme) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: const Color(0xff174632),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: OfficeSurface(
              material: 1,
              stitched: true,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      kind == 'home'
                          ? Icons.menu_book
                          : kind == 'hotel'
                          ? Icons.hotel
                          : kind == 'visa'
                          ? Icons.badge_outlined
                          : Icons.flight,
                      color: const Color(0xffd8ba80),
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(
                            title,
                            style: const TextStyle(
                              color: Color(0xffffedc9),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            UiText(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xffe0cfab),
                                fontSize: 12,
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
    }
    final index = artIndex(kind), color = artColor(index);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(activePack.heroRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: dark ? .12 : .23),
              blurRadius: 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: dark
              ? Color.lerp(color, const Color(0xff302b39), .65)
              : Color.lerp(color, Colors.white, .8),
          borderRadius: BorderRadius.circular(activePack.heroRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height:
                  height *
                  MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
              child: Stack(
                children: [
                  if (illustrationsEnabled)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.sizeOf(context).width < 380 ? 160 : 210,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, .65, 1],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Opacity(
                          opacity:
                              (dark ? .65 : 1) *
                              (displayPreferences['artStrength'] as num? ?? 1)
                                  .toDouble()
                                  .clamp(0, 1),
                          child: AmbientMotion(
                            seed: artIndex(kind) + 40,
                            background: true,
                            child: AtlasArt(
                              asset: activePack.scenes,
                              index: switch (kind) {
                                'ticket' || 'change' => 0,
                                'visa' => 1,
                                'hotel' => 2,
                                _ => 3,
                              },
                              columns: 2,
                              mirror: true,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (kind == 'expense' && illustrationsEnabled)
                    Positioned(
                      left: 22,
                      bottom: 10,
                      child: ArtIcon(14, size: 40),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              UiText(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: dark
                                          ? Colors.black26
                                          : Colors.white70,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              if (subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: UiText(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: dark
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: illustrationsEnabled
                              ? (MediaQuery.sizeOf(context).width < 380
                                    ? 64
                                    : 90)
                              : 12,
                        ),
                        if (!illustrationsEnabled) ArtIcon(index, size: 56),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white.withValues(alpha: .85),
                        child: Icon(Icons.chevron_left_rounded, color: color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TicketShape extends RoundedRectangleBorder {
  const TicketShape()
    : super(borderRadius: const BorderRadius.all(Radius.circular(24)));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = super.getOuterPath(rect, textDirection: textDirection);
    final holes = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left, rect.top + rect.height * .53),
          radius: 8,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right, rect.top + rect.height * .53),
          radius: 8,
        ),
      );
    return Path.combine(PathOperation.difference, body, holes);
  }
}
