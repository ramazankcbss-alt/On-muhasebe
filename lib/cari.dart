import 'package:flutter/material.dart';

import 'belge.dart';
import 'db.dart';
import 'excel_araclari.dart';
import 'ortak.dart';
import 'servis.dart';

class CariListe extends StatefulWidget {
  final bool sadeceBakiyeli;
  const CariListe({super.key, this.sadeceBakiyeli = false});
  @override
  State<CariListe> createState() => _CariListeState();
}

class _CariListeState extends State<CariListe> {
  List<Map<String, Object?>> cariler = [];
  String ara = '';
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    final r = await DB.q('''SELECT c.*, IFNULL((SELECT SUM(borc-alacak) FROM cari_hareket WHERE cari_id=c.id),0) bakiye
      FROM cari c ORDER BY c.unvan''');
    setState(() => cariler = widget.sadeceBakiyeli ? r.where((x) => sy(x['bakiye']).abs() > 0.005).toList() : r);
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final l = cariler
        .where((c) => n.isEmpty || normal('${c['unvan']} ${c['kod'] ?? ''} ${c['tel'] ?? ''}').contains(n))
        .toList();
    final top = l.fold(0.0, (a, c) => a + sy(c['bakiye']));
    return Scaffold(
      appBar: AppBar(title: Text(widget.sadeceBakiyeli ? 'Cari Bakiye Listesi' : 'Cari Hesap Listesi'), actions: [
        IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => excelPaylas('Cari Listesi', ['Kod', 'Ünvan', 'Tip', 'Telefon', 'Vergi No', 'Bakiye'],
                l.map((c) => [c['kod'], c['unvan'], c['tip'], c['tel'], c['vergi_no'], sy(c['bakiye'])]).toList())),
      ]),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const CariForm()));
            yukle();
          }),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ünvan, kod, telefon'),
              onChanged: (v) => setState(() => ara = v)),
        ),
        ListTile(
          dense: true,
          title: Text('${l.length} cari'),
          trailing: Text('Net bakiye: ${para(top)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: l.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = l[i];
              final b = sy(c['bakiye']);
              return ListTile(
                title: Text('${c['unvan']}'),
                subtitle: Text([c['kod'], c['tip'], c['tel']].where((e) => e != null && '$e'.isNotEmpty).join(' • ')),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(para(b.abs()), style: TextStyle(fontWeight: FontWeight.bold, color: b > 0 ? Colors.green[800] : b < 0 ? Colors.red : null)),
                  Text(b > 0.005 ? 'Alacağımız' : b < -0.005 ? 'Borcumuz' : '', style: const TextStyle(fontSize: 11)),
                ]),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => CariDetay(c['id'] as int)));
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

class CariDetay extends StatefulWidget {
  final int id;
  const CariDetay(this.id, {super.key});
  @override
  State<CariDetay> createState() => _CariDetayState();
}

