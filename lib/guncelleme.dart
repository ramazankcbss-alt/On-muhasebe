import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ortak.dart';

/// GitHub'daki son sürümü denetler; yeni APK varsa indirme bağlantısını açar.
class Guncelleme {
  static const _adres = 'https://api.github.com/repos/ramazankcbss-alt/On-muhasebe/releases/latest';

  static Future<String> mevcut() async => (await PackageInfo.fromPlatform()).version;

  static List<int> _p(String s) => s.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((x) => int.tryParse(x) ?? 0).toList();

  static bool _yeniMi(String son, String mevcut) {
    final a = _p(son), b = _p(mevcut);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// [sor] true ise güncel olduğunda da bilgi verir (elle denetleme).
  static Future<void> kontrol(BuildContext context, {bool sor = false}) async {
    Map<String, dynamic> j;
    try {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final q = await c.getUrl(Uri.parse(_adres));
      q.headers.set('User-Agent', 'on-muhasebe');
      q.headers.set('Accept', 'application/vnd.github+json');
      final r = await q.close();
      j = jsonDecode(await r.transform(utf8.decoder).join()) as Map<String, dynamic>;
      c.close();
    } catch (_) {
      if (sor && context.mounted) mesaj(context, 'İnternet bağlantısı yok');
      return;
    }
    final son = '${j['tag_name'] ?? ''}';
    final apk = (j['assets'] as List? ?? []).cast<Map>().where((a) => '${a['name']}'.endsWith('.apk')).toList();
    final v = await mevcut();
    if (!context.mounted) return;
    if (apk.isEmpty || !_yeniMi(son, v)) {
      if (sor) mesaj(context, 'Uygulama güncel');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Yeni sürüm: $son'),
        content: const Text('Güncelle\'ye dokunduğunuzda APK indirilir. İndirme bitince dosyaya dokunup "Güncelle"yi seçin. Verileriniz silinmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Sonra')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Güncelle')),
        ],
      ),
    );
    if (ok == true) await launchUrl(Uri.parse('${apk.first['browser_download_url']}'), mode: LaunchMode.externalApplication);
  }
}
