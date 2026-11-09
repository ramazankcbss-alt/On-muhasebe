import 'package:flutter/material.dart';

import 'db.dart';
import 'ortak.dart';
import 'servis.dart';

class ReceteListe extends StatefulWidget {
  const ReceteListe({super.key});
  @override
  State<ReceteListe> createState() => _ReceteListeState();
}

class _ReceteListeState extends State<ReceteListe> {
  List<Map<String, Object?>> l = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT r.*, u.ad urun, (SELECT COUNT(*) FROM recete_kalem WHERE recete_id=r.id) kalem FROM recete r LEFT JOIN urun u ON u.id=r.urun_id ORDER BY r.ad');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reçeteler')),
        floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceteForm()));
              yukle();
            }),
        body: ListView(
          children: l
              .map((r) => ListTile(
                    title: Text('${r['ad']}'),
                    subtitle: Text('Mamul: ${r['urun'] ?? '-'} • ${miktarS(r['miktar'])} birim için ${r['kalem']} kalem'),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceteForm(id: r['id'] as int)));
                      yukle();
                    },
                  ))
              .toList(),
        ),
      );
}

class ReceteForm extends StatefulWidget {
  final int? id;
  const ReceteForm({super.key, this.id});
  @override
  State<ReceteForm> createState() => _ReceteFormState();
}

class _ReceteFormState extends State<ReceteForm> {
  final ad = TextEditingController(), miktar = TextEditingController(text: '1');
  Map<String, Object?>? urun;
  List<Map<String, Object?>> kalemler = [];

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      () async {
        final r = await DB.tek('SELECT * FROM recete WHERE id=?', [widget.id]);
        if (r == null) return;
        ad.text = '${r['ad'] ?? ''}';
        miktar.text = miktarS(r['miktar']);
        urun = await DB.tek('SELECT id, ad FROM urun WHERE id=?', [r['urun_id']]);
        kalemler = (await DB.q('SELECT k.urun_id, k.miktar, u.ad FROM recete_kalem k JOIN urun u ON u.id=k.urun_id WHERE recete_id=?', [widget.id]))
            .map((e) => Map<String, Object?>.from(e))
            .toList();
        setState(() {});
      }();
    }
  }

  Future<void> kaydet() async {
    if (urun == null || kalemler.isEmpty) return mesaj(context, 'Mamul ve en az bir hammadde seçin');
    final d = await DB.db;
    await d.transaction((tx) async {
      final m = {'ad': ad.text.trim().isEmpty ? urun!['ad'] : ad.text.trim(), 'urun_id': urun!['id'], 'miktar': sy(miktar.text) == 0 ? 1 : sy(miktar.text)};
      int id;
      if (widget.id == null) {
        id = await tx.insert('recete', m);
      } else {
        id = widget.id!;
        await tx.update('recete', m, where: 'id=?', whereArgs: [id]);
        await tx.delete('recete_kalem', where: 'recete_id=?', whereArgs: [id]);
      }
      for (final k in kalemler) {
        await tx.insert('recete_kalem', {'recete_id': id, 'urun_id': k['urun_id'], 'miktar': k['miktar']});
      }
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reçete'), actions: [
          if (widget.id != null)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!await onay(context, 'Reçete silinsin mi?')) return;
                  await DB.sil('recete', widget.id!);
                  final d = await DB.db;
                  await d.delete('recete_kalem', where: 'recete_id=?', whereArgs: [widget.id]);
                  if (context.mounted) Navigator.pop(context);
                }),
          IconButton(icon: const Icon(Icons.check), onPressed: kaydet),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Hammadde'),
          onPressed: () async {
            final u = await urunSec(context);
            if (u == null || !context.mounted) return;
            final m = await metinSor(context, '${u['ad']} miktarı', ilk: '1', sayi: true);
            if (m != null) setState(() => kalemler.add({'urun_id': u['id'], 'ad': u['ad'], 'miktar': sy(m)}));
          },
        ),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          SecimAlani('Mamul (üretilen ürün)', urun?['ad'] as String?, () async {
            final u = await urunSec(context);
            if (u != null) setState(() => urun = u);
          }),
          Girdi(ad, 'Reçete adı'),
          Girdi(miktar, 'Reçete kaç birim mamul için?', sayi: true),
          const Text('Hammaddeler', style: TextStyle(fontWeight: FontWeight.bold)),
          ...kalemler.asMap().entries.map((e) => ListTile(
                title: Text('${e.value['ad']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(miktarS(e.value['miktar'])),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => kalemler.removeAt(e.key))),
                ]),
              )),
        ]),
      );
}

