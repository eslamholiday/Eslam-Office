import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'visual_system.dart';

class GeoCatalog {
  static List<Map<String, dynamic>> countries = [];
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= () async {
    final raw = await rootBundle.loadString('assets/data/countries.json');
    countries = (jsonDecode(raw) as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }();
  static String clean(String value) =>
      normalize(value).replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A]'), '');
  static const countryAliases = {
    'العراق': 'IQ',
    'iraq': 'IQ',
    'تركيا': 'TR',
    'turkey': 'TR',
    'turkiye': 'TR',
    'الامارات': 'AE',
    'الاماراتالعربيةالمتحدة': 'AE',
    'uae': 'AE',
    'الاردن': 'JO',
    'jordan': 'JO',
    'لبنان': 'LB',
    'مصر': 'EG',
    'egypt': 'EG',
    'السعودية': 'SA',
    'قطر': 'QA',
    'عمان': 'OM',
    'عُمان': 'OM',
    'ايران': 'IR',
    'ماليزيا': 'MY',
    'تايلاند': 'TH',
    'جورجيا': 'GE',
    'ارمينيا': 'AM',
    'روسيا': 'RU',
    'المالديف': 'MV',
    'الصين': 'CN',
    'اليابان': 'JP',
    'اندونيسيا': 'ID',
    'سنغافورة': 'SG',
    'سريلانكا': 'LK',
    'المغرب': 'MA',
    'جنوبافريقيا': 'ZA',
    'امريكا': 'US',
    'اميركا': 'US',
    'الولاياتالمتحدة': 'US',
    'usa': 'US',
    'بريطانيا': 'GB',
    'انكلترا': 'GB',
    'uk': 'GB',
    'فلسطين': 'PS',
    'كورياالجنوبية': 'KR',
  };
  static const cityAliases = {
    'بغداد': 'IQ',
    'baghdad': 'IQ',
    'bgw': 'IQ',
    'البصرة': 'IQ',
    'basra': 'IQ',
    'اربيـل': 'IQ',
    'اربيل': 'IQ',
    'erbil': 'IQ',
    'ebl': 'IQ',
    'السليمانية': 'IQ',
    'النجف': 'IQ',
    'كربلاء': 'IQ',
    'الموصل': 'IQ',
    'اسطنبول': 'TR',
    'istanbul': 'TR',
    'انقرة': 'TR',
    'بورصة': 'TR',
    'bursa': 'TR',
    'انطاليا': 'TR',
    'دبي': 'AE',
    'dubai': 'AE',
    'dxb': 'AE',
    'ابوظبي': 'AE',
    'الشارقة': 'AE',
    'عمان': 'JO',
    'amman': 'JO',
    'amm': 'JO',
    'بيروت': 'LB',
    'القاهرة': 'EG',
    'cairo': 'EG',
    'cai': 'EG',
    'الاسكندرية': 'EG',
    'شرمالشيخ': 'EG',
    'الغردقة': 'EG',
    'جدة': 'SA',
    'الرياض': 'SA',
    'مكة': 'SA',
    'المدينة': 'SA',
    'الدوحة': 'QA',
    'مسقط': 'OM',
    'طهران': 'IR',
    'كوالالمبور': 'MY',
    'بانكوك': 'TH',
    'تبليسي': 'GE',
    'يريفان': 'AM',
    'موسكو': 'RU',
    'المالديف': 'MV',
    'لندن': 'GB',
    'london': 'GB',
    'باريس': 'FR',
    'paris': 'FR',
    'روما': 'IT',
    'rome': 'IT',
    'برلين': 'DE',
    'نيويورك': 'US',
    'newyork': 'US',
    'طوكيو': 'JP',
    'سيول': 'KR',
  };
  static String? countryCode(String name) {
    final key = clean(name);
    for (final country in countries) {
      if ([
        country['code'],
        country['ar'],
        country['en'],
      ].any((v) => clean('$v') == key)) {
        return country['code'] as String;
      }
    }
    return countryAliases[key];
  }

  static String? infer(String kind, String name) => kind == 'country'
      ? countryCode(name)
      : kind == 'city'
      ? cityAliases[clean(name)]
      : null;
  static String? recordCode(Map<String, dynamic> record) {
    if (!['city', 'country'].contains(record['kind'])) return null;
    if (record.containsKey('flagCode')) {
      return '${record['flagCode']}'.isEmpty
          ? null
          : record['flagCode'] as String;
    }
    if (record['countryCode'] != null) return record['countryCode'] as String;
    return displayPreferences['autoGeoFlags'] == false
        ? null
        : infer(record['kind'], record['name'] ?? '');
  }

  static Map<String, dynamic>? byCode(String? code) =>
      countries.where((c) => c['code'] == code).firstOrNull;
}

class CountryBadge extends StatelessWidget {
  final String? code;
  final double? size;
  const CountryBadge(this.code, {super.key, this.size});
  @override
  Widget build(BuildContext context) {
    if (code == null || displayPreferences['showFlags'] == false) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<void>(
      future: GeoCatalog.load(),
      builder: (_, snapshot) {
        final country = GeoCatalog.byCode(code);
        final width =
            size ?? (displayPreferences['flagSize'] as num? ?? 28).toDouble();
        if (country == null) return SizedBox(width: width, height: width * .7);
        return Semantics(
          label: 'علم ${country['ar']}',
          child: SizedBox(
            width: width,
            height: width * .7,
            child: AtlasArt(
              asset: 'assets/flags/atlas.webp',
              index: country['index'] as int,
              columns: 16,
            ),
          ),
        );
      },
    );
  }
}
