import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db.dart';
import 'excel_araclari.dart';

// ---------- Sayı / tarih yardımcıları ----------

final _paraF = NumberFormat('#,##0.00', 'tr_TR');
final _sayiF = NumberFormat('#,##0.###', 'tr_TR');

String para(Object? v) => _paraF.format(sy(v));
String miktarS(Object? v) => _sayiF.format(sy(v));

/// Türkçe ve İngilizce biçimli sayıları çözer: "1.250,50 TL", "1250.5", "₺ 3.000"
double sy(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  var s = v.toString().trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (s.isEmpty || s == '-') return 0;
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s) ?? 0;
}

final _db = DateFormat('yyyy-MM-dd');
String bugun() => _db.format(DateTime.now());
String tarihS(DateTime d) => _db.format(d);
String yilBasi() => '${DateTime.now().year}-01-01';

/// 'yyyy-MM-dd' → 'dd.MM.yyyy'
String gTarih(Object? s) {
  final t = s?.toString() ?? '';
  if (t.length >= 10 && t[4] == '-') return '${t.substring(8, 10)}.${t.substring(5, 7)}.${t.substring(0, 4)}';
  return t;
}

/// Çeşitli tarih biçimlerini 'yyyy-MM-dd' yapar. Çözemezse null.
String? tarihCoz(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  if (m != null) return _yap(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})').firstMatch(t);
  if (m != null) {
    var y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    return _yap(y, int.parse(m[2]!), int.parse(m[1]!));
  }
  final n = double.tryParse(t.replaceAll(',', '.'));
  if (n != null && n > 20000 && n < 80000) {
    return tarihS(DateTime(1899, 12, 30).add(Duration(days: n.floor())));
  }
  return null;
}

String? _yap(int y, int a, int g) {
  if (a < 1 || a > 12 || g < 1 || g > 31) return null;
  return '$y-${a.toString().padLeft(2, '0')}-${g.toString().padLeft(2, '0')}';
}

/// Türkçe karakterleri sadeleştirip karşılaştırma anahtarı üretir.
String normal(String s) {
  var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const m = {'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c'};
  m.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

// ---------- Basit diyaloglar ----------

void mesaj(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> onay(BuildContext c, String m) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(m),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Evet')),
      ],
    ),
  );
  return r == true;
}

Future<String?> tarihSec(BuildContext c, String? mevcut) async {
  final ilk = DateTime.tryParse(mevcut ?? '') ?? DateTime.now();
  final d = await showDatePicker(
      context: c, initialDate: ilk, firstDate: DateTime(2000), lastDate: DateTime(2100));
  return d == null ? null : tarihS(d);
}

/// Aranabilir seçim listesi. sql sonucu 'id' ve [goster] alanını içermeli.
Future<Map<String, Object?>?> secim(BuildContext c, String baslik, String sql,
    {String goster = 'ad', String? alt, List<Object?>? args, Future<Map<String, Object?>?> Function()? yeni}) {
  return showDialog<Map<String, Object?>>(
    context: c,
    builder: (_) => _SecimDialog(baslik, sql, goster, alt, args, yeni),
  );
}

class _SecimDialog extends StatefulWidget {
  final String baslik, sql, goster;
  final String? alt;
  final List<Object?>? args;
  final Future<Map<String, Object?>?> Function()? yeni;
  const _SecimDialog(this.baslik, this.sql, this.goster, this.alt, this.args, this.yeni);
  @override
  State<_SecimDialog> createState() => _SecimDialogState();
}

