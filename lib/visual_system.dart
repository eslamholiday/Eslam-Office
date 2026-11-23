import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';

// A pack owns artwork, colors, geometry and motion together. Future packs plug
// into this registry without rewriting forms, routes or the accounting model.
class VisualPack {
  final String id, name, icons, scenes;
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
  'clay': VisualPack(
    id: 'clay',
    name: 'المجسّمات الملونة',
    icons: 'assets/visuals/clay/icons.webp',
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
const coral = Color(0xffef635a),
    teal = Color(0xff089b9e),
    violet = Color(0xff9b68cf);
bool get illustrationsEnabled => displayPreferences['liteGraphics'] != true;
int artIndex(String kind) => switch (kind) {
  'ticket' || 'change' || 'home' => 0,
  'visa' => 1,
  'hotel' => 2,
  'expense' || 'owed' => 3,
  'settlement' || 'refund' => 4,
  'customer' || 'customers' || 'passenger' => 5,
  'supplier' || 'payable' => 6,
  'profit' || 'reports' => 7,
  'settings' => 8,
  'appearance' => 9,
  'sound' => 10,
  'haptic' => 11,
  'gesture' => 12,
  'statements' || 'review' => 13,
  'expenses' => 14,
  _ => 15,
};
int titleArt(String text) {
  if (text.contains('الرئيسية')) {
    return 0;
  }
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

class ArtIcon extends StatelessWidget {
  final int index;
  final double size;
  const ArtIcon(this.index, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: illustrationsEnabled
        ? AtlasArt(asset: activePack.icons, index: index, columns: 4)
        : Icon(
            switch (index) {
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
  final primary = preferences['packAccent'] is int
      ? Color(preferences['packAccent'])
      : pack.primary;
  final radius = (preferences['packRadius'] as num? ?? pack.radius).toDouble();
  final surface = dark ? const Color(0xff302b39) : pack.surface;
  final ink = dark ? const Color(0xfffff0e4) : const Color(0xff49394b);
  final border = dark ? const Color(0xff514455) : const Color(0xffefd4bf);
  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: dark ? const Color(0xffff9d8e) : primary,
        secondary: dark ? const Color(0xff65d8d4) : pack.secondary,
        surface: surface,
        onSurface: ink,
        surfaceTint: Colors.transparent,
        onPrimary: dark ? const Color(0xff422c30) : Colors.white,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xff211e29) : pack.canvas,
    visualDensity: preferences['compact'] == true
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
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      backgroundColor: coral,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w800,
        fontSize: 21,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 1 : pack.elevation,
      shadowColor: dark ? Colors.black38 : const Color(0x337b493b),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: dark ? border : Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff26232e) : const Color(0xfffff2e7),
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
    final index = titleArt(title is Text ? ((title as Text).data ?? '') : '');
    final color = title is Text && (title as Text).data == 'الرئيسية'
        ? activePack.primary
        : artColor(index);
    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: .15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      child: AppBar(
        title: title,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        centerTitle: centerTitle,
        toolbarHeight: kToolbarHeight + 8,
        actions: actions,
        foregroundColor: Colors.white,
        bottom: bottom,
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
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
                bottom: -26,
                child: Opacity(opacity: .13, child: ArtIcon(index, size: 125)),
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
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xff49394b),
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
                                  child: Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xff49394b),
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
