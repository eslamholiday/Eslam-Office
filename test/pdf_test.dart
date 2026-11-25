import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eslam_office/reports.dart';
import 'package:eslam_office/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('Arabic PDF with bundled font generates offline across pages', () async {
    final s = await Store.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final page = PdfPage(
      s,
      'كشف حساب اختباري',
      ['التاريخ', 'العملية', 'الحركة', 'الرصيد'],
      List.generate(
        65,
        (i) => [
          '2026-10-02',
          i == 0
              ? 'فندق: Grand Hyatt Dubai\nالوجهة: Dubai — بغداد\nالمسافر: Ali محمد\nUSD 130.00'
              : 'تذكرة بغداد — دبي #$i',
          '130.00 USD',
          '${(i + 1) * 130}.00 USD',
        ],
      ),
      ['الرصيد النهائي: 8450.00 USD'],
    );
    final bytes = await page.document(PdfPageFormat.a4);
    expect(bytes.length, greaterThan(10000));
    expect(String.fromCharCodes(bytes), contains('/FontFile2'));
    expect(String.fromCharCodes(bytes), isNot(contains('/Subtype /Image')));
    await File('/tmp/eslam-statement-test.pdf').writeAsBytes(bytes);
    await s.db.close();
  });
}