class _CariDetayState extends State<CariDetay> {
  Map<String, Object?>? c;
  List<Map<String, Object?>> h = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    c = await DB.tek('SELECT * FROM cari WHERE id=?', [widget.id]);
    h = await DB.q('SELECT * FROM cari_hareket WHERE cari_id=? ORDER BY tarih, id', [widget.id]);
    if (mounted) setState(() {});
  }

  Future<void> git(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    yukle();
  }

  @override
  Widget build(BuildContext context) {
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    double yuru = 0;
    final satirlar = h.map((x) {
      yuru += sy(x['borc']) - sy(x['alacak']);
      return {...x, 'bakiye': yuru};
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${c!['unvan']}'), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () => git(CariForm(id: widget.id))),
        IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Ekstre paylaş',
            onPressed: () => excelPaylas('Ekstre ${c!['unvan']}', ['Tarih', 'İşlem', 'Açıklama', 'Borç', 'Alacak', 'Bakiye'],
                satirlar.map((x) => [gTarih(x['tarih']), x['tur'], x['aciklama'], sy(x['borc']), sy(x['alacak']), sy(x['bakiye'])]).toList())),
      ]),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('Bakiye: ${para(yuru.abs())} ${yuru > 0.005 ? '(Alacağımız)' : yuru < -0.005 ? '(Borcumuz)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([c!['tel'], c!['vergi_dairesi'], c!['vergi_no']].where((e) => e != null && '$e'.isNotEmpty).join(' • ')),
          ),
        ),
        Wrap(spacing: 6, children: [
          ActionChip(avatar: const Icon(Icons.call_received, size: 18), label: const Text('Tahsilat'),
              onPressed: () => git(IslemForm('tahsilat', cariId: widget.id))),
          ActionChip(avatar: const Icon(Icons.call_made, size: 18), label: const Text('Ödeme'),
              onPressed: () => git(IslemForm('odeme', cariId: widget.id))),
          ActionChip(avatar: const Icon(Icons.receipt_long, size: 18), label: const Text('Satış Faturası'),
              onPressed: () => git(BelgeForm('satis_fatura', cariId: widget.id))),
          ActionChip(avatar: const Icon(Icons.receipt, size: 18), label: const Text('Alış Faturası'),
              onPressed: () => git(BelgeForm('alis_fatura', cariId: widget.id))),
        ]),
        const Divider(),
        Expanded(
          child: satirlar.isEmpty
              ? const Center(child: Text('Hareket yok'))
              : ListView.builder(
                  itemCount: satirlar.length,
                  itemBuilder: (_, i) {
                    final x = satirlar[satirlar.length - 1 - i];
                    final borc = sy(x['borc']), alacak = sy(x['alacak']);
                    return ListTile(
                      dense: true,
                      title: Text('${x['tur']}  ${x['aciklama'] ?? ''}'),
                      subtitle: Text('${gTarih(x['tarih'])}   Bakiye: ${para(x['bakiye'])}'),
                      trailing: Text(borc > 0 ? '+${para(borc)}' : '-${para(alacak)}',
                          style: TextStyle(color: borc > 0 ? Colors.green[800] : Colors.red, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final b = x['belge_id'] as int?;
                        if (b != null) {
                          final bl = await DB.tek('SELECT tur FROM belge WHERE id=?', [b]);
                          if (bl != null && context.mounted) {
                            await git(BelgeForm(bl['tur'] as String, id: b));
                            return;
                          }
                        }
                        if (context.mounted) await hareketTikla(context, x);
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

class CariForm extends StatefulWidget {
  final int? id;
  const CariForm({super.key, this.id});
  @override
  State<CariForm> createState() => _CariFormState();
}

class _CariFormState extends State<CariForm> {
  final alanlar = ['kod', 'unvan', 'tel', 'email', 'adres', 'vergi_dairesi', 'vergi_no', 'notlar'];
  final etiket = {
    'kod': 'Cari Kodu', 'unvan': 'Ünvan *', 'tel': 'Telefon', 'email': 'E-posta', 'adres': 'Adres',
    'vergi_dairesi': 'Vergi Dairesi', 'vergi_no': 'Vergi / TC No', 'notlar': 'Notlar',
  };
  late final Map<String, TextEditingController> k = {for (final a in alanlar) a: TextEditingController()};
  String tip = 'Müşteri';
  static const tipler = ['Müşteri', 'Tedarikçi', 'Müşteri + Tedarikçi', 'Kurum', 'Personel', 'Diğer'];

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      DB.tek('SELECT * FROM cari WHERE id=?', [widget.id]).then((c) {
        if (c == null) return;
        for (final a in alanlar) {
          k[a]!.text = '${c[a] ?? ''}';
        }
        setState(() => tip = tipler.contains(c['tip']) ? c['tip'] as String : 'Diğer');
      });
    }
  }

  Future<void> kaydet() async {
    if (k['unvan']!.text.trim().isEmpty) return mesaj(context, 'Ünvan zorunlu');
    final m = {for (final a in alanlar) a: k[a]!.text.trim(), 'tip': tip};
    if (widget.id == null) {
      await DB.ekle('cari', m);
    } else {
      await DB.guncelle('cari', m, widget.id!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.id == null ? 'Hesap Tanımla' : 'Cari Düzenle'), actions: [
          if (widget.id != null)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final n = await DB.tek('SELECT COUNT(*) n FROM cari_hareket WHERE cari_id=?', [widget.id]);
                  if (!context.mounted) return;
                  if ((n?['n'] as int? ?? 0) > 0) return mesaj(context, 'Hareketi olan cari silinemez.');
                  if (await onay(context, 'Cari silinsin mi?')) {
                    await DB.sil('cari', widget.id!);
                    if (context.mounted) Navigator.pop(context);
                  }
                }),
          IconButton(icon: const Icon(Icons.check), onPressed: kaydet),
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in alanlar.take(2)) Girdi(k[a]!, etiket[a]!),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<String>(
              value: tip,
              decoration: const InputDecoration(labelText: 'Hesap Tipi'),
              items: tipler.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => tip = v!),
            ),
          ),
          for (final a in alanlar.skip(2)) Girdi(k[a]!, etiket[a]!, satir: a == 'adres' || a == 'notlar' ? 2 : 1),
        ]),
      );
}

