import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

String dosyaAdi(String s) => s.replaceAll(RegExp(r'[^\wçğıöşüÇĞİÖŞÜ\- ]'), '').replaceAll(' ', '_');

xl.CellValue? _hucreYaz(Object? v) {
  if (v == null) return null;
  if (v is num) return xl.DoubleCellValue(v.toDouble());
  return xl.TextCellValue(v.toString());
}

/// Tek sayfalık Excel oluşturup paylaşım menüsünü açar (WhatsApp, e-posta, Drive...)
Future<void> excelPaylas(String ad, List<String> basliklar, List<List<Object?>> satirlar) =>
    excelCokluPaylas(ad, {'Sheet1': (basliklar, satirlar)});

Future<void> excelCokluPaylas(String ad, Map<String, (List<String>, List<List<Object?>>)> sayfalar) async {
  final ex = xl.Excel.createExcel();
  var ilk = true;
  for (final e in sayfalar.entries) {
    final adi = ilk && e.key == 'Sheet1' ? 'Sheet1' : e.key;
    final sh = ex[adi];
    sh.appendRow(e.value.$1.map<xl.CellValue?>((b) => xl.TextCellValue(b)).toList());
    for (final r in e.value.$2) {
      sh.appendRow(r.map(_hucreYaz).toList());
    }
    ilk = false;
  }
  if (!sayfalar.containsKey('Sheet1') && ex.tables.containsKey('Sheet1') && ex.tables.length > 1) {
    ex.delete('Sheet1');
  }
  final bytes = ex.encode();
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${dosyaAdi(ad)}.xlsx');
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path)], text: ad);
}

String _iki(int n) => n.toString().padLeft(2, '0');

String hucreOku(xl.Data? d) {
  final v = d?.value;
  if (v == null) return '';
  if (v is xl.DateCellValue) return '${v.year}-${_iki(v.month)}-${_iki(v.day)}';
  if (v is xl.DateTimeCellValue) return '${v.year}-${_iki(v.month)}-${_iki(v.day)}';
  if (v is xl.IntCellValue) return v.value.toString();
  if (v is xl.DoubleCellValue) {
    final x = v.value;
    return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
  }
  if (v is xl.TextCellValue) {
    final dynamic t = (v as dynamic).value;
    if (t is String) return t.trim();
    final dynamic metin = t?.text;
    return (metin is String ? metin : t.toString()).trim();
  }
  return v.toString().trim();
}

/// Excel (.xlsx) veya CSV dosyasındaki tüm sayfaları satır/sütun metni olarak döndürür.
Map<String, List<List<String>>> dosyaOku(String ad, Uint8List bytes) {
  final k = ad.toLowerCase();
  if (k.endsWith('.csv') || k.endsWith('.txt')) {
    return {'CSV': csvOku(metinCoz(bytes))};
  }
  if (k.endsWith('.xls')) {
    throw Exception('Eski .xls biçimi okunamıyor. Dosyayı Excel/EBS içinden ".xlsx" veya ".csv" olarak kaydedin.');
  }
  final ex = xl.Excel.decodeBytes(bytes);
  final out = <String, List<List<String>>>{};
  for (final e in ex.tables.entries) {
    final rows = e.value.rows.map((r) => r.map(hucreOku).toList()).where((r) => r.any((x) => x.isNotEmpty)).toList();
    if (rows.isNotEmpty) out[e.key] = rows;
  }
  return out;
}

/// UTF-8 değilse Windows-1254 (Türkçe) varsayar.
String metinCoz(List<int> b) {
  try {
    return utf8.decode(b);
  } catch (_) {
    const m = {0xD0: 'Ğ', 0xF0: 'ğ', 0xDD: 'İ', 0xFD: 'ı', 0xDE: 'Ş', 0xFE: 'ş', 0x80: '€'};
    return String.fromCharCodes(b).split('').map((ch) => m[ch.codeUnitAt(0)] ?? ch).join();
  }
}

List<List<String>> csvOku(String metin) {
  final satirlar = metin.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  if (satirlar.isEmpty) return [];
  final ilk = satirlar.first;
  final ayrac = ['\t', ';', ','].reduce((a, b) => a.allMatches(ilk).length >= b.allMatches(ilk).length ? a : b);
  final out = <List<String>>[];
  for (final s in satirlar) {
    if (s.trim().isEmpty) continue;
    final hucre = <String>[];
    final sb = StringBuffer();
    var tirnak = false;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '"') {
        if (tirnak && i + 1 < s.length && s[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          tirnak = !tirnak;
        }
      } else if (ch == ayrac && !tirnak) {
        hucre.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    hucre.add(sb.toString().trim());
    out.add(hucre);
  }
  return out;
}
