import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'ortak.dart';
import 'whatsapp.dart';

/// Android tarafındaki WhatsApp bildirim dinleyicisiyle konuşur (android_ek/kotlin/WaDinleyici.kt).
class WaKanal {
  static const _k = MethodChannel('kones/wa');

  static Future<bool> izinVarMi() async {
    try {
      return await _k.invokeMethod<bool>('izinVarMi') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> izinAc() => _k.invokeMethod('izinAc');

  static Future<List<String>> takipOku() async => ((await _k.invokeMethod<List>('takipOku')) ?? []).cast<String>();

  static Future<void> takipAyarla(List<String> l) => _k.invokeMethod('takipAyarla', {'liste': l});

  static Future<List<String>> gorulenler() async => ((await _k.invokeMethod<List>('gorulenler')) ?? []).cast<String>();

  /// Servisin yakaladığı mesajları wa_mesaj tablosuna alır. Yeni mesaj sayısını döner.
  static Future<int> mesajlar() async {
    final d = await DB.db;
    await d.execute('CREATE TABLE IF NOT EXISTS wa_mesaj(anahtar TEXT PRIMARY KEY, sohbet TEXT, kisi TEXT, metin TEXT, zaman INTEGER)');
    List l;
    try {
      l = await _k.invokeMethod<List>('mesajlar') ?? [];
    } catch (_) {
      return 0;
    }
    var n = 0;
    await d.transaction((tx) async {
      for (final x in l.cast<Map>()) {
        final r = await tx.insert('wa_mesaj', {'anahtar': x['anahtar'], 'sohbet': x['sohbet'], 'kisi': x['kisi'], 'metin': x['metin'], 'zaman': x['zaman']},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (r > 0) n++;
      }
    });
    return n;
  }
}

class WaOtomatik extends StatefulWidget {
  const WaOtomatik({super.key});
  @override
  State<WaOtomatik> createState() => _WaOtomatikState();
}

class _WaOtomatikState extends State<WaOtomatik> with WidgetsBindingObserver {
  bool izin = false;
  List<String> takip = [];
  List<Map<String, Object?>> _liste = [];
  static const gun = 90;

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
    if (s == AppLifecycleState.resumed) yukle();
  }

  Future<void> yukle() async {
    final i = await WaKanal.izinVarMi();
    List<String> t = [];
    try {
      t = await WaKanal.takipOku();
    } catch (_) {}
    await WaKanal.mesajlar();
    final sinir = DateTime.now().subtract(const Duration(days: gun)).millisecondsSinceEpoch;
    final l = await DB.q('SELECT * FROM wa_mesaj WHERE zaman>=? ORDER BY zaman', [sinir]);
    final islenen = (await DB.q('SELECT h FROM aktarim_hash')).map((x) => x['h']).toSet();
    if (!mounted) return;
    setState(() {
      izin = i;
      takip = t..sort();
      _liste = l.where((x) => !islenen.contains(x['anahtar'])).toList();
    });
  }

  /// Yakalanan mesajları alır ve işlenmemiş olanları listeler.
  Future<void> esitle() async {
    final yeni = await WaKanal.mesajlar();
    await yukle();
    if (!mounted) return;
    if (yeni > 0) mesaj(context, '$yeni yeni mesaj alındı');
    if (_liste.isEmpty) return mesaj(context, 'Henüz yakalanmış mesaj yok');
    final l = _liste.map((x) {
      final z = DateTime.fromMillisecondsSinceEpoch(x['zaman'] as int);
      return WaMesaj(tarihS(z), '${z.hour.toString().padLeft(2, '0')}:${z.minute.toString().padLeft(2, '0')}', '${x['kisi']}', '${x['metin']}',
          anahtar: '${x['anahtar']}')
        ..tutar = tutarBul('${x['metin']}');
    }).toList();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsappAktar(gelen: l, baslik: 'Gelen WhatsApp Mesajları')));
    yukle();
  }