/// Tüm kasa / banka / cari işlemleri için ortak form
class IslemForm extends StatefulWidget {
  final String kod;
  final int? cariId;
  const IslemForm(this.kod, {super.key, this.cariId});
  @override
  State<IslemForm> createState() => _IslemFormState();
}

class _IslemFormState extends State<IslemForm> {
  late final IT t = islemler[widget.kod]!;
  String tarih = bugun();
  Map<String, Object?>? hesap, karsiHesap, cari, karsiCari;
  final tutar = TextEditingController(), aciklama = TextEditingController(), kategori = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.cariId != null) {
      DB.tek('SELECT id, unvan ad FROM cari WHERE id=?', [widget.cariId]).then((c) => setState(() => cari = c));
    }
    if (t.hesap != 0) {
      DB.tek('SELECT id, ad FROM hesap WHERE tip=IFNULL(?, tip) ORDER BY tip DESC, id LIMIT 1', [t.hesapTip])
          .then((h) => setState(() => hesap = h));
    }
    if (t.karsi != 0) {
      DB.tek('SELECT id, ad FROM hesap WHERE tip=? ORDER BY id DESC LIMIT 1', [t.karsiTip ?? 'kasa'])
          .then((h) => setState(() => karsiHesap = h));
    }
  }

  Future<void> kaydet() async {
    final tt = sy(tutar.text);
    if (tt <= 0) return mesaj(context, 'Tutar girin');
    if (t.hesap != 0 && hesap == null) return mesaj(context, 'Hesap seçin');
    if (t.karsi != 0 && karsiHesap == null) return mesaj(context, '2. hesabı seçin');
    if (t.cari != 0 && cari == null) return mesaj(context, 'Cari seçin');
    if (t.karsiCari != 0 && karsiCari == null) return mesaj(context, '2. cariyi seçin');
    await Servis.islemKaydet(widget.kod,
        hesap: hesap?['id'] as int?,
        karsiHesap: karsiHesap?['id'] as int?,
        cari: cari?['id'] as int?,
        karsiCari: karsiCari?['id'] as int?,
        tarih: tarih,
        tutar: tt,
        aciklama: aciklama.text.trim(),
        kategori: kategori.text.trim().isEmpty ? null : kategori.text.trim());
    if (mounted) {
      mesaj(context, '${t.ad} kaydedildi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t.ad), actions: [IconButton(icon: const Icon(Icons.check), onPressed: kaydet)]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          if (t.not != null) Card(child: Padding(padding: const EdgeInsets.all(10), child: Text(t.not!))),
          SecimAlani('Tarih', gTarih(tarih), () async {
            final x = await tarihSec(context, tarih);
            if (x != null) setState(() => tarih = x);
          }, ikon: Icons.event),
          if (t.hesap != 0)
            SecimAlani(t.karsi != 0 && t.karsiTip == t.hesapTip ? '1. Hesap (çıkan)' : 'Kasa / Banka', hesap?['ad'] as String?, () async {
              final x = await hesapSec(context, tip: t.hesapTip);
              if (x != null) setState(() => hesap = x);
            }),
          if (t.karsi != 0)
            SecimAlani(t.karsiTip == t.hesapTip ? '2. Hesap (giren)' : (t.karsiTip == 'kasa' ? 'Kasa' : 'Hesap'),
                karsiHesap?['ad'] as String?, () async {
              final x = await hesapSec(context, tip: t.karsiTip);
              if (x != null) setState(() => karsiHesap = x);
            }),
          if (t.cari != 0)
            SecimAlani(t.karsiCari != 0 ? '1. Cari (alacaklandırılan)' : 'Cari Hesap', cari?['ad'] as String?, () async {
              final x = await cariSec(context);
              if (x != null) setState(() => cari = x);
            }),
          if (t.karsiCari != 0)
            SecimAlani('2. Cari (borçlandırılan)', karsiCari?['ad'] as String?, () async {
              final x = await cariSec(context);
              if (x != null) setState(() => karsiCari = x);
            }),
          Girdi(tutar, 'Tutar (₺)', sayi: true),
          if (t.kategori) Girdi(kategori, 'Kategori (Kira, Elektrik, SGK, Vergi, Yakıt...)'),
          Girdi(aciklama, 'Açıklama', satir: 2),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: kaydet, icon: const Icon(Icons.save), label: const Text('Kaydet')),
        ]),
      );
}

