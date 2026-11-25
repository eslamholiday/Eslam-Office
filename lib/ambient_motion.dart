import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'domain.dart';
import 'labels.dart';

class AmbientRuntime {
  // The application lifecycle enables ambient work; standalone widget hosts stay still.
  static bool enabled = false;
  static final pulse = ValueNotifier<int>(0);
  static bool foreground = true;
}

class MotionGate extends StatefulWidget {
  final Widget child;
  const MotionGate({super.key, required this.child});
  @override
  State<MotionGate> createState() => _MotionGateState();
}

class _MotionGateState extends State<MotionGate> with WidgetsBindingObserver {
  Timer? throttle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AmbientRuntime.foreground = state == AppLifecycleState.resumed;
    AmbientRuntime.pulse.value++;
  }

  @override
  void dispose() {
    throttle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          if (AmbientRuntime.enabled && throttle?.isActive != true) {
            throttle = Timer(const Duration(milliseconds: 90), () {
              AmbientRuntime.pulse.value++;
            });
          }
          return false;
        },
        child: widget.child,
      );
}

class AmbientMotion extends StatefulWidget {
  final Widget child;
  final int seed;
  final bool background;
  const AmbientMotion({
    super.key,
    required this.child,
    required this.seed,
    this.background = false,
  });
  @override
  State<AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<AmbientMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  bool checking = false;
  @override
  void initState() {
    super.initState();
    AmbientRuntime.pulse.addListener(check);
  }

  bool get allowed =>
      AmbientRuntime.enabled &&
      AmbientRuntime.foreground &&
      displayPreferences['reduceMotion'] != true &&
      (displayPreferences['ambientLevel'] as num? ?? 2) > 0 &&
      displayPreferences[widget.background
              ? 'ambientBackgrounds'
              : 'ambientIcons'] !=
          false &&
      displayPreferences['liteGraphics'] != true;
  void check() {
    if (!mounted || checking) return;
    checking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checking = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      var visible = false;
      if (box is RenderBox && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        final rect = offset & box.size;
        visible = rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
      }
      final run =
          allowed &&
          visible &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.of(context);
      final ms = (8000 / (displayPreferences['ambientSpeed'] as num? ?? 1))
          .round()
          .clamp(4000, 16000);
      controller.duration = Duration(milliseconds: ms);
      if (run && !controller.isAnimating) {
        controller.repeat();
      } else if (!run && controller.isAnimating) {
        controller.stop();
      }
    });
  }

  @override
  void dispose() {
    AmbientRuntime.pulse.removeListener(check);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LabelScope.watch(context);
    check();
    if (!allowed || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final phase = (controller.value + widget.seed * .113) % 1;
        final wave = widget.background
            ? math.sin(phase * math.pi * 2)
            : phase < .32
            ? math.sin(phase / .32 * math.pi * 2)
            : 0.0;
        final level = (displayPreferences['ambientLevel'] as num? ?? 2)
            .toDouble();
        return Transform.translate(
          offset: Offset(
            widget.background ? wave * level : 0,
            -wave * level * 1.3,
          ),
          child: Transform.rotate(
            angle: widget.background ? 0 : wave * .012 * level,
            child: child,
          ),
        );
      },
    );
  }
}

class AmountMotionText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextDirection? textDirection;
  const AmountMotionText(
    this.value, {
    super.key,
    this.style,
    this.textDirection,
  });
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Duration(
      milliseconds:
          displayPreferences['reduceMotion'] == true ||
              displayPreferences['animateNumbers'] == false ||
              MediaQuery.disableAnimationsOf(context)
          ? 0
          : 250,
    ),
    child: UiText(
      value,
      key: ValueKey(value),
      textDirection: TextDirection.ltr,
      style: style,
    ),
  );
}
