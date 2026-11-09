import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'excel_araclari.dart';
import 'ortak.dart';
import 'servis.dart';

class WaMesaj {
  final String tarih, saat, kisi;
  String metin;
  double? tutar;
  bool secili = false, aktarildi = false;
  WaMesaj(this.tarih, this.saat, this.kisi, this.metin);
  String get anahtar => 'wa|$tarih|$saat|$kisi|${metin.length > 200 ? metin.substring(0, 200) : metin}';
}

final _satirRe = RegExp(r'^‎?\[?(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})[,\s]+(\d{1,2}:\d{2})(?::\d{2})?\]?\s*(?:-\s*)?(.*)$');
final _tutarRe = [
  RegExp(r'(\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:TL|tl|Tl|₺|lira|Lira|LİRA|TRY)(?![A-Za-zçğıöşüÇĞİÖŞÜ])'),
  RegExp(r'(?:₺|TL)\s*(\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)'),
];

double? tutarBul(String s) {
  for (final re in _tutarRe) {
    final m = re.firstMatch(s);
    if (m != null) {
      final v = sy(m[1]!.replaceAll(' ', '.'));
      if (v > 0) return v;
    }
  }
  return null;
}

/// WhatsApp "Sohbeti dışa aktar" (.txt veya .zip) dosyasını mesajlara ayırır.
List<WaMesaj> sohbetCoz(String metin) {
  final out = <WaMesaj>[];
  for (final satir in metin.split('\n')) {
    final s = satir.replaceAll('\r', '');
    final m = _satirRe.firstMatch(s);
    if (m != null) {
      final govde = m[3]!;
      final i = govde.indexOf(': ');
      if (i <= 0 || i > 60) continue; // sistem mesajı
      out.add(WaMesaj(tarihCoz(m[1]) ?? m[1]!, m[2]!, govde.substring(0, i).trim(), govde.substring(i + 2).trim()));
    } else if (out.isNotEmpty && s.trim().isNotEmpty) {
      out.last.metin += '\n${s.trim()}';
    }
  }
  for (final x in out) {
    x.tutar = tutarBul(x.metin);
  }
  return out;
}

class WhatsappAktar extends StatefulWidget {
  const WhatsappAktar({super.key});
  @override
  State<WhatsappAktar> createState() => _WhatsappAktarState();
}

class _WhatsappAktarState extends State<WhatsappAktar> {
  List<WaMesaj> mesajlar = [];
  String dosya = '';
  bool sadeceTutar = true;
  String ara = '';

  Future<void> sec() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'zip'], withData: true);
    if (r == null || r.files.first.bytes == null) return;
    final f = r.files.first;
    List<int> b = f.bytes!;
    if (f.name.toLowerCase().endsWith('.zip')) {
      final arsiv = ZipDecoder().decodeBytes(f.bytes!);
      final txt = arsiv.files.where((x) => x.isFile && x.name.toLowerCase().endsWith('.txt')).toList();
      if (txt.isEmpty) {
        if (mounted) mesaj(context, 'ZIP içinde sohbet (.txt) bulunamadı');
        return;
      }
      b = txt.first.content as List<int>;
    }
    final l = sohbetCoz(metinCoz(b));
    final d = await DB.db;
    for (final m in l) {
      final x = await d.query('aktarim_hash', where: 'h=?', whereArgs: [m.anahtar]);
      m.aktarildi = x.isNotEmpty;
    }
    setState(() {
      mesajlar = l;
      dosya = f.name;
    });
    if (l.isEmpty && mounted) mesaj(context, 'Mesaj bulunamadı. Dosyanın WhatsApp "Sohbeti dışa aktar" çıktısı olduğundan emin olun.');
  }

  List<WaMesaj> get gorunen {
    final n = normal(ara);
    return mesajlar.where((m) => (!sadeceTutar || m.tutar != null) && (n.isEmpty || normal('${m.kisi} ${m.metin}').contains(n))).toList();
  }

  Future<void> aktar() async {
    final secilen = mesajlar.where((m) => m.secili).toList();
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
      if (m.aktarildi) continue;
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
        await Servis.islemKaydet(kod, hesap: hesap, cari: cariId, tarih: m.tarih, tutar: m.tutar!, aciklama: 'WhatsApp ${m.kisi}: $kisa', kategori: t.kategori ? 'WhatsApp' : null, kaynak: 'WhatsApp');
        n++;
      }
      await d.insert('aktarim_hash', {'h': m.anahtar}, conflictAlgorithm: ConflictAlgorithm.ignore);
      m.aktarildi = true;
      m.secili = false;
    }
    if (!mounted) return;
    setState(() {});
    mesaj(context, '$n işlem, $not not aktarıldı');
  }

  @override
  Widget build(BuildContext context) {
    final g = gorunen;
    final secSayi = mesajlar.where((m) => m.secili).length;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Verileri'), actions: [
        IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Sohbet dosyası seç', onPressed: sec),
      ]),
      floatingActionButton: secSayi == 0 ? null : FloatingActionButton.extended(onPressed: aktar, icon: const Icon(Icons.input), label: Text('$secSayi mesajı aktar')),
      body: mesajlar.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: [
              const Text('WhatsApp\'taki iş yazışmalarını uygulamaya alma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('WhatsApp, başka uygulamaların mesajları doğrudan okumasına izin vermez. Bunun yerine sohbeti dışa aktarıp buraya yüklersiniz:\n\n'
                  '1. WhatsApp\'ta ilgili sohbeti/grubu açın.\n'
                  '2. Sağ üst ⋮ → Diğer → Sohbeti dışa aktar → "Medya olmadan".\n'
                  '3. "Dosyalara kaydet" (veya Drive) seçin.\n'
                  '4. Burada "Sohbet dosyası seç" ile o .txt / .zip dosyasını açın.\n\n'
                  'Uygulama tutar geçen mesajları (ör. "5.000 TL gönderdim", "₺1.250 havale") bulur; seçtiklerinizi tahsilat, ödeme, gider veya not olarak işler. Aynı mesaj ikinci kez aktarılmaz.'),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: sec, icon: const Icon(Icons.folder_open), label: const Text('Sohbet dosyası seç')),
            ])
          : Column(children: [
              ListTile(dense: true, title: Text(dosya), subtitle: Text('${mesajlar.length} mesaj • ${mesajlar.where((m) => m.tutar != null).length} tanesinde tutar var')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kişi veya kelime'), onChanged: (v) => setState(() => ara = v)),
              ),
              Row(children: [
                Expanded(child: SwitchListTile(dense: true, value: sadeceTutar, title: const Text('Sadece tutar içerenler'), onChanged: (v) => setState(() => sadeceTutar = v))),
                TextButton(
                    onPressed: () => setState(() {
                          final hepsi = g.where((m) => !m.aktarildi).every((m) => m.secili);
                          for (final m in g) {
                            if (!m.aktarildi) m.secili = !hepsi;
                          }
                        }),
                    child: const Text('Tümünü seç')),
              ]),
              Expanded(
                child: ListView.builder(
                  itemCount: g.length,
                  itemBuilder: (_, i) {
                    final m = g[g.length - 1 - i];
                    return CheckboxListTile(
                      value: m.secili,
                      onChanged: m.aktarildi ? null : (v) => setState(() => m.secili = v == true),
                      title: Text(m.metin, maxLines: 3, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${m.kisi} • ${gTarih(m.tarih)} ${m.saat}${m.aktarildi ? ' • aktarıldı' : ''}'),
                      secondary: m.tutar == null ? null : Chip(label: Text(para(m.tutar))),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
