import 'package:flutter/material.dart';

import 'db.dart';
import 'ortak.dart';

/// Çek ve senetler: alınan (müşteriden) / verilen (tedarikçiye)
class CekListe extends StatefulWidget {
  const CekListe({super.key});
  @override
  State<CekListe> createState() => _CekListeState();
}

class _CekListeState extends State<CekListe> {
  String yon = 'Alınan';
  bool sadecePortfoy = false;
  List<Map<String, Object?>> l = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT k.*, c.unvan FROM cek_senet k LEFT JOIN cari c ON c.id=k.cari_id WHERE yon=? ORDER BY vade', [yon]);
    if (mounted) setState(() {});
  }

  Future<void> durumDegistir(Map<String, Object?> k) async {
    final alinan = k['yon'] == 'Alınan';
    final secenek = alinan
        ? ['Portföyde', 'Tahsil Edildi', 'Ciro Edildi', 'Karşılıksız / İade']
        : ['Portföyde', 'Ödendi', 'Karşılıksız / İade'];
    final s = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => ListView(shrinkWrap: true, children: [
              ListTile(title: Text('${k['tur']} ${k['no'] ?? ''} • ${para(k['tutar'])}'), subtitle: Text('Şu an: ${k['durum']}')),
              ...secenek.map((x) => ListTile(title: Text(x), onTap: () => Navigator.pop(context, x))),
              ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Kaydı sil'), onTap: () => Navigator.pop(context, 'sil')),
            ]));
    if (s == null || !mounted) return;
    final tutar = sy(k['tutar']);
    final d = await DB.db;
    if (s == 'sil') {
      if (!await onay(context, 'Çek/senet ve oluşturduğu cari hareket silinsin mi?')) return;
      if (k['durum_grup'] != null) await DB.grupSil(k['durum_grup'] as String);
      if (k['grup'] != null) await DB.grupSil(k['grup'] as String);
      await DB.sil('cek_senet', k['id'] as int);
      return yukle();
    }
    Map<String, Object?>? hesap, cari;
    if (s == 'Tahsil Edildi' || s == 'Ödendi') {
      hesap = await hesapSec(context);
      if (hesap == null) return;
    }
    if (s == 'Ciro Edildi') {
      if (!mounted) return;
      cari = await cariSec(context);
      if (cari == null) return;
    }
    final g = DB.yeniGrup();
    final h = hesap, cr = cari;
    await d.transaction((tx) async {
      if (k['durum_grup'] != null) await DB.grupSilTx(tx, k['durum_grup'] as String);
      final aciklama = '${k['tur']} ${k['no'] ?? ''} - $s';
      if (h != null) {
        await tx.insert('finans_hareket', {
          'hesap_id': h['id'], 'tarih': bugun(), 'tur': alinan ? 'Çek/Senet Tahsil' : 'Çek/Senet Ödeme', 'cari_id': k['cari_id'],
          'aciklama': aciklama, 'giris': alinan ? tutar : 0, 'cikis': alinan ? 0 : tutar, 'grup': g,
        });
      }
      if (cr != null) {
        await tx.insert('cari_hareket', {'cari_id': cr['id'], 'tarih': bugun(), 'tur': 'Çek Ciro', 'aciklama': aciklama, 'borc': tutar, 'alacak': 0, 'grup': g});
      }
      if (s.startsWith('Karşılıksız')) {
        // Ödeme geçersiz: cari hareketi tersine çevrilir
        await tx.insert('cari_hareket', {
          'cari_id': k['cari_id'], 'tarih': bugun(), 'tur': 'Karşılıksız ${k['tur']}', 'aciklama': aciklama,
          'borc': alinan ? tutar : 0, 'alacak': alinan ? 0 : tutar, 'grup': g,
        });
      }
      await tx.update('cek_senet', {'durum': s, 'durum_grup': s == 'Portföyde' ? null : g}, where: 'id=?', whereArgs: [k['id']]);
    });
    yukle();
  }

  @override
  Widget build(BuildContext context) {
    final f = l.where((k) => !sadecePortfoy || k['durum'] == 'Portföyde').toList();
    final toplam = f.where((k) => k['durum'] == 'Portföyde').fold(0.0, (a, k) => a + sy(k['tutar']));
    return Scaffold(
      appBar: AppBar(title: const Text('Çek ve Senetler')),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => CekForm(yon: yon)));
            yukle();
          }),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'Alınan', label: Text('Alınan (Müşteri)')), ButtonSegment(value: 'Verilen', label: Text('Verilen (Kendi)'))],
            selected: {yon},
            onSelectionChanged: (s) {
              yon = s.first;
              yukle();
            },
          ),
        ),
        SwitchListTile(dense: true, value: sadecePortfoy, title: const Text('Sadece portföydekiler / ödenmemişler'), onChanged: (v) => setState(() => sadecePortfoy = v)),
        ListTile(dense: true, title: const Text('Bekleyen toplam'), trailing: Text(para(toplam), style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: ListView(
            children: f.map((k) {
              final gecti = k['durum'] == 'Portföyde' && '${k['vade']}'.compareTo(bugun()) <= 0;
              return ListTile(
                leading: Icon(k['tur'] == 'Çek' ? Icons.money : Icons.description),
                title: Text('${k['unvan'] ?? ''}  ${k['no'] ?? ''}'),
                subtitle: Text('Vade ${gTarih(k['vade'])} • ${k['banka'] ?? ''} • ${k['durum']}', style: gecti ? const TextStyle(color: Colors.red) : null),
                trailing: Text(para(k['tutar']), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => durumDegistir(k),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class CekForm extends StatefulWidget {
  final String yon;
  const CekForm({super.key, required this.yon});
  @override
  State<CekForm> createState() => _CekFormState();
}

class _CekFormState extends State<CekForm> {
  String tur = 'Çek';
  late String yon = widget.yon;
  String tarih = bugun(), vade = bugun();
  Map<String, Object?>? cari;
  final no = TextEditingController(), banka = TextEditingController(), tutar = TextEditingController(), aciklama = TextEditingController();

  Future<void> kaydet() async {
    final t = sy(tutar.text);
    if (cari == null || t <= 0) return mesaj(context, 'Cari ve tutar zorunlu');
    final g = DB.yeniGrup();
    final d = await DB.db;
    await d.transaction((tx) async {
      await tx.insert('cek_senet', {
        'tur': tur, 'yon': yon, 'no': no.text.trim(), 'cari_id': cari!['id'], 'banka': banka.text.trim(), 'tarih': tarih,
        'vade': vade, 'tutar': t, 'aciklama': aciklama.text.trim(), 'grup': g,
      });
      // Alınan çek: müşterinin borcu kapanır (alacak). Verilen çek: tedarikçiye borcumuz kapanır (borç).
      await tx.insert('cari_hareket', {
        'cari_id': cari!['id'], 'tarih': tarih, 'tur': '${yon == 'Alınan' ? 'Alınan' : 'Verilen'} $tur',
        'aciklama': '$tur ${no.text} vade ${gTarih(vade)}', 'borc': yon == 'Verilen' ? t : 0, 'alacak': yon == 'Alınan' ? t : 0, 'grup': g,
      });
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Çek / Senet Girişi'), actions: [IconButton(icon: const Icon(Icons.check), onPressed: kaydet)]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'Çek', label: Text('Çek')), ButtonSegment(value: 'Senet', label: Text('Senet'))],
              selected: {tur},
              onSelectionChanged: (s) => setState(() => tur = s.first)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'Alınan', label: Text('Müşteriden alınan')), ButtonSegment(value: 'Verilen', label: Text('Tedarikçiye verilen'))],
              selected: {yon},
              onSelectionChanged: (s) => setState(() => yon = s.first)),
          SecimAlani('Cari', cari?['ad'] as String?, () async {
            final x = await cariSec(context);
            if (x != null) setState(() => cari = x);
          }),
          Girdi(no, 'Çek / Senet No'),
          Girdi(banka, 'Banka / Şube'),
          Row(children: [
            Expanded(
                child: SecimAlani('Düzenleme', gTarih(tarih), () async {
              final x = await tarihSec(context, tarih);
              if (x != null) setState(() => tarih = x);
            }, ikon: Icons.event)),
            const SizedBox(width: 8),
            Expanded(
                child: SecimAlani('Vade', gTarih(vade), () async {
              final x = await tarihSec(context, vade);
              if (x != null) setState(() => vade = x);
            }, ikon: Icons.event)),
          ]),
          Girdi(tutar, 'Tutar', sayi: true),
          Girdi(aciklama, 'Açıklama'),
        ]),
      );
}

class OrtalamaVade extends StatefulWidget {
  const OrtalamaVade({super.key});
  @override
  State<OrtalamaVade> createState() => _OrtalamaVadeState();
}

class _OrtalamaVadeState extends State<OrtalamaVade> {
  List<Map<String, Object?>> l = [];
  final secili = <int>{};
  @override
  void initState() {
    super.initState();
    DB.q("SELECT k.*, c.unvan FROM cek_senet k LEFT JOIN cari c ON c.id=k.cari_id WHERE durum='Portföyde' ORDER BY vade").then((r) => setState(() => l = r));
  }

  @override
  Widget build(BuildContext context) {
    final s = l.where((k) => secili.contains(k['id'])).toList();
    final toplam = s.fold(0.0, (a, k) => a + sy(k['tutar']));
    String sonuc = '-';
    if (toplam > 0) {
      final bugunD = DateTime.now();
      final agirlik = s.fold(0.0, (a, k) => a + sy(k['tutar']) * (DateTime.tryParse('${k['vade']}') ?? bugunD).difference(bugunD).inDays);
      final gun = (agirlik / toplam).round();
      sonuc = '${gTarih(tarihS(bugunD.add(Duration(days: gun))))}  ($gun gün)';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ortalama Vade')),
      body: Column(children: [
        Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(title: Text('Seçilen: ${s.length} adet • ${para(toplam)}'), subtitle: Text('Ortalama vade: $sonuc'))),
        Expanded(
          child: ListView(
              children: l
                  .map((k) => CheckboxListTile(
                        value: secili.contains(k['id']),
                        title: Text('${k['yon']} ${k['tur']} • ${k['unvan'] ?? ''}'),
                        subtitle: Text('Vade ${gTarih(k['vade'])} • ${para(k['tutar'])}'),
                        onChanged: (v) => setState(() => v == true ? secili.add(k['id'] as int) : secili.remove(k['id'])),
                      ))
                  .toList()),
        ),
      ]),
    );
  }
}
