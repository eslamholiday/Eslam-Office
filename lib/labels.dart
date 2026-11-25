import 'package:flutter/material.dart';
import 'domain.dart';

String uiLabel(String text, [Map<String, dynamic>? preferences]) {
  final labels = (preferences ?? displayPreferences)['uiLabels'] as Map?;
  return labels?[text]?.toString() ?? text;
}

class LabelScope extends InheritedNotifier<ChangeNotifier> {
  const LabelScope({super.key, required super.notifier, required super.child});
  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LabelScope>();
}

String widgetCaption(Widget? widget) => widget is UiText
    ? widget.data
    : widget is Text
    ? widget.data ?? ''
    : '';

/// Keeps labels editable without touching semantic keys, reference records or money.
class UiText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  final Locale? locale;
  const UiText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
    this.locale,
  });
  @override
  Widget build(BuildContext context) {
    LabelScope.watch(context);
    return Text(
      uiLabel(data),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
      textScaler: textScaler,
      locale: locale,
    );
  }
}
