import 'package:flutter/material.dart';

import 'db.dart';
import 'ortak.dart';
import 'servis.dart';

/// Barkodla / aramayla hızlı satış ekranı (perakende kasa)
class HizliSatis extends StatefulWidget {
  final bool iade;
  const HizliSatis({super.key, this.iade = false});
  @override
  State<HizliSatis> createState() => _HizliSatisState();
}

class _HizliSatisState extends State<HizliSatis> {
  final ara = TextEditingController();
  List<Map<String, Object?>> sonuc = [];
  final sepet = <Map<String, Object?>>[];

  Future<void> bul(String v) async {
    final n = v.trim();
    if (n.isEmpty) return setState(() => sonuc = []);
    final tam = await DB.tek('SELECT * FROM urun WHERE barkod=? OR kod=? LIMIT 1', [n, n]);
    if (tam != null) {
      ekle(tam);
      ara.clear();
      return setState(() => sonuc = []);
    }
    final r = await DB.q('SELECT * FROM urun WHERE ad LIKE ? OR kod LIKE ? ORDER BY ad LIMIT 30', ['%$n%', '%$n%']);
    setState(() => sonuc = r);
  }

  void ekle(Map<String, Object?> u) {
    final i = sepet.indexWhere((s) => s['urun_id'] == u['id']);
    setState(() {
      if (i >= 0) {
        sepet[i]['miktar'] = sy(sepet[i]['miktar']) + 1;
      } else {
        sepet.add({'urun_id': u['id'], 'urun_ad': u['ad'], 'birim': u['birim'], 'miktar': 1.0, 'fiyat': sy(u['satis_fiyat']), 'kdv': sy(u['kdv']), 'iskonto': 0.0});
      }
    });
  }

  double get toplam => sepet.fold(0.0, (a, s) => a + sy(s['miktar']) * sy(s['fiyat']) * (1 + sy(s['kdv']) / 100));

  Future<void> bitir(String sekil) async {
    if (sepet.isEmpty) return;
    Map<String, Object?>? cari;
    int? hesap;
    if (sekil == 'veresiye') {
      cari = await cariSec(context);
      if (cari == null) return;
    } else {
      hesap = await Servis.ilkHesap(sekil == 'nakit' ? 'kasa' : 'banka');
    }
    final tur = widget.iade ? 'hizli_satis_iade' : 'hizli_satis';
    await Servis.belgeKaydet({
      'tur': tur, 'no': await Servis.sonrakiNo(tur), 'tarih': bugun(), 'depo_id': 1, 'cari_id': cari?['id'],
      'odeme': sekil == 'veresiye' ? 'acik' : 'pesin', 'hesap_id': hesap, 'aciklama': sekil == 'kart' ? 'Kredi kartı' : sekil == 'nakit' ? 'Nakit' : 'Veresiye',
    }, sepet);
    if (!mounted) return;
    mesaj(context, '${widget.iade ? 'İade' : 'Satış'} tamamlandı: ${para(toplam)}');
    setState(() => sepet.clear());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.iade ? 'Hızlı Satış İade' : 'Hızlı Satış'), actions: [
          if (sepet.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () => setState(() => sepet.clear())),
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: ara,
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.qr_code_scanner), hintText: 'Barkod okut veya ürün adı yaz'),
              onChanged: (v) => v.length >= 2 ? bul(v) : null,
              onSubmitted: bul,
            ),
          ),
          if (sonuc.isNotEmpty)
            SizedBox(
              height: 160,
              child: ListView(
                  children: sonuc
                      .map((u) => ListTile(
                          dense: true,
                          title: Text('${u['ad']}'),
                          trailing: Text(para(sy(u['satis_fiyat']) * (1 + sy(u['kdv']) / 100))),
                          onTap: () {
                            ekle(u);
                            ara.clear();
                            setState(() => sonuc = []);
                          }))
                      .toList()),
            ),
          const Divider(),
          Expanded(
            child: ListView(
              children: sepet.asMap().entries.map((e) {
                final s = e.value;
                return ListTile(
                  title: Text('${s['urun_ad']}'),
                  subtitle: Text('${para(sy(s['fiyat']) * (1 + sy(s['kdv']) / 100))} (KDV dahil)'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                              final m = sy(s['miktar']) - 1;
                              if (m <= 0) {
                                sepet.removeAt(e.key);
                              } else {
                                s['miktar'] = m;
                              }
                            })),
                    Text(miktarS(s['miktar']), style: const TextStyle(fontSize: 16)),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => s['miktar'] = sy(s['miktar']) + 1)),
                  ]),
                );
              }).toList(),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              top: false,
              child: Column(children: [
                Row(children: [
                  const Text('TOPLAM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(para(toplam), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: () => bitir('nakit'), icon: const Icon(Icons.payments), label: const Text('Nakit'))),
                  const SizedBox(width: 6),
                  Expanded(child: FilledButton.icon(onPressed: () => bitir('kart'), icon: const Icon(Icons.credit_card), label: const Text('Kart'))),
                  const SizedBox(width: 6),
                  Expanded(child: OutlinedButton.icon(onPressed: () => bitir('veresiye'), icon: const Icon(Icons.person), label: const Text('Veresiye'))),
                ]),
              ]),
            ),
          ),
        ]),
      );
}

class FiyatGor extends StatefulWidget {
  const FiyatGor({super.key});
  @override
  State<FiyatGor> createState() => _FiyatGorState();
}

class _FiyatGorState extends State<FiyatGor> {
  Map<String, Object?>? u;
  double stok = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fiyat Gör')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.qr_code_scanner), hintText: 'Barkod / kod / ad'),
              onSubmitted: (v) async {
                final r = await DB.tek('SELECT * FROM urun WHERE barkod=? OR kod=? OR ad LIKE ? LIMIT 1', [v.trim(), v.trim(), '%${v.trim()}%']);
                stok = r == null ? 0 : await Servis.stok(r['id'] as int);
                setState(() => u = r);
              },
            ),
            const SizedBox(height: 40),
            if (u != null) ...[
              Text('${u!['ad']}', style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(para(sy(u!['satis_fiyat']) * (1 + sy(u!['kdv']) / 100)), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
              Text('KDV dahil • KDV hariç ${para(u!['satis_fiyat'])}'),
              const SizedBox(height: 12),
              Text('Stok: ${miktarS(stok)} ${u!['birim'] ?? ''}'),
            ],
          ]),
        ),
      );
}
