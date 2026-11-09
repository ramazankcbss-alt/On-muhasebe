import 'package:flutter/material.dart';

import 'db.dart';
import 'excel_araclari.dart';
import 'ortak.dart';
import 'servis.dart';

/// İrsaliye, Fatura, Fiş, Sipariş ve Stok fişleri listesi
class BelgeListe extends StatefulWidget {
  final String grup;
  final String baslik;
  const BelgeListe(this.grup, {super.key, required this.baslik});
  @override
  State<BelgeListe> createState() => _BelgeListeState();
}

class _BelgeListeState extends State<BelgeListe> {
  List<Map<String, Object?>> l = [];
  String? tur;
  String ara = '';
  late final turListe = grupTurleri(widget.grup);

  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    final kodlar = turListe.map((t) => "'${t.kod}'").join(',');
    l = await DB.q('''SELECT b.*, c.unvan FROM belge b LEFT JOIN cari c ON c.id=b.cari_id
      WHERE b.tur IN ($kodlar) ORDER BY b.tarih DESC, b.id DESC''');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final f = l.where((b) => (tur == null || b['tur'] == tur) && (n.isEmpty || normal('${b['no']} ${b['unvan'] ?? ''} ${b['aciklama'] ?? ''}').contains(n))).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik), actions: [
        IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => excelPaylas(widget.baslik, ['Tarih', 'Tür', 'No', 'Cari', 'Ara Toplam', 'KDV', 'Genel Toplam', 'Durum'],
                f.map((b) => [gTarih(b['tarih']), turlar[b['tur']]?.ad, b['no'], b['unvan'], sy(b['ara_toplam']) - sy(b['iskonto']), sy(b['kdv_toplam']), sy(b['genel_toplam']), b['durum']]).toList())),
      ]),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final t = turListe.length == 1
              ? turListe.first
              : await showModalBottomSheet<BT>(
                  context: context,
                  builder: (_) => ListView(shrinkWrap: true, children: turListe.map((t) => ListTile(title: Text(t.ad), onTap: () => Navigator.pop(context, t))).toList()));
          if (t == null || !context.mounted) return;
          await Navigator.push(context, MaterialPageRoute(builder: (_) => BelgeForm(t.kod)));
          yukle();
        },
      ),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('Tümü'), selected: tur == null, onSelected: (_) => setState(() => tur = null))),
            ...turListe.map((t) => Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(t.ad), selected: tur == t.kod, onSelected: (_) => setState(() => tur = t.kod)))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'No, cari, açıklama'), onChanged: (v) => setState(() => ara = v)),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: f.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = f[i];
              return ListTile(
                title: Text('${b['no']}  ${b['unvan'] ?? ''}'),
                subtitle: Text('${gTarih(b['tarih'])} • ${turlar[b['tur']]?.ad ?? b['tur']}${widget.grup == 'Sipariş' ? ' • ${b['durum']}' : ''}'),
                trailing: Text(para(b['genel_toplam']), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => BelgeForm(b['tur'] as String, id: b['id'] as int)));
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

class BelgeForm extends StatefulWidget {
  final String tur;
  final int? id;
  final int? cariId;
  final Map<String, Object?>? onDolum;
  final List<Map<String, Object?>>? onSatirlar;
  const BelgeForm(this.tur, {super.key, this.id, this.cariId, this.onDolum, this.onSatirlar});
  @override
  State<BelgeForm> createState() => _BelgeFormState();
}

