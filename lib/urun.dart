import 'package:flutter/material.dart';

import 'db.dart';
import 'excel_araclari.dart';
import 'ortak.dart';

class UrunListe extends StatefulWidget {
  const UrunListe({super.key});
  @override
  State<UrunListe> createState() => _UrunListeState();
}

class _UrunListeState extends State<UrunListe> {
  List<Map<String, Object?>> l = [];
  String ara = '';
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT u.*, IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0) stok FROM urun u ORDER BY u.ad');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final f = l.where((u) => n.isEmpty || normal('${u['ad']} ${u['kod'] ?? ''} ${u['barkod'] ?? ''} ${u['grup'] ?? ''}').contains(n)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Listesi'), actions: [
        IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => excelPaylas('Ürün Listesi', ['Kod', 'Ad', 'Barkod', 'Grup', 'Birim', 'KDV', 'Alış Fiyatı', 'Satış Fiyatı', 'Stok'],
                f.map((u) => [u['kod'], u['ad'], u['barkod'], u['grup'], u['birim'], sy(u['kdv']), sy(u['alis_fiyat']), sy(u['satis_fiyat']), sy(u['stok'])]).toList())),
      ]),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const UrunForm()));
            yukle();
          }),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad, kod, barkod, grup'), onChanged: (v) => setState(() => ara = v))),
        Expanded(
          child: ListView.separated(
            itemCount: f.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = f[i];
              final kritik = sy(u['kritik']) > 0 && sy(u['stok']) <= sy(u['kritik']);
              return ListTile(
                title: Text('${u['ad']}'),
                subtitle: Text('${u['kod'] ?? ''}  Alış ${para(u['alis_fiyat'])} • Satış ${para(u['satis_fiyat'])}'),
                trailing: Text('${miktarS(u['stok'])} ${u['birim'] ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: kritik || sy(u['stok']) < 0 ? Colors.red : null)),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => UrunForm(id: u['id'] as int)));
                  yukle();
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class UrunForm extends StatefulWidget {
  final int? id;
  const UrunForm({super.key, this.id});
  @override
  State<UrunForm> createState() => _UrunFormState();
}

class _UrunFormState extends State<UrunForm> {
  static const metin = ['kod', 'ad', 'barkod', 'grup', 'birim'];
  static const sayi = ['kdv', 'alis_fiyat', 'satis_fiyat', 'kritik'];
  static const etiket = {
    'kod': 'Ürün Kodu', 'ad': 'Ürün Adı *', 'barkod': 'Barkod', 'grup': 'Grup', 'birim': 'Birim',
    'kdv': 'KDV %', 'alis_fiyat': 'Alış Fiyatı (KDV hariç)', 'satis_fiyat': 'Satış Fiyatı (KDV hariç)', 'kritik': 'Kritik Stok',
  };
  late final k = {for (final a in [...metin, ...sayi]) a: TextEditingController()};
  List<Map<String, Object?>> hareket = [];

  @override
  void initState() {
    super.initState();
    k['birim']!.text = 'Adet';
    k['kdv']!.text = '20';
    if (widget.id != null) {
      DB.tek('SELECT * FROM urun WHERE id=?', [widget.id]).then((u) async {
        if (u == null) return;
        for (final a in metin) {
          k[a]!.text = '${u[a] ?? ''}';
        }
        for (final a in sayi) {
          k[a]!.text = miktarS(u[a]);
        }
        hareket = await DB.q('SELECT s.*, d.ad depo FROM stok_hareket s LEFT JOIN depo d ON d.id=s.depo_id WHERE urun_id=? ORDER BY tarih DESC, s.id DESC LIMIT 200', [widget.id]);
        setState(() {});
      });
    }
  }

  Future<void> kaydet() async {
    if (k['ad']!.text.trim().isEmpty) return mesaj(context, 'Ürün adı zorunlu');
    final m = <String, Object?>{for (final a in metin) a: k[a]!.text.trim(), for (final a in sayi) a: sy(k[a]!.text)};
    if (widget.id == null) {
      await DB.ekle('urun', m);
    } else {
      await DB.guncelle('urun', m, widget.id!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.id == null ? 'Ürün Tanımla' : 'Ürün Düzenle'), actions: [
          if (widget.id != null)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (hareket.isNotEmpty) return mesaj(context, 'Hareketi olan ürün silinemez');
                  if (await onay(context, 'Ürün silinsin mi?')) {
                    await DB.sil('urun', widget.id!);
                    if (context.mounted) Navigator.pop(context);
                  }
                }),
          IconButton(icon: const Icon(Icons.check), onPressed: kaydet),
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in metin) Girdi(k[a]!, etiket[a]!),
          for (final a in sayi) Girdi(k[a]!, etiket[a]!, sayi: true),
          if (hareket.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('Stok Hareketleri', style: TextStyle(fontWeight: FontWeight.bold))),
            ...hareket.map((h) => ListTile(
                  dense: true,
                  title: Text('${h['aciklama'] ?? h['tur']}'),
                  subtitle: Text('${gTarih(h['tarih'])} • ${h['depo'] ?? ''}'),
                  trailing: Text(sy(h['giris']) > 0 ? '+${miktarS(h['giris'])}' : '-${miktarS(h['cikis'])}',
                      style: TextStyle(color: sy(h['giris']) > 0 ? Colors.green[800] : Colors.red)),
                )),
          ],
        ]),
      );
}