/// Çoklu Borç/Alacak Dekontu ve Çoklu Ödeme/Tahsilat
class CokluIslem extends StatefulWidget {
  final bool odemeTahsilat;
  const CokluIslem({super.key, required this.odemeTahsilat});
  @override
  State<CokluIslem> createState() => _CokluIslemState();
}

class _CokluIslemState extends State<CokluIslem> {
  String tarih = bugun();
  Map<String, Object?>? hesap;
  final satirlar = <Map<String, Object?>>[];

  Future<void> satirEkle() async {
    final c = await cariSec(context);
    if (c == null || !mounted) return;
    String kod = widget.odemeTahsilat ? 'tahsilat' : 'borc_dekont';
    final tut = TextEditingController(), ac = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, ss) => AlertDialog(
          title: Text('${c['ad']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: widget.odemeTahsilat
                  ? const [ButtonSegment(value: 'tahsilat', label: Text('Tahsilat')), ButtonSegment(value: 'odeme', label: Text('Ödeme'))]
                  : const [ButtonSegment(value: 'borc_dekont', label: Text('Borç')), ButtonSegment(value: 'alacak_dekont', label: Text('Alacak'))],
              selected: {kod},
              onSelectionChanged: (s) => ss(() => kod = s.first),
            ),
            Girdi(tut, 'Tutar', sayi: true),
            Girdi(ac, 'Açıklama'),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ekle'))],
        ),
      ),
    );
    if (ok == true && sy(tut.text) > 0) {
      setState(() => satirlar.add({'cari': c['id'], 'ad': c['ad'], 'kod': kod, 'tutar': sy(tut.text), 'aciklama': ac.text}));
    }
  }

  Future<void> kaydet() async {
    if (satirlar.isEmpty) return;
    if (widget.odemeTahsilat && hesap == null) return mesaj(context, 'Kasa/banka seçin');
    final d = await DB.db;
    await d.transaction((tx) async {
      for (final s in satirlar) {
        await Servis.islemKaydet(s['kod'] as String,
            cari: s['cari'] as int, hesap: hesap?['id'] as int?, tarih: tarih, tutar: s['tutar'] as double,
            aciklama: s['aciklama'] as String?, tx: tx);
      }
    });
    if (mounted) {
      mesaj(context, '${satirlar.length} işlem kaydedildi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.odemeTahsilat ? 'Çoklu Ödeme/Tahsilat' : 'Çoklu Borç/Alacak Dekontu'),
            actions: [IconButton(icon: const Icon(Icons.check), onPressed: kaydet)]),
        floatingActionButton: FloatingActionButton.extended(onPressed: satirEkle, icon: const Icon(Icons.add), label: const Text('Satır')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          SecimAlani('Tarih', gTarih(tarih), () async {
            final x = await tarihSec(context, tarih);
            if (x != null) setState(() => tarih = x);
          }, ikon: Icons.event),
          if (widget.odemeTahsilat)
            SecimAlani('Kasa / Banka', hesap?['ad'] as String?, () async {
              final x = await hesapSec(context);
              if (x != null) setState(() => hesap = x);
            }),
          ...satirlar.asMap().entries.map((e) => ListTile(
                title: Text('${e.value['ad']}'),
                subtitle: Text('${islemler[e.value['kod']]!.ad}  ${e.value['aciklama']}'),
                trailing: Text(para(e.value['tutar'])),
                onLongPress: () => setState(() => satirlar.removeAt(e.key)),
              )),
          if (satirlar.isNotEmpty)
            ListTile(
                title: const Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(para(satirlar.fold(0.0, (a, s) => a + (s['tutar'] as double))))),
          const Padding(padding: EdgeInsets.all(8), child: Text('Satırı silmek için uzun basın.', style: TextStyle(fontSize: 12))),
        ]),
      );
}