class _BelgeFormState extends State<BelgeForm> {
  late BT t = turlar[widget.tur]!;
  String tarih = bugun();
  String? vade;
  final no = TextEditingController(), aciklama = TextEditingController(), barkod = TextEditingController();
  Map<String, Object?>? cari, depo, hedefDepo, hesap;
  String odeme = 'acik';
  int? kaynakId;
  int stokEtkisiz = 0;
  String durum = 'Açık';
  List<Map<String, Object?>> satirlar = [];
  bool hazir = false;

  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    depo = await DB.tek('SELECT id, ad FROM depo ORDER BY id LIMIT 1');
    if (widget.id != null) {
      final b = await DB.tek('SELECT * FROM belge WHERE id=?', [widget.id]);
      if (b != null) await _doldur(b);
      satirlar = (await DB.q('SELECT s.*, u.ad urun_ad FROM belge_satir s LEFT JOIN urun u ON u.id=s.urun_id WHERE belge_id=? ORDER BY s.id', [widget.id]))
          .map((e) => Map<String, Object?>.from(e))
          .toList();
    } else {
      no.text = await Servis.sonrakiNo(widget.tur);
      if (widget.onDolum != null) await _doldur(widget.onDolum!);
      if (widget.onSatirlar != null) satirlar = widget.onSatirlar!.map((e) => Map<String, Object?>.from(e)).toList();
      if (widget.cariId != null) cari = await DB.tek('SELECT id, unvan ad FROM cari WHERE id=?', [widget.cariId]);
    }
    setState(() => hazir = true);
  }

  Future<void> _doldur(Map<String, Object?> b) async {
    if (widget.id != null) no.text = '${b['no'] ?? ''}';
    tarih = (b['tarih'] as String?) ?? tarih;
    vade = b['vade'] as String?;
    aciklama.text = '${b['aciklama'] ?? ''}';
    odeme = (b['odeme'] as String?) ?? 'acik';
    kaynakId = b['kaynak_id'] as int?;
    stokEtkisiz = (b['stok_etkisiz'] as int?) ?? 0;
    durum = (b['durum'] as String?) ?? 'Açık';
    if (b['cari_id'] != null) cari = await DB.tek('SELECT id, unvan ad FROM cari WHERE id=?', [b['cari_id']]);
    if (b['depo_id'] != null) depo = await DB.tek('SELECT id, ad FROM depo WHERE id=?', [b['depo_id']]);
    if (b['hedef_depo_id'] != null) hedefDepo = await DB.tek('SELECT id, ad FROM depo WHERE id=?', [b['hedef_depo_id']]);
    if (b['hesap_id'] != null) hesap = await DB.tek('SELECT id, ad FROM hesap WHERE id=?', [b['hesap_id']]);
  }

  bool get cariGerekli => t.cari != 0 || t.grup == 'Sipariş' || t.grup == 'İrsaliye';

  double get araT => satirlar.fold(0.0, (a, s) => a + sy(s['miktar']) * sy(s['fiyat']) * (1 - sy(s['iskonto']) / 100));
  double get kdvT => satirlar.fold(0.0, (a, s) => a + sy(s['miktar']) * sy(s['fiyat']) * (1 - sy(s['iskonto']) / 100) * sy(s['kdv']) / 100);

  Future<void> urunEkle([Map<String, Object?>? u]) async {
    u ??= await urunSec(context);
    if (u == null || !mounted) return;
    final s = await satirDialog({
      'urun_id': u['id'], 'urun_ad': u['ad'], 'miktar': 1.0, 'birim': u['birim'],
      'fiyat': sy(t.alis ? u['alis_fiyat'] : u['satis_fiyat']), 'kdv': sy(u['kdv']), 'iskonto': 0.0,
    });
    if (s != null) setState(() => satirlar.add(s));
  }

  Future<void> serbestEkle() async {
    final s = await satirDialog({'urun_id': null, 'aciklama': '', 'miktar': 1.0, 'birim': 'Adet', 'fiyat': 0.0, 'kdv': 20.0, 'iskonto': 0.0});
    if (s != null) setState(() => satirlar.add(s));
  }

  Future<void> barkodlaEkle(String v) async {
    final k = v.trim();
    if (k.isEmpty) return;
    final u = await DB.tek('SELECT * FROM urun WHERE barkod=? OR kod=? LIMIT 1', [k, k]);
    barkod.clear();
    if (!mounted) return;
    if (u == null) return mesaj(context, 'Ürün bulunamadı: $k');
    final var_ = satirlar.indexWhere((s) => s['urun_id'] == u['id']);
    if (var_ >= 0) {
      setState(() => satirlar[var_]['miktar'] = sy(satirlar[var_]['miktar']) + 1);
    } else {
      setState(() => satirlar.add({
            'urun_id': u['id'], 'urun_ad': u['ad'], 'miktar': 1.0, 'birim': u['birim'],
            'fiyat': sy(t.alis ? u['alis_fiyat'] : u['satis_fiyat']), 'kdv': sy(u['kdv']), 'iskonto': 0.0,
          }));
    }
  }

  Future<Map<String, Object?>?> satirDialog(Map<String, Object?> s) {
    final ac = TextEditingController(text: '${s['aciklama'] ?? ''}');
    final mk = TextEditingController(text: miktarS(s['miktar']));
    final fy = TextEditingController(text: sy(s['fiyat']).toStringAsFixed(2).replaceAll('.', ','));
    final kd = TextEditingController(text: miktarS(s['kdv']));
    final ik = TextEditingController(text: miktarS(s['iskonto']));
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s['urun_ad'] as String? ?? 'Hizmet / Serbest Satır'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Girdi(ac, s['urun_id'] == null ? 'Açıklama *' : 'Açıklama'),
            Row(children: [Expanded(child: Girdi(mk, 'Miktar', sayi: true)), const SizedBox(width: 8), Expanded(child: Girdi(fy, 'Birim Fiyat', sayi: true))]),
            Row(children: [Expanded(child: Girdi(kd, 'KDV %', sayi: true)), const SizedBox(width: 8), Expanded(child: Girdi(ik, 'İskonto %', sayi: true))]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () {
                if (s['urun_id'] == null && ac.text.trim().isEmpty) return;
                Navigator.pop(d, {...s, 'aciklama': ac.text.trim(), 'miktar': sy(mk.text), 'fiyat': sy(fy.text), 'kdv': sy(kd.text), 'iskonto': sy(ik.text)});
              },
              child: const Text('Tamam')),
        ],
      ),
    );
  }

  Future<void> kaydet() async {
    if (satirlar.isEmpty) return mesaj(context, 'En az bir satır ekleyin');
    if (t.cari != 0 && cari == null && !(t.kod.startsWith('hizli') && odeme != 'acik')) {
      return mesaj(context, 'Cari seçin');
    }
    if (odeme != 'acik' && hesap == null) return mesaj(context, 'Kasa/banka seçin');
    if (t.kod == 'depo_transfer' && hedefDepo == null) return mesaj(context, 'Hedef depoyu seçin');
    await Servis.belgeKaydet({
      'tur': t.kod, 'no': no.text.trim(), 'tarih': tarih, 'vade': vade, 'cari_id': cari?['id'], 'depo_id': depo?['id'],
      'hedef_depo_id': hedefDepo?['id'], 'aciklama': aciklama.text.trim(), 'odeme': odeme,
      'hesap_id': odeme == 'acik' ? null : hesap?['id'], 'stok_etkisiz': stokEtkisiz, 'durum': durum, 'kaynak_id': kaynakId,
    }, satirlar, id: widget.id);
    if (mounted) {
      mesaj(context, '${t.ad} kaydedildi');
      Navigator.pop(context, true);
    }
  }

  /// Sipariş → İrsaliye/Fatura, İrsaliye → Fatura
  Future<void> donustur() async {
    final hedefler = <BT>[];
    final satisMi = !t.alis;
    if (t.grup == 'Sipariş') {
      hedefler.addAll([turlar[satisMi ? 'satis_irsaliye' : 'alis_irsaliye']!, turlar[satisMi ? 'satis_fatura' : 'alis_fatura']!]);
    } else if (t.grup == 'İrsaliye') {
      final k = t.kod.replaceAll('irsaliye', 'fatura');
      if (turlar[k] != null) hedefler.add(turlar[k]!);
    }
    if (hedefler.isEmpty) return;
    final h = await showModalBottomSheet<BT>(
        context: context,
        builder: (_) => ListView(shrinkWrap: true, children: hedefler.map((x) => ListTile(leading: const Icon(Icons.transform), title: Text('${x.ad} oluştur'), onTap: () => Navigator.pop(context, x))).toList()));
    if (h == null || !mounted) return;
    await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => BelgeForm(h.kod,
                onDolum: {
                  'tarih': bugun(), 'cari_id': cari?['id'], 'depo_id': depo?['id'], 'aciklama': '${t.ad} ${no.text}',
                  'kaynak_id': widget.id, 'stok_etkisiz': t.grup == 'İrsaliye' ? 1 : 0,
                },
                onSatirlar: satirlar.map((s) => Map<String, Object?>.from(s)..remove('id')..remove('belge_id')).toList())));
  }

  @override
  Widget build(BuildContext context) {
    if (!hazir) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final ara = araT, kdv = kdvT;
    return Scaffold(
      appBar: AppBar(title: Text(t.ad), actions: [
        if (widget.id != null && (t.grup == 'Sipariş' || t.grup == 'İrsaliye'))
          IconButton(tooltip: 'Dönüştür', icon: const Icon(Icons.transform), onPressed: donustur),
        if (widget.id != null)
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await onay(context, 'Belge ve bağlı tüm hareketler silinsin mi?')) return;
                final b = await DB.tek('SELECT grup FROM belge WHERE id=?', [widget.id]);
                final g = b?['grup'] as String?;
                if (g != null) {
                  await DB.grupSil(g);
                } else {
                  await DB.sil('belge', widget.id!);
                }
                if (context.mounted) Navigator.pop(context, true);
              }),
        if (widget.id != null)
          IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () => excelPaylas('${t.ad} ${no.text}', ['Ürün/Hizmet', 'Miktar', 'Birim', 'Fiyat', 'İsk.%', 'KDV%', 'Tutar'],
                  [
                    ...satirlar.map((s) => [s['urun_ad'] ?? s['aciklama'], sy(s['miktar']), s['birim'], sy(s['fiyat']), sy(s['iskonto']), sy(s['kdv']), sy(s['miktar']) * sy(s['fiyat']) * (1 - sy(s['iskonto']) / 100)]),
                    ['Cari: ${cari?['ad'] ?? ''}', null, null, null, null, 'Ara Toplam', ara],
                    ['Tarih: ${gTarih(tarih)}', null, null, null, null, 'KDV', kdv],
                    [null, null, null, null, null, 'Genel Toplam', ara + kdv],
                  ])),
        IconButton(icon: const Icon(Icons.check), onPressed: kaydet),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(child: Girdi(no, 'Belge No')),
          const SizedBox(width: 8),
          Expanded(
              child: SecimAlani('Tarih', gTarih(tarih), () async {
            final x = await tarihSec(context, tarih);
            if (x != null) setState(() => tarih = x);
          }, ikon: Icons.event)),
        ]),
        if (cariGerekli)
          SecimAlani('Cari Hesap', cari?['ad'] as String?, () async {
            final x = await cariSec(context);
            if (x != null) setState(() => cari = x);
          }, temizle: () => setState(() => cari = null)),
        if (t.stok != 0 || t.kod == 'depo_transfer' || t.grup == 'İrsaliye')
          SecimAlani(t.kod == 'depo_transfer' ? 'Çıkış Deposu' : 'Depo', depo?['ad'] as String?, () async {
            final x = await depoSec(context);
            if (x != null) setState(() => depo = x);
          }),
        if (t.kod == 'depo_transfer')
          SecimAlani('Giriş Deposu', hedefDepo?['ad'] as String?, () async {
            final x = await depoSec(context);
            if (x != null) setState(() => hedefDepo = x);
          }),
        if (t.grup == 'Fatura')
          SecimAlani('Vade Tarihi', vade == null ? null : gTarih(vade), () async {
            final x = await tarihSec(context, vade ?? tarih);
            if (x != null) setState(() => vade = x);
          }, ikon: Icons.event, temizle: () => setState(() => vade = null)),
        if (stokEtkisiz == 1)
          const Card(child: Padding(padding: EdgeInsets.all(8), child: Text('Stok hareketi irsaliyede yapıldığı için bu belge stoku tekrar etkilemez.'))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: barkod,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.qr_code), hintText: 'Barkod / ürün kodu + Enter'),
              onSubmitted: barkodlaEkle,
            ),
          ),
          IconButton.filledTonal(onPressed: () => urunEkle(), icon: const Icon(Icons.add_shopping_cart), tooltip: 'Ürün ekle'),
          IconButton.filledTonal(onPressed: serbestEkle, icon: const Icon(Icons.post_add), tooltip: 'Hizmet / serbest satır'),
        ]),
        const SizedBox(height: 6),
        ...satirlar.asMap().entries.map((e) {
          final s = e.value;
          final tutar = sy(s['miktar']) * sy(s['fiyat']) * (1 - sy(s['iskonto']) / 100);
          return Card(
            child: ListTile(
              dense: true,
              title: Text('${s['urun_ad'] ?? s['aciklama']}'),
              subtitle: Text('${miktarS(s['miktar'])} ${s['birim'] ?? ''} × ${para(s['fiyat'])}  KDV %${miktarS(s['kdv'])}${sy(s['iskonto']) > 0 ? '  İsk %${miktarS(s['iskonto'])}' : ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(para(tutar)),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => satirlar.removeAt(e.key))),
              ]),
              onTap: () async {
                final y = await satirDialog(s);
                if (y != null) setState(() => satirlar[e.key] = y);
              },
            ),
          );
        }),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _top('Ara Toplam', ara),
              _top('KDV', kdv),
              _top('GENEL TOPLAM', ara + kdv, kalin: true),
            ]),
          ),
        ),
        if (t.cari != 0) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: odeme,
            decoration: const InputDecoration(labelText: 'Ödeme Şekli'),
            items: const [
              DropdownMenuItem(value: 'acik', child: Text('Açık hesap (veresiye)')),
              DropdownMenuItem(value: 'pesin', child: Text('Peşin (kasa / banka)')),
            ],
            onChanged: (v) async {
              setState(() => odeme = v!);
              if (v == 'pesin' && hesap == null) {
                final h = await DB.tek('SELECT id, ad FROM hesap ORDER BY tip DESC, id LIMIT 1');
                setState(() => hesap = h);
              }
            },
          ),
          if (odeme != 'acik')
            SecimAlani('Kasa / Banka', hesap?['ad'] as String?, () async {
              final x = await hesapSec(context);
              if (x != null) setState(() => hesap = x);
            }),
        ],
        if (t.grup == 'Sipariş')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              value: durum == 'Kapandı' ? 'Kapandı' : 'Açık',
              decoration: const InputDecoration(labelText: 'Sipariş Durumu'),
              items: const [DropdownMenuItem(value: 'Açık', child: Text('Açık (bekliyor)')), DropdownMenuItem(value: 'Kapandı', child: Text('Kapandı (teslim edildi)'))],
              onChanged: (v) => setState(() => durum = v!),
            ),
          ),
        Girdi(aciklama, 'Açıklama', satir: 2),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: kaydet, icon: const Icon(Icons.save), label: const Text('Kaydet')),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _top(String a, double v, {bool kalin = false}) => Row(children: [
        Expanded(child: Text(a, style: TextStyle(fontWeight: kalin ? FontWeight.bold : null))),
        Text(para(v), style: TextStyle(fontWeight: kalin ? FontWeight.bold : null, fontSize: kalin ? 17 : null)),
      ]);
}
