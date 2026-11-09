import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ortak.dart';

/// GitHub'daki son sürümü denetler; yeni APK varsa indirme bağlantısını açar.
class Guncelleme {
  static const depo = 'ramazankcbss-alt/On-muhasebe';
  static const _adres = 'https://api.github.com/repos/$depo/releases/latest';

  static Future<String> mevcutSurum() async => (await PackageInfo.fromPlatform()).version;

  /// "1.0.12" gibi sürümleri karşılaştırır. a > b ise pozitif.
  static int karsilastir(String a, String b) {
    List<int> p(String s) => s.replaceAll(RegExp(r'^[vV]'), '').split(RegExp(r'[.+-]')).map((x) => int.tryParse(x) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final f = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (f != 0) return f;
    }
    return 0;
  }

  static Future<({String surum, String url, String notlar})?> sonSurum() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final q = await c.getUrl(Uri.parse(_adres));
      q.headers.set('Accept', 'application/vnd.github+json');
      final r = await q.close().timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(await r.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final apk = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>().where((a) => '${a['name']}'.endsWith('.apk')).toList();
      if (apk.isEmpty) return null;
      return (surum: '${j['tag_name']}'.replaceAll(RegExp(r'^[vV]'), ''), url: '${apk.first['browser_download_url']}', notlar: '${j['body'] ?? ''}');
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  /// [sessiz] true ise sadece yeni sürüm varsa bir şey gösterir (açılışta kullanılır).
  static Future<void> denetle(BuildContext context, {bool sessiz = true}) async {
    final simdi = await mevcutSurum();
    final son = await sonSurum();
    if (!context.mounted) return;
    if (son == null) {
      if (!sessiz) mesaj(context, 'Sürüm bilgisi alınamadı. İnternet bağlantısını kontrol edin.');
      return;
    }
    if (karsilastir(son.surum, simdi) <= 0) {
      if (!sessiz) mesaj(context, 'Uygulama güncel ($simdi)');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Yeni sürüm: ${son.surum}'),
        content: SingleChildScrollView(
          child: Text('Kurulu sürüm: $simdi\n\n'
              'Güncelle\'ye dokunduğunuzda APK indirilir. İndirme bitince dosyaya dokunup "Güncelle"yi seçin. Verileriniz silinmez.'
              '${son.notlar.trim().isEmpty ? '' : '\n\n${son.notlar.trim()}'}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Sonra')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Güncelle')),
        ],
      ),
    );
    if (ok == true) {
      await launchUrl(Uri.parse(son.url), mode: LaunchMode.externalApplication);
    }
  }
}
