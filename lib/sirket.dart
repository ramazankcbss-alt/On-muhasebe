import 'package:flutter/material.dart';

import 'db.dart';
import 'ortak.dart';

class SirketBilgisi extends StatefulWidget {
  const SirketBilgisi({super.key});
  @override
  State<SirketBilgisi> createState() => _SirketBilgisiState();
}

class _SirketBilgisiState extends State<SirketBilgisi> {
  static const alanlar = {
    'kod': 'Firma Kodu *', 'unvan': 'Firma Ünvanı', 'adres': 'Adresi', 'adres2': 'Adres Devamı', 'tel': 'Telefon No',
    'faks': 'Faks No', 'gsm': 'Gsm No', 'vergi_dairesi': 'Vergi Dairesi', 'vergi_no': 'Vergi No', 'web': 'Web Adresi',
    'email': 'E-Mail Adresi', 'banka': 'Banka Adı', 'sube': 'Banka Şube', 'sube_kodu': 'Şube Kodu', 'hesap_no': 'Hesap No / IBAN',
    'notlar': 'Notlar',
  };
  late final k = {for (final a in alanlar.keys) a: TextEditingController()};

  @override
  void initState() {
    super.initState();
    DB.tek('SELECT * FROM sirket WHERE id=1').then((r) {
      if (r == null) return;
      for (final a in alanlar.keys) {
        k[a]!.text = '${r[a] ?? ''}';
      }
    });
  }

  Future<void> kaydet() async {
    if (k['kod']!.text.trim().isEmpty) return mesaj(context, 'Uyarı: Firma Kodunu boş bırakmayınız.');
    final m = {for (final a in alanlar.keys) a: k[a]!.text.trim()};
    final d = await DB.db;
    final n = await d.update('sirket', m, where: 'id=1');
    if (n == 0) await d.insert('sirket', {...m, 'id': 1});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Şirket Bilgisi'), actions: [IconButton(icon: const Icon(Icons.check), onPressed: kaydet)]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final e in alanlar.entries) Girdi(k[e.key]!, e.value, satir: e.key == 'notlar' ? 3 : 1),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: kaydet, child: const Text('Kaydet'))),
          ]),
        ]),
      );
}
