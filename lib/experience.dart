import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'ambient_motion.dart';

class Experience {
  static const channel = MethodChannel('eslam_money/experience');
  static const events = ['select', 'navigate', 'save', 'alert', 'error'];
  static const eventLabels = {
    'select': 'الضغط والاختيار',
    'navigate': 'التنقل والرجوع',
    'save': 'نجاح الحفظ',
    'alert': 'التنبيه',
    'error': 'تعذر الإجراء',
  };
  static DateTime? _last;
  static String? _lastEvent;
  static Future<String?> fire(String event, {String? preview}) async {
    if (!events.contains(event)) return null;
    final now = DateTime.now();
    if (preview == null &&
        _last != null &&
        now.difference(_last!).inMilliseconds < 100 &&
        (event == 'select' || event == _lastEvent)) {
      return null;
    }
    final preferences = displayPreferences;
    final sound =
        preview == 'sound' ||
        (preview == null &&
            preferences['soundEnabled'] != false &&
            preferences['sound_$event'] != false);
    final haptic =
        preview == 'haptic' ||
        (preview == null &&
            preferences['hapticEnabled'] != false &&
            preferences['haptic_$event'] != false);
    if (!sound && !haptic) return null;
    _last = now;
    _lastEvent = event;
    try {
      final response = await channel
          .invokeMapMethod<String, dynamic>('feedback', {
            'event': event,
            'sound': sound,
            'haptic': haptic,
            'volume': (preferences['soundVolume'] as num? ?? .25)
                .clamp(0, 1)
                .toDouble(),
            'intensity': (preferences['hapticIntensity'] as num? ?? .45)
                .clamp(0, 1)
                .toDouble(),
            'style':
                [
                  'soft',
                  'pop',
                  'bell',
                  'silk',
                  'wood',
                  'crystal',
                  'water',
                ].contains(preferences['soundStyle'])
                ? preferences['soundStyle']
                : 'silk',
          })
          .timeout(const Duration(seconds: 7));
      return response?['sound'] as String?;
    } on PlatformException {
      /* Feedback must never block an operation. */
    } on MissingPluginException {
      /* Other platforms and widget tests. */
    } on TimeoutException {
      /* A stalled audio decoder must not leave a preview waiting. */
    }
    return 'error';
  }
}

class ExperienceObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      unawaited(Experience.fire(route is DialogRoute ? 'alert' : 'navigate'));
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      unawaited(Experience.fire('navigate'));
}

final experienceObserver = ExperienceObserver();

class ExperienceTapRegion extends StatefulWidget {
  final Widget child;
  const ExperienceTapRegion({super.key, required this.child});
  @override
  State<ExperienceTapRegion> createState() => _ExperienceTapRegionState();
}

class _ExperienceTapRegionState extends State<ExperienceTapRegion> {
  PointerDownEvent? down;
  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => down = event,
    onPointerCancel: (_) => down = null,
    onPointerUp: (event) {
      final start = down;
      down = null;
      if (start != null &&
          start.pointer == event.pointer &&
          (start.position - event.position).distance < 9 &&
          (event.timeStamp - start.timeStamp).inMilliseconds < 450) {
        if (AmbientRuntime.enabled) {
          Future<void>.delayed(const Duration(milliseconds: 45), () async {
            if (AmbientRuntime.foreground) await Experience.fire('select');
          });
        } else {
          unawaited(Experience.fire('select'));
        }
      }
    },
    child: widget.child,
  );
}

class Tactile extends StatefulWidget {
  final Widget child;
  const Tactile({super.key, required this.child});
  @override
  State<Tactile> createState() => _TactileState();
}

class _TactileState extends State<Tactile> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale:
          pressed &&
              displayPreferences['reduceMotion'] != true &&
              displayPreferences['pressMotion'] != false &&
              !MediaQuery.disableAnimationsOf(context)
          ? .975
          : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}