/// Depo, Kasa, Banka gibi basit isim listeleri
class BasitListe extends StatefulWidget {
  final String tablo, baslik;
  final String? tip;
  const BasitListe(this.tablo, this.baslik, {super.key, this.tip});
  @override
  State<BasitListe> createState() => _BasitListeState();
}

class _BasitListeState extends State<BasitListe> {
  List<Map<String, Object?>> l = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    if (widget.tablo == 'hesap') {
      l = await DB.q('SELECT h.*, IFNULL((SELECT SUM(giris-cikis) FROM finans_hareket WHERE hesap_id=h.id),0) bakiye FROM hesap h WHERE tip=? ORDER BY id', [widget.tip]);
    } else {
      l = await DB.q('SELECT * FROM ${widget.tablo} ORDER BY id');
    }
    if (mounted) setState(() {});
  }

  Future<void> duzenle([Map<String, Object?>? r]) async {
    final ad = TextEditingController(text: '${r?['ad'] ?? ''}');
    final sube = TextEditingController(text: '${r?['sube'] ?? ''}');
    final iban = TextEditingController(text: '${r?['iban'] ?? ''}');
    final banka = widget.tip == 'banka';
    final sonuc = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(r == null ? 'Yeni' : 'Düzenle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Girdi(ad, banka ? 'Banka / Hesap Adı' : 'Ad'),
          if (banka) Girdi(sube, 'Şube'),
          if (banka) Girdi(iban, 'IBAN'),
        ]),
        actions: [
          if (r != null) TextButton(onPressed: () => Navigator.pop(d, 'sil'), child: const Text('Sil')),
          FilledButton(onPressed: () => Navigator.pop(d, 'kaydet'), child: const Text('Kaydet')),
        ],
      ),
    );
    if (sonuc == 'kaydet' && ad.text.trim().isNotEmpty) {
      final m = <String, Object?>{'ad': ad.text.trim(), if (widget.tip != null) 'tip': widget.tip, if (banka) 'sube': sube.text, if (banka) 'iban': iban.text};
      if (r == null) {
        await DB.ekle(widget.tablo, m);
      } else {
        await DB.guncelle(widget.tablo, m, r['id'] as int);
      }
    } else if (sonuc == 'sil' && r != null) {
      final kol = widget.tablo == 'hesap' ? 'hesap_id' : 'depo_id';
      final tab = widget.tablo == 'hesap' ? 'finans_hareket' : 'stok_hareket';
      final n = await DB.tek('SELECT COUNT(*) n FROM $tab WHERE $kol=?', [r['id']]);
      if ((n?['n'] as int? ?? 0) > 0) {
        if (mounted) mesaj(context, 'Hareketi olan kayıt silinemez');
      } else {
        await DB.sil(widget.tablo, r['id'] as int);
      }
    }
    yukle();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.baslik)),
        floatingActionButton: FloatingActionButton(onPressed: () => duzenle(), child: const Icon(Icons.add)),
        body: ListView(
            children: l
                .map((r) => ListTile(
                      title: Text('${r['ad']}'),
                      subtitle: r['iban'] != null && '${r['iban']}'.isNotEmpty ? Text('${r['sube'] ?? ''} ${r['iban']}') : null,
                      trailing: r.containsKey('bakiye') ? Text(para(r['bakiye']), style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                      onTap: () => duzenle(r),
                    ))
                .toList()),
      );
}