class UretimEmirleri extends StatefulWidget {
  const UretimEmirleri({super.key});
  @override
  State<UretimEmirleri> createState() => _UretimEmirleriState();
}

class _UretimEmirleriState extends State<UretimEmirleri> {
  List<Map<String, Object?>> l = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT e.*, r.ad recete, u.ad urun FROM uretim_emri e JOIN recete r ON r.id=e.recete_id LEFT JOIN urun u ON u.id=r.urun_id ORDER BY e.tarih DESC, e.id DESC');
    if (mounted) setState(() {});
  }

  Future<void> yeni() async {
    final r = await secim(context, 'Reçete Seç', 'SELECT id, ad FROM recete ORDER BY ad');
    if (r == null || !mounted) return;
    final m = await metinSor(context, 'Üretilecek miktar', ilk: '1', sayi: true);
    if (m == null || sy(m) <= 0) return;
    await DB.ekle('uretim_emri', {'recete_id': r['id'], 'tarih': bugun(), 'miktar': sy(m), 'depo_id': 1});
    yukle();
  }

  /// Hammaddeleri sarf fişiyle düşer, mamulü maliyetiyle stoğa alır.
  Future<void> tamamla(Map<String, Object?> e) async {
    final r = await DB.tek('SELECT * FROM recete WHERE id=?', [e['recete_id']]);
    if (r == null) return;
    final oran = sy(e['miktar']) / (sy(r['miktar']) == 0 ? 1 : sy(r['miktar']));
    final kalemler = await DB.q('SELECT k.urun_id, k.miktar, u.ad, u.birim FROM recete_kalem k JOIN urun u ON u.id=k.urun_id WHERE recete_id=?', [r['id']]);
    double maliyet = 0;
    final sarf = <Map<String, Object?>>[];
    for (final k in kalemler) {
      final mk = sy(k['miktar']) * oran;
      final f = await Servis.ortMaliyet(k['urun_id'] as int);
      maliyet += mk * f;
      sarf.add({'urun_id': k['urun_id'], 'miktar': mk, 'birim': k['birim'], 'fiyat': f, 'kdv': 0});
    }
    final kaynak = 'uretim:${e['id']}';
    final s1 = await Servis.belgeKaydet({'tur': 'sarf', 'no': await Servis.sonrakiNo('sarf'), 'tarih': bugun(), 'depo_id': e['depo_id'], 'aciklama': 'Üretim emri #${e['id']}'}, sarf);
    final s2 = await Servis.belgeKaydet({'tur': 'uretimden_giris', 'no': await Servis.sonrakiNo('uretimden_giris'), 'tarih': bugun(), 'depo_id': e['depo_id'], 'aciklama': 'Üretim emri #${e['id']}'}, [
      {'urun_id': r['urun_id'], 'miktar': sy(e['miktar']), 'fiyat': sy(e['miktar']) == 0 ? 0 : maliyet / sy(e['miktar']), 'kdv': 0}
    ]);
    final d = await DB.db;
    await d.rawUpdate('UPDATE belge SET kaynak=? WHERE id IN (?, ?)', [kaynak, s1, s2]);
    await DB.guncelle('uretim_emri', {'durum': 'Tamamlandı'}, e['id'] as int);
    if (mounted) mesaj(context, 'Üretim tamamlandı. Birim maliyet: ${para(sy(e['miktar']) == 0 ? 0 : maliyet / sy(e['miktar']))}');
    yukle();
  }

  Future<void> geriAl(Map<String, Object?> e) async {
    final b = await DB.q('SELECT grup FROM belge WHERE kaynak=?', ['uretim:${e['id']}']);
    for (final x in b) {
      await DB.grupSil(x['grup'] as String);
    }
    await DB.guncelle('uretim_emri', {'durum': 'Bekliyor'}, e['id'] as int);
    yukle();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Üretim Emri')),
        floatingActionButton: FloatingActionButton(onPressed: yeni, child: const Icon(Icons.add)),
        body: ListView(
          children: l
              .map((e) => ListTile(
                    title: Text('#${e['id']} ${e['urun'] ?? e['recete']} × ${miktarS(e['miktar'])}'),
                    subtitle: Text('${gTarih(e['tarih'])} • ${e['durum']}'),
                    trailing: e['durum'] == 'Bekliyor'
                        ? FilledButton(onPressed: () => tamamla(e), child: const Text('Üret'))
                        : TextButton(onPressed: () => geriAl(e), child: const Text('Geri al')),
                    onLongPress: () async {
                      if (e['durum'] != 'Bekliyor') return;
                      if (await onay(context, 'Emir silinsin mi?')) {
                        await DB.sil('uretim_emri', e['id'] as int);
                        yukle();
                      }
                    },
                  ))
              .toList(),
        ),
      );
}
