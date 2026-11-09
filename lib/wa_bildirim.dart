import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'ortak.dart';
import 'whatsapp.dart';

/// WhatsApp bildirimlerinden otomatik mesaj yakalama.
/// Android tarafı: android_ek/kotlin/WaDinleyici.kt (bildirim dinleyici servis).
class WaBildirim {
  static const _k = MethodChannel('kones/wa');

  static Future<bool> izinVar() async {
    try {
      return await _k.invokeMethod<bool>('izinVar') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> izinAc() => _k.invokeMethod('izinAc');

  static Future<List<String>> takip() async => ((await _k.invokeMethod<List>('takipAl')) ?? []).cast<String>()..sort();

  static Future<void> takipYaz(List<String> l) => _k.invokeMethod('takipYaz', {'liste': l});

  static Future<List<String>> gorulenler() async => ((await _k.invokeMethod<List>('gorulenler')) ?? []).cast<String>();

  /// Servisin yakaladığı mesajları veritabanına (wa_mesaj) alır. Yeni mesaj sayısını döner.
  static Future<int> topla() async {
    List l;
    try {
      l = await _k.invokeMethod<List>('mesajlar') ?? [];
    } catch (_) {
      return 0;
    }
    if (l.isEmpty) return 0;
    final d = await DB.db;
    var n = 0;
    await d.transaction((tx) async {
      for (final x in l.cast<Map>()) {
        final r = await tx.insert(
          'wa_mesaj',
          {'anahtar': 'wn|${x['anahtar']}', 'sohbet': x['sohbet'], 'kisi': x['kisi'], 'metin': x['metin'], 'zaman': x['zaman']},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (r > 0) n++;
      }
    });
    return n;
  }
}

/// "WhatsApp Otomatik" ekranı: izin, takip edilen sohbetler ve yakalanan mesajlar.
class WaOtomatik extends StatefulWidget {
  const WaOtomatik({super.key});
  @override
  State<WaOtomatik> createState() => _WaOtomatikState();
}

class _WaOtomatikState extends State<WaOtomatik> with WidgetsBindingObserver {
  bool izin = false, sadeceTutar = true;
  List<String> takip = [];
  List<WaMesaj> mesajlar = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    yukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) yukle(); // izin ekranından dönünce
  }

  Future<void> yukle() async {
    final i = await WaBildirim.izinVar();
    final t = await WaBildirim.takip().catchError((_) => <String>[]);
    if (!mounted) return;
    setState(() {
      izin = i;
      takip = t;
    });
  }

  /// Yakalanan mesajları alır ve son 90 günün işlenmemiş mesajlarını listeler.
  Future<void> esitle() async {
    final yeni = await WaBildirim.topla();
    final sinir = DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final l = await DB.q('SELECT * FROM wa_mesaj WHERE zaman>=? ORDER BY zaman', [sinir]);
    final islenen = (await DB.q("SELECT h FROM aktarim_hash WHERE h LIKE 'wn|%'")).map((x) => x['h']).toSet();
    final out = <WaMesaj>[];
    for (final x in l) {
      final a = '${x['anahtar']}';
      if (islenen.contains(a)) continue;
      final z = DateTime.fromMillisecondsSinceEpoch(x['zaman'] as int);
      final m = WaMesaj(tarihS(z), '${z.hour.toString().padLeft(2, '0')}:${z.minute.toString().padLeft(2, '0')}', '${x['kisi']}', '${x['metin']}', anahtar: a)
        ..tutar = tutarBul('${x['metin']}');
      out.add(m);
    }
    if (!mounted) return;
    setState(() => mesajlar = out);
    final tutarli = out.where((m) => m.tutar != null).length;
    mesaj(context, '${yeni > 0 ? '$yeni yeni mesaj alındı. ' : ''}$tutarli tutarlı mesaj işlenmeyi bekliyor');
  }

  Future<void> sohbetEkle() async {
    final g = (await WaBildirim.gorulenler()).where((s) => !takip.contains(s)).toList();
    if (!mounted) return;
    final s = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(title: const Text('Takip edilecek sohbet'), children: [
        if (g.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Listede, izin verildikten sonra bildirimi gelen sohbetler görünür.', style: TextStyle(fontSize: 13)),
          ),
        for (final x in g) SimpleDialogOption(onPressed: () => Navigator.pop(d, x), child: Text(x)),
        SimpleDialogOption(onPressed: () => Navigator.pop(d, '\u0000elle'), child: const Text('Adını elle yaz', style: TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
    if (s == null || !mounted) return;
    var ad = s;
    if (s == '\u0000elle') {
      final e = await metinSor(context, 'Sohbet / grup adı');
      if (e == null || e.trim().isEmpty) return;
      ad = e.trim();
    }
    await WaBildirim.takipYaz({...takip, ad}.toList());
    yukle();
  }

  Future<void> sohbetSil(String s) async {
    await WaBildirim.takipYaz(takip.where((x) => x != s).toList());
    yukle();
  }

  Future<void> isle() async {
    final secilen = mesajlar.where((m) => m.secili).toList();
    if (secilen.isEmpty) return mesaj(context, 'Önce mesaj seçin');
    await waMesajlariIsle(context, secilen);
    if (!mounted) return;
    setState(() => mesajlar.removeWhere((m) => m.aktarildi));
  }

  @override
  Widget build(BuildContext context) {
    final g = mesajlar.where((m) => !sadeceTutar || m.tutar != null).toList();
    final secSayi = mesajlar.where((m) => m.secili).length;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Otomatik'), actions: [
        IconButton(icon: const Icon(Icons.sync), tooltip: 'Eşitle', onPressed: izin ? esitle : null),
      ]),
      floatingActionButton: secSayi == 0 ? null : FloatingActionButton.extended(onPressed: isle, icon: const Icon(Icons.input), label: Text('$secSayi mesajı işle')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        Card(
          color: izin ? Colors.green[50] : Colors.orange[50],
          child: ListTile(
            leading: Icon(izin ? Icons.notifications_active : Icons.notifications_off, color: izin ? Colors.green : Colors.orange),
            title: Text(izin ? 'Bildirim izni verildi' : 'Bildirim izni gerekli'),
            subtitle: Text(izin
                ? (takip.isEmpty ? 'Henüz sohbet seçilmedi. Hiçbir mesaj kaydedilmez; sadece seçtiğiniz sohbetler takip edilir.' : 'Seçili sohbetlerden gelen mesajlar uygulama kapalıyken de kaydediliyor.')
                : 'Açılan listede "Ön Muhasebe"yi bulup izin verin, sonra geri dönün.'),
            trailing: izin ? null : FilledButton(onPressed: WaBildirim.izinAc, child: const Text('İzin ver')),
          ),
        ),
        if (izin) ...[
          ListTile(
            dense: true,
            title: const Text('Takip edilen sohbetler', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: TextButton.icon(onPressed: sohbetEkle, icon: const Icon(Icons.add), label: const Text('Ekle')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (final s in takip) InputChip(label: Text(s), onDeleted: () => sohbetSil(s)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
                'Eşitle\'ye bastığınızda son 90 günde yakalanan mesajlar listelenir. Tutarlı mesajları seçip tahsilat, ödeme veya gider olarak işlersiniz; '
                'işlenenler bir daha gelmez ve diğer telefonlara da eşitlenir.\n\n'
                'Not: Sadece size gelen ve bildirimi düşen mesajlar yakalanır. Sessize alınmış sohbetleri takip etmek için o sohbetin bildirimlerini açık tutun. '
                'Geçmiş mesajlar için "Sohbetten Veri Al" (dışa aktarma) kullanın.',
                style: TextStyle(fontSize: 12)),
          ),
          FilledButton.icon(onPressed: esitle, icon: const Icon(Icons.sync), label: const Text('Eşitle')),
          const Divider(),
          if (mesajlar.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Henüz yakalanmış mesaj yok')))
          else ...[
            SwitchListTile(dense: true, value: sadeceTutar, title: const Text('Sadece tutar içerenler'), onChanged: (v) => setState(() => sadeceTutar = v)),
            for (final m in g.reversed)
              CheckboxListTile(
                value: m.secili,
                onChanged: (v) => setState(() => m.secili = v == true),
                title: Text(m.metin, maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text('${m.kisi} • ${gTarih(m.tarih)} ${m.saat}'),
                secondary: m.tutar == null ? null : Chip(label: Text(para(m.tutar))),
              ),
          ],
        ],
        const SizedBox(height: 80),
      ]),
    );
  }
}