class HizliFiyat extends StatefulWidget {
  const HizliFiyat({super.key});
  @override
  State<HizliFiyat> createState() => _HizliFiyatState();
}

class _HizliFiyatState extends State<HizliFiyat> {
  String? grup;
  String alan = 'satis_fiyat';
  final yuzde = TextEditingController(text: '10');
  bool yuvarla = true;
  List<String> gruplar = [];
  @override
  void initState() {
    super.initState();
    DB.q("SELECT DISTINCT grup FROM urun WHERE grup IS NOT NULL AND grup<>'' ORDER BY grup")
        .then((r) => setState(() => gruplar = r.map((e) => e['grup'] as String).toList()));
  }

  Future<void> uygula() async {
    final y = sy(yuzde.text);
    if (y == 0) return;
    final carpan = 1 + y / 100;
    final ifade = yuvarla ? 'ROUND($alan*$carpan, 0)' : 'ROUND($alan*$carpan, 2)';
    final d = await DB.db;
    final n = await d.rawUpdate('UPDATE urun SET $alan=$ifade ${grup == null ? '' : 'WHERE grup=?'}', grup == null ? [] : [grup]);
    if (mounted) {
      mesaj(context, '$n ürünün fiyatı güncellendi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hızlı Fiyat Değişiklik')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          DropdownButtonFormField<String?>(
            value: grup,
            decoration: const InputDecoration(labelText: 'Ürün grubu'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('Tüm ürünler')), ...gruplar.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g)))],
            onChanged: (v) => setState(() => grup = v),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'satis_fiyat', label: Text('Satış fiyatı')), ButtonSegment(value: 'alis_fiyat', label: Text('Alış fiyatı'))],
            selected: {alan},
            onSelectionChanged: (s) => setState(() => alan = s.first),
          ),
          Girdi(yuzde, 'Değişim % (indirim için eksi yazın)', sayi: true),
          SwitchListTile(value: yuvarla, title: const Text('Tam liraya yuvarla'), onChanged: (v) => setState(() => yuvarla = v)),
          FilledButton(onPressed: uygula, child: const Text('Uygula')),
        ]),
      );
}

class UrunHizliGuncelle extends StatefulWidget {
  const UrunHizliGuncelle({super.key});
  @override
  State<UrunHizliGuncelle> createState() => _UrunHizliGuncelleState();
}

class _UrunHizliGuncelleState extends State<UrunHizliGuncelle> {
  List<Map<String, Object?>> l = [];
  String ara = '';
  @override
  void initState() {
    super.initState();
    DB.q('SELECT id, ad, kod, alis_fiyat, satis_fiyat FROM urun ORDER BY ad').then((r) => setState(() => l = r));
  }

  Future<void> yaz(int id, String alan, String v) async {
    await DB.guncelle('urun', {alan: sy(v)}, id);
    if (mounted) mesaj(context, 'Kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final f = l.where((u) => n.isEmpty || normal('${u['ad']} ${u['kod'] ?? ''}').contains(n)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Hızlı Güncelleme')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => ara = v))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Fiyatı değiştirip klavyeden "Tamam"a basın.', style: TextStyle(fontSize: 12))),
        Expanded(
          child: ListView.builder(
            itemCount: f.length,
            itemBuilder: (_, i) {
              final u = f[i];
              return ListTile(
                key: ValueKey(u['id']),
                title: Text('${u['ad']}'),
                subtitle: Row(children: [
                  Expanded(
                      child: TextFormField(
                          initialValue: miktarS(u['alis_fiyat']),
                          decoration: const InputDecoration(labelText: 'Alış'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onFieldSubmitted: (v) => yaz(u['id'] as int, 'alis_fiyat', v))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextFormField(
                          initialValue: miktarS(u['satis_fiyat']),
                          decoration: const InputDecoration(labelText: 'Satış'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onFieldSubmitted: (v) => yaz(u['id'] as int, 'satis_fiyat', v))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
