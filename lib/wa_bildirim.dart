import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'ortak.dart';
import 'servis.dart';
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
  static const gun = 90;
  bool izin = false, sadeceTutar = true;
  List<String> takip = [];
  List<WaMesaj> _liste = [];
  Map<String, int> sohbetler = {};

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
    if (!mounted) return;
    setState(() {
      izin = i;
      takip = t..sort();
    });
  }

  /// İşlenen mesajları listeden kaldırır.
  void temizle() => setState(() => _liste.removeWhere((m) => m.aktarildi));

  /// Yakalanan mesajları alır; son 90 günün işlenmemiş mesajlarını listeler.
  Future<void> esitle() async {
    final yeni = await WaKanal.mesajlar();
    final d = await DB.db;
    final l = await DB.q('SELECT * FROM wa_mesaj WHERE zaman>=? ORDER BY zaman', [DateTime.now().subtract(const Duration(days: gun)).millisecondsSinceEpoch]);
    final out = <WaMesaj>[];
    final say = <String, int>{};
    for (final x in l) {
      final z = DateTime.fromMillisecondsSinceEpoch(x['zaman'] as int);
      final m = WaMesaj(tarihS(z), '${z.hour.toString().padLeft(2, '0')}:${z.minute.toString().padLeft(2, '0')}', '${x['kisi']}', '${x['metin']}', '${x['anahtar']}')
        ..tutar = tutarBul('${x['metin']}');
      if ((await d.query('aktarim_hash', where: 'h=?', whereArgs: [m.anahtar])).isNotEmpty) continue;
      out.add(m);
      say['${x['sohbet']}'] = (say['${x['sohbet']}'] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() {
      _liste = out;
      sohbetler = say;
    });
    if (yeni > 0) mesaj(context, '$yeni yeni mesaj alındı');
  }

  Future<void> sohbetEkle() async {
    final g = (await WaKanal.gorulenler()).where((s) => !takip.contains(s)).toList();
    if (!mounted) return;
    final s = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Takip edilecek sohbet', style: TextStyle(fontWeight: FontWeight.bold))),
        if (g.isEmpty) const ListTile(dense: true, subtitle: Text('Listede, izin verildikten sonra bildirimi gelen sohbetler görünür.')),
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

  void tumunuIsaretle() => setState(() {
        final g = _liste.where((m) => !sadeceTutar || m.tutar != null);
        final hepsi = g.every((m) => m.secili);
        for (final m in g) {
          m.secili = !hepsi;
        }
      });

  Future<void> aktar() async {
    final secilen = _liste.where((m) => m.secili).toList();
    if (secilen.isEmpty) return mesaj(context, 'Önce mesaj seçin');
    const secenekler = {
      'cariden_tahsilat': 'Tahsilat (cariden, kasaya)',
      'gelen_havale': 'Tahsilat (cariden, bankaya)',
      'cariye_odeme': 'Ödeme (cariye, kasadan)',
      'giden_havale': 'Ödeme (cariye, bankadan)',
      'borc_dekont': 'Borç dekontu (cari bize borçlandı)',
      'alacak_dekont': 'Alacak dekontu (biz cariye borçlandık)',
      'diger_odeme': 'Gider (kasadan)',
      'diger_tahsilat': 'Diğer gelir (kasaya)',
      'not': 'Sadece not olarak kaydet',
    };
    String kod = 'cariden_tahsilat';
    bool gonderenCari = true;
    Map<String, Object?>? cari;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, ss) => AlertDialog(
          title: Text('${secilen.length} mesaj nasıl işlensin?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: kod,
                isExpanded: true,
                items: secenekler.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => ss(() => kod = v!),
              ),
              if (kod != 'not' && islemler[kod]!.cari != 0) ...[
                RadioListTile<bool>(value: true, groupValue: gonderenCari, title: const Text('Gönderen kişiyi cari olarak kullan'), onChanged: (v) => ss(() => gonderenCari = true)),
                RadioListTile<bool>(value: false, groupValue: gonderenCari, title: Text(cari == null ? 'Tek cari seç' : 'Cari: ${cari!['ad']}'), onChanged: (v) async {
                  final c = await cariSec(d);
                  ss(() {
                    cari = c;
                    gonderenCari = c == null;
                  });
                }),
              ],
              const Padding(padding: EdgeInsets.only(top: 8), child: Text('Tutar mesajdan okunur; tutarı olmayan mesajlar not olarak kaydedilir.', style: TextStyle(fontSize: 12))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Aktar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final d = await DB.db;
    int n = 0, not = 0;
    for (final m in secilen) {
      final kisa = m.metin.length > 120 ? '${m.metin.substring(0, 120)}…' : m.metin;
      if (kod == 'not' || m.tutar == null) {
        await DB.ekle('notlar', {'tarih': m.tarih, 'kaynak': 'WhatsApp', 'kisi': m.kisi, 'metin': m.metin});
        not++;
      } else {
        final t = islemler[kod]!;
        int? cariId;
        if (t.cari != 0) cariId = gonderenCari ? await Servis.cariBulEkle(m.kisi) : cari?['id'] as int?;
        int? hesap;
        if (t.hesap != 0) hesap = await Servis.ilkHesap(t.hesapTip ?? 'kasa');
        await Servis.islemKaydet(kod, hesap: hesap, cari: cariId, tarih: m.tarih, tutar: m.tutar!, aciklama: "WhatsApp'tan ${m.kisi}: $kisa", kategori: t.kategori ? 'WhatsApp' : null, kaynak: 'WhatsApp');
        n++;
      }
      await d.insert('aktarim_hash', {'h': m.anahtar}, conflictAlgorithm: ConflictAlgorithm.ignore);
      m.aktarildi = true;
      m.secili = false;
    }
    if (!mounted) return;
    temizle();
    mesaj(context, '$n işlem, $not not aktarıldı');
  }

  @override
  Widget build(BuildContext context) {
    final g = _liste.where((m) => !sadeceTutar || m.tutar != null).toList();
    final secSayi = _liste.where((m) => m.secili).length;
    final tutarli = _liste.where((m) => m.tutar != null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Otomatik'), actions: [
        if (izin) TextButton.icon(onPressed: esitle, icon: const Icon(Icons.sync), label: Text('Eşitle (${_liste.length})')),
      ]),
      floatingActionButton: secSayi == 0 ? null : FloatingActionButton.extended(onPressed: aktar, icon: const Icon(Icons.input), label: Text('$secSayi mesajı aktar')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        Card(
          color: izin ? Colors.green[50] : Colors.orange[50],
          child: ListTile(
            leading: Icon(izin ? Icons.notifications_active : Icons.notifications_off, color: izin ? Colors.green : Colors.orange),
            title: const Text('Otomatik Takip ve Eşitle'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(izin ? 'Bildirim izni verildi' : 'Bildirim izni gerekli'),
              if (!izin) const Text('Açılan listede "Ön Muhasebe"yi bulup izin verin, sonra geri dönün.', style: TextStyle(fontSize: 12)),
            ]),
            trailing: izin ? null : FilledButton(onPressed: WaKanal.izinAc, child: const Text('İzin ver')),
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('Takip edilen sohbetler', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(!izin
              ? 'Kapalı'
              : takip.isEmpty
                  ? 'Henüz sohbet seçilmedi. Hiçbir mesaj kaydedilmez; sadece seçtiğiniz sohbetler takip edilir.'
                  : 'Seçili sohbetlerden gelen mesajlar uygulama kapalıyken de kaydediliyor.'),
          trailing: izin ? IconButton(icon: const Icon(Icons.add), onPressed: sohbetEkle) : null,
        ),
        for (final s in takip)
          ListTile(
            dense: true,
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(sohbetler[s] == null ? s : '$s (${sohbetler[s]} mesaj)'),
            trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await WaKanal.takipAyarla(takip.where((x) => x != s).toList());
                  yukle();
                }),
          ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Eşitle\'ye bastığınızda son 90 günde yakalanan mesajlar listelenir. Tutarlı mesajları seçip tahsilat, ödeme veya gider olarak işlersiniz; işlenenler bir daha gelmez ve diğer telefonlara da eşitlenir.\n\n'
              'Not: Sadece size gelen ve bildirimi düşen mesajlar yakalanır. Sessize alınmış sohbetleri takip etmek için o sohbetin bildirimlerini açık tutun. Geçmiş mesajlar için "Sohbetten Veri Al" (dışa aktarma) kullanın.',
              style: TextStyle(fontSize: 12)),
        ),
        const Divider(),
        ListTile(
          title: const Text('Gelen WhatsApp Mesajları', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(_liste.isEmpty ? 'Henüz yakalanmış mesaj yok' : '$tutarli tutarlı mesaj işlenmeyi bekliyor'),
        ),
        if (_liste.isNotEmpty)
          Row(children: [
            Expanded(child: SwitchListTile(dense: true, value: sadeceTutar, title: const Text('Sadece tutar içerenler'), onChanged: (v) => setState(() => sadeceTutar = v))),
            TextButton(onPressed: tumunuIsaretle, child: const Text('Tümünü seç')),
          ]),
        for (final m in g.reversed)
          CheckboxListTile(
            value: m.secili,
            onChanged: (v) => setState(() => m.secili = v == true),
            title: Text(m.metin, maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: Text('${m.kisi} • ${gTarih(m.tarih)} ${m.saat}'),
            secondary: m.tutar == null ? null : Chip(label: Text(para(m.tutar))),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }
}