class _SecimDialogState extends State<_SecimDialog> {
  List<Map<String, Object?>> tum = [];
  String ara = '';
  @override
  void initState() {
    super.initState();
    DB.q(widget.sql, widget.args).then((r) => setState(() => tum = r));
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final liste = tum
        .where((r) => n.isEmpty || normal(r.values.map((e) => e ?? '').join(' ')).contains(n))
        .toList();
    return AlertDialog(
      title: Text(widget.baslik),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ara'),
            onChanged: (v) => setState(() => ara = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: liste.isEmpty
                ? const Center(child: Text('Kayıt yok'))
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) {
                      final r = liste[i];
                      return ListTile(
                        dense: true,
                        title: Text('${r[widget.goster] ?? ''}'),
                        subtitle: widget.alt == null ? null : Text('${r[widget.alt] ?? ''}'),
                        onTap: () => Navigator.pop(context, r),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        if (widget.yeni != null)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yeni'),
            onPressed: () async {
              final r = await widget.yeni!();
              if (r != null && context.mounted) Navigator.pop(context, r);
            },
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }
}

Future<Map<String, Object?>?> cariSec(BuildContext c) => secim(c, 'Cari Seç',
    'SELECT id, unvan AS ad, IFNULL(kod,\'\') || \'  \' || IFNULL(tel,\'\') AS alt FROM cari ORDER BY unvan',
    alt: 'alt', yeni: () async {
  final ad = await metinSor(c, 'Yeni cari ünvanı');
  if (ad == null || ad.isEmpty) return null;
  final id = await DB.ekle('cari', {'unvan': ad});
  return {'id': id, 'ad': ad};
});

Future<Map<String, Object?>?> urunSec(BuildContext c) => secim(
    c,
    'Ürün Seç',
    '''SELECT u.id, u.ad, u.kod, u.birim, u.kdv, u.alis_fiyat, u.satis_fiyat,
       IFNULL(u.kod,'') || '  Stok: ' || IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0)
       || '  Fiyat: ' || u.satis_fiyat AS alt FROM urun u ORDER BY u.ad''',
    alt: 'alt');

Future<Map<String, Object?>?> hesapSec(BuildContext c, {String? tip}) => secim(
    c,
    tip == 'banka' ? 'Banka Hesabı Seç' : tip == 'kasa' ? 'Kasa Seç' : 'Kasa / Banka Seç',
    'SELECT id, ad, CASE tip WHEN \'kasa\' THEN \'Kasa\' ELSE \'Banka\' END AS alt FROM hesap ${tip == null ? '' : 'WHERE tip=?'} ORDER BY tip DESC, ad',
    alt: 'alt',
    args: tip == null ? null : [tip]);

Future<Map<String, Object?>?> depoSec(BuildContext c) =>
    secim(c, 'Depo Seç', 'SELECT id, ad FROM depo ORDER BY id');

Future<String?> metinSor(BuildContext c, String baslik, {String ilk = '', bool sayi = false}) {
  final k = TextEditingController(text: ilk);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(baslik),
      content: TextField(
        controller: k,
        autofocus: true,
        keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, k.text.trim()), child: const Text('Tamam')),
      ],
    ),
  );
}

/// Seçilmiş bir kaydı gösteren dokunulabilir alan
class SecimAlani extends StatelessWidget {
  final String etiket;
  final String? deger;
  final VoidCallback onTap;
  final VoidCallback? temizle;
  final IconData ikon;
  const SecimAlani(this.etiket, this.deger, this.onTap,
      {super.key, this.temizle, this.ikon = Icons.arrow_drop_down});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: etiket,
              suffixIcon: (temizle != null && deger != null)
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: temizle)
                  : Icon(ikon),
            ),
            child: Text(deger ?? 'Seçiniz', style: deger == null ? TextStyle(color: Theme.of(context).hintColor) : null),
          ),
        ),
      );
}

class Girdi extends StatelessWidget {
  final TextEditingController k;
  final String etiket;
  final bool sayi;
  final int satir;
  const Girdi(this.k, this.etiket, {super.key, this.sayi = false, this.satir = 1});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: k,
          maxLines: satir,
          keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
          decoration: InputDecoration(labelText: etiket),
        ),
      );
}

// ---------- Genel rapor / liste ekranı ----------

class Kolon {
  final String alan, ad;
  final bool para, sayi, tarih;
  const Kolon(this.alan, this.ad, {this.para = false, this.sayi = false, this.tarih = false});
  // Not: 'para' alanı üst seviye para() fonksiyonunu gölgelediği için para2 kullanılır.
  String bicim(Object? v) => para
      ? (v == null ? '' : para2(v))
      : sayi
          ? miktarS(v)
          : tarih
              ? gTarih(v)
              : '${v ?? ''}';
}

String para2(Object? v) => para(v);

typedef VeriFn = Future<List<Map<String, Object?>>> Function(String bas, String bit);

class RaporEkrani extends StatefulWidget {
  final String baslik;
  final List<Kolon> kolonlar;
  final VeriFn veri;
  final bool tarihli;
  final Future<void> Function(BuildContext c, Map<String, Object?> satir)? tikla;
  final Widget? ust;
  final Widget? Function(BuildContext c, VoidCallback yenile)? fab;
  const RaporEkrani(
      {super.key,
      required this.baslik,
      required this.kolonlar,
      required this.veri,
      this.tarihli = true,
      this.tikla,
      this.ust,
      this.fab});
  @override
  State<RaporEkrani> createState() => _RaporEkraniState();
}