  Future<void> ekle() async {
    final g = (await WaKanal.gorulenler()).where((s) => !takip.contains(s)).toList();
    if (!mounted) return;
    final s = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Takip edilecek sohbet', style: TextStyle(fontWeight: FontWeight.bold))),
        if (g.isEmpty)
          const ListTile(dense: true, subtitle: Text('Listede, izin verildikten sonra bildirimi gelen sohbetler görünür.')),
        for (final x in g) ListTile(leading: const Icon(Icons.chat), title: Text(x), onTap: () => Navigator.pop(c, x)),
        ListTile(leading: const Icon(Icons.edit), title: const Text('Adını elle yaz'), onTap: () => Navigator.pop(c, '')),
      ]),
    );
    if (s == null || !mounted) return;
    var ad = s;
    if (ad.isEmpty) {
      final t = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Sohbet / grup adı'),
          content: TextField(controller: t, autofocus: true, decoration: const InputDecoration(hintText: "WhatsApp'ta göründüğü gibi (kişi veya grup adı)")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('Tamam')),
          ],
        ),
      );
      if (r == null || r.isEmpty) return;
      ad = r;
    }
    await WaKanal.takipAyarla({...takip, ad}.toList());
    yukle();
  }

  Future<void> cikar(String s) async {
    await WaKanal.takipAyarla(takip.where((x) => x != s).toList());
    yukle();
  }

  @override
  Widget build(BuildContext context) {
    final sayilar = <String, int>{};
    for (final x in _liste) {
      sayilar['${x['sohbet']}'] = (sayilar['${x['sohbet']}'] ?? 0) + 1;
    }
    final tutarli = _liste.where((x) => tutarBul('${x['metin']}') != null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Otomatik')),
      floatingActionButton: izin && _liste.isNotEmpty
          ? FloatingActionButton.extended(onPressed: esitle, icon: const Icon(Icons.sync), label: Text('Eşitle (${_liste.length})'))
          : null,
      body: RefreshIndicator(
        onRefresh: yukle,
        child: ListView(padding: const EdgeInsets.all(8), children: [
          Card(
            color: izin ? Colors.green[50] : Colors.orange[50],
            child: ListTile(
              leading: Icon(izin ? Icons.notifications_active : Icons.notifications_off, color: izin ? Colors.green : Colors.orange),
              title: Text(izin ? 'Bildirim izni verildi' : 'Bildirim izni gerekli'),
              subtitle: izin ? null : const Text('Açılan listede "Ön Muhasebe"yi bulup izin verin, sonra geri dönün.'),
              trailing: izin ? null : FilledButton(onPressed: WaKanal.izinAc, child: const Text('İzin ver')),
            ),
          ),
          ListTile(
            title: const Text('Otomatik Takip ve Eşitle', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(!izin
                ? 'Kapalı'
                : takip.isEmpty
                    ? 'Henüz sohbet seçilmedi. Hiçbir mesaj kaydedilmez; sadece seçtiğiniz sohbetler takip edilir.'
                    : 'Seçili sohbetlerden gelen mesajlar uygulama kapalıyken de kaydediliyor.'),
            trailing: izin ? IconButton(icon: const Icon(Icons.add), tooltip: 'Ekle', onPressed: ekle) : null,
          ),
          if (takip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final s in takip) InputChip(label: Text(s), onDeleted: () => cikar(s)),
              ]),
            ),
          const Divider(),
          ListTile(
            title: const Text('Gelen WhatsApp Mesajları', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_liste.isEmpty ? 'Henüz yakalanmış mesaj yok' : '$tutarli tutarlı mesaj işlenmeyi bekliyor'),
          ),
          for (final e in sayilar.entries)
            ListTile(dense: true, leading: const Icon(Icons.chat_bubble_outline), title: Text("WhatsApp'tan ${e.key} (${e.value} mesaj)")),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Eşitle\'ye bastığınızda son 90 günde yakalanan mesajlar listelenir. Tutarlı mesajları seçip tahsilat, ödeme veya gider olarak işlersiniz; işlenenler bir daha gelmez ve diğer telefonlara da eşitlenir.\n\n'
                'Not: Sadece size gelen ve bildirimi düşen mesajlar yakalanır. Sessize alınmış sohbetleri takip etmek için o sohbetin bildirimlerini açık tutun. Geçmiş mesajlar için "Sohbetten Veri Al" (dışa aktarma) kullanın.',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