class _RaporEkraniState extends State<RaporEkrani> {
  String bas = yilBasi(), bit = bugun(), ara = '';
  List<Map<String, Object?>>? satirlar;

  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    final r = await widget.veri(bas, bit);
    if (mounted) setState(() => satirlar = r);
  }

  List<Map<String, Object?>> get suzulmus {
    final n = normal(ara);
    final s = satirlar ?? [];
    if (n.isEmpty) return s;
    return s.where((r) => normal(widget.kolonlar.map((k) => r[k.alan] ?? '').join(' ')).contains(n)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final liste = suzulmus;
    final toplamlar = <String, double>{};
    for (final k in widget.kolonlar.where((k) => k.para)) {
      toplamlar[k.alan] = liste.fold(0.0, (a, r) => a + sy(r[k.alan]));
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik), actions: [
        IconButton(
          tooltip: 'Excel olarak paylaş',
          icon: const Icon(Icons.ios_share),
          onPressed: () => excelPaylas(
              widget.baslik,
              widget.kolonlar.map((k) => k.ad).toList(),
              liste
                  .map((r) => widget.kolonlar
                      .map<Object?>((k) => (k.para || k.sayi) ? sy(r[k.alan]) : k.bicim(r[k.alan]))
                      .toList())
                  .toList()),
        ),
      ]),
      floatingActionButton: widget.fab?.call(context, yukle),
      body: Column(children: [
        if (widget.ust != null) widget.ust!,
        if (widget.tarihli)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(gTarih(bas)),
                      onPressed: () async {
                        final t = await tarihSec(context, bas);
                        if (t != null) {
                          bas = t;
                          yukle();
                        }
                      })),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
              Expanded(
                  child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(gTarih(bit)),
                      onPressed: () async {
                        final t = await tarihSec(context, bit);
                        if (t != null) {
                          bit = t;
                          yukle();
                        }
                      })),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Listede ara'),
            onChanged: (v) => setState(() => ara = v),
          ),
        ),
        Expanded(
          child: satirlar == null
              ? const Center(child: CircularProgressIndicator())
              : liste.isEmpty
                  ? const Center(child: Text('Kayıt bulunamadı'))
                  : RefreshIndicator(
                      onRefresh: yukle,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowHeight: 40,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 52,
                            columnSpacing: 18,
                            columns: widget.kolonlar
                                .map((k) => DataColumn(label: Text(k.ad), numeric: k.para || k.sayi))
                                .toList(),
                            rows: [
                              ...liste.take(1500).map((r) => DataRow(
                                    onSelectChanged: widget.tikla == null
                                        ? null
                                        : (_) async {
                                            await widget.tikla!(context, r);
                                            yukle();
                                          },
                                    cells: widget.kolonlar.map((k) {
                                      final v = r[k.alan];
                                      final neg = (k.para || k.sayi) && sy(v) < 0;
                                      return DataCell(Text(k.bicim(v),
                                          style: neg ? const TextStyle(color: Colors.red) : null));
                                    }).toList(),
                                  )),
                              if (toplamlar.isNotEmpty)
                                DataRow(
                                  color: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
                                  cells: widget.kolonlar.asMap().entries.map((e) {
                                    final k = e.value;
                                    if (k.para) {
                                      return DataCell(Text(para(toplamlar[k.alan]),
                                          style: const TextStyle(fontWeight: FontWeight.bold)));
                                    }
                                    return DataCell(Text(e.key == 0 ? 'TOPLAM (${liste.length})' : '',
                                        style: const TextStyle(fontWeight: FontWeight.bold)));
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

/// Hareket satırına dokununca: bağlı işlemin tamamını silme seçeneği
Future<void> hareketTikla(BuildContext c, Map<String, Object?> r) async {
  final g = r['grup'] as String?;
  if (g == null) return;
  final belge = await DB.tek('SELECT id FROM belge WHERE grup=?', [g]);
  if (!c.mounted) return;
  final sil = await onay(
      c,
      belge != null
          ? 'Bu hareket bir belgeye bağlı. Belge ve bağlı tüm hareketleri silinsin mi?'
          : 'Bu işlem ve bağlı tüm hareketler (cari, kasa/banka, stok) silinsin mi?');
  if (sil) await DB.grupSil(g);
}

/// Anahtar-değer özet ekranı (Genel Durum, Kar/Zarar özet vb.)
class OzetEkrani extends StatefulWidget {
  final String baslik;
  final Future<List<MapEntry<String, Object?>>> Function(String bas, String bit) veri;
  final bool tarihli;
  const OzetEkrani({super.key, required this.baslik, required this.veri, this.tarihli = true});
  @override
  State<OzetEkrani> createState() => _OzetEkraniState();
}

class _OzetEkraniState extends State<OzetEkrani> {
  String bas = yilBasi(), bit = bugun();
  List<MapEntry<String, Object?>>? v;
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    final r = await widget.veri(bas, bit);
    if (mounted) setState(() => v = r);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.baslik), actions: [
          IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: v == null
                  ? null
                  : () => excelPaylas(widget.baslik, ['Kalem', 'Tutar'],
                      v!.map((e) => [e.key, e.value is num ? e.value : e.value?.toString()]).toList())),
        ]),
        body: v == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                if (widget.tarihli)
                  ListTile(
                    leading: const Icon(Icons.date_range),
                    title: Text('${gTarih(bas)} – ${gTarih(bit)}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final b = await tarihSec(context, bas);
                      if (b == null || !context.mounted) return;
                      final s = await tarihSec(context, bit);
                      bas = b;
                      if (s != null) bit = s;
                      yukle();
                    },
                  ),
                ...v!.map((e) => e.value == null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                        child: Text(e.key,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)))
                    : ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text(e.value is num ? para(e.value) : '${e.value}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: e.value is num && (e.value as num) < 0 ? Colors.red : null)),
                      )),
              ]),
      );
}
