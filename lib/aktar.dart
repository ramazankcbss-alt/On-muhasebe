import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'excel_araclari.dart';
import 'ortak.dart';
import 'servis.dart';

/// İçe aktarılabilecek alan: kod, ekranda görünen ad, otomatik eşleşme için eş anlamlı başlıklar
class HAlan {
  final String kod, ad;
  final List<String> es;
  final bool zorunlu;
  const HAlan(this.kod, this.ad, this.es, {this.zorunlu = false});
}

class Hedef {
  final String kod, ad, aciklama;
  final List<HAlan> alanlar;
  const Hedef(this.kod, this.ad, this.aciklama, this.alanlar);
}

const _tarih = HAlan('tarih', 'Tarih', ['tarih', 'islemtarihi', 'belgetarihi', 'faturatarihi', 'date', 'tahakkuktarihi', 'cezatarihi', 'tebligtarihi']);
const _aciklama = HAlan('aciklama', 'Açıklama', ['aciklama', 'islem', 'islemaciklamasi', 'detay', 'konu', 'vergituru', 'vergiturkodu', 'turu', 'not']);
const _cari = HAlan('cari', 'Cari (ünvan veya kod)', ['unvan', 'cariunvan', 'cariadi', 'cari', 'musteri', 'firma', 'firmaadi', 'aliciunvan', 'saticiunvan', 'adisoyadi', 'adsoyad', 'kurum', 'gonderen', 'alici', 'satici']);

const hedefler = <Hedef>[
  Hedef('cari', 'Cari Hesaplar', 'Müşteri/tedarikçi kartları. Bakiye sütunu varsa açılış bakiyesi olarak işlenir.', [
    HAlan('kod', 'Cari Kodu', ['carikodu', 'kod', 'hesapkodu']),
    HAlan('unvan', 'Ünvan', ['unvan', 'cariunvan', 'cariadi', 'firmaadi', 'adi', 'adisoyadi', 'musteri', 'ad'], zorunlu: true),
    HAlan('tip', 'Hesap Tipi', ['tip', 'tipi', 'hesaptipi', 'grup']),
    HAlan('tel', 'Telefon', ['telefon', 'tel', 'gsm', 'cep', 'telefonno', 'gsmno']),
    HAlan('email', 'E-posta', ['email', 'eposta', 'mail']),
    HAlan('adres', 'Adres', ['adres', 'adresi']),
    HAlan('vergi_dairesi', 'Vergi Dairesi', ['vergidairesi', 'vd']),
    HAlan('vergi_no', 'Vergi / TC No', ['vergino', 'vkn', 'tckn', 'tcno', 'vergikimlikno', 'tckimlikno']),
    HAlan('borc', 'Borç', ['borc', 'toplamborc']),
    HAlan('alacak', 'Alacak', ['alacak', 'toplamalacak']),
    HAlan('bakiye', 'Bakiye (+ alacağımız / − borcumuz)', ['bakiye', 'kalan', 'netbakiye']),
  ]),
  Hedef('urun', 'Ürünler / Stok Kartları', 'Ürün kartları. Miktar sütunu varsa stok açılışı olarak işlenir.', [
    HAlan('kod', 'Ürün Kodu', ['urunkodu', 'stokkodu', 'kod']),
    HAlan('ad', 'Ürün Adı', ['urunadi', 'stokadi', 'urun', 'ad', 'adi', 'malzeme', 'aciklama'], zorunlu: true),
    HAlan('barkod', 'Barkod', ['barkod', 'barcode']),
    HAlan('grup', 'Grup', ['grup', 'grubu', 'kategori', 'urungrubu']),
    HAlan('birim', 'Birim', ['birim', 'birimi']),
    HAlan('kdv', 'KDV %', ['kdv', 'kdvorani', 'kdv%']),
    HAlan('alis_fiyat', 'Alış Fiyatı', ['alisfiyati', 'alisfiyat', 'alis', 'maliyet']),
    HAlan('satis_fiyat', 'Satış Fiyatı', ['satisfiyati', 'satisfiyat', 'satis', 'fiyat', 'fiyati']),
    HAlan('miktar', 'Stok Miktarı', ['miktar', 'stok', 'stokmiktari', 'kalan', 'mevcut']),
  ]),
  Hedef('cari_hareket', 'Cari Hareketler', 'Ekstre satırları. Cari yoksa otomatik açılır.', [
    _tarih, _cari,
    HAlan('aciklama', 'Açıklama', ['aciklama', 'islem', 'evraktipi', 'belgeno', 'turu']),
    HAlan('borc', 'Borç', ['borc']),
    HAlan('alacak', 'Alacak', ['alacak']),
    HAlan('tutar', 'Tutar (+ borç / − alacak)', ['tutar', 'meblag']),
  ]),
  Hedef('kasa', 'Kasa Hareketleri', 'Kasa giriş/çıkışları. Cari sütunu doluysa tahsilat/ödeme olarak cariye de işlenir.', [
    _tarih, _aciklama, _cari,
    HAlan('hesap', 'Kasa Adı', ['kasa', 'kasaadi']),
    HAlan('kategori', 'Kategori', ['kategori', 'gidertur', 'gelirgider']),
    HAlan('giris', 'Giriş', ['giris', 'gelir', 'tahsilat', 'borc']),
    HAlan('cikis', 'Çıkış', ['cikis', 'gider', 'odeme', 'alacak']),
    HAlan('tutar', 'Tutar (+ giriş / − çıkış)', ['tutar', 'meblag']),
  ]),
  Hedef('banka', 'Banka Hareketleri (Ekstre)', 'Banka ekstresi (Enpara vb. Excel çıktısı).', [
    _tarih, _aciklama, _cari,
    HAlan('hesap', 'Banka / Hesap Adı', ['banka', 'hesap', 'hesapadi', 'iban']),
    HAlan('kategori', 'Kategori', ['kategori']),
    HAlan('giris', 'Gelen', ['gelen', 'giris', 'alacak', 'yatan']),
    HAlan('cikis', 'Giden', ['giden', 'cikis', 'borc', 'cekilen']),
    HAlan('tutar', 'Tutar (+ giriş / − çıkış)', ['tutar', 'islemtutari', 'meblag']),
  ]),
  Hedef('borc_kaydi', 'Kurum Borçları (Vergi, SGK, Bağ-Kur, Ceza)', 'Ödenecek borç olarak kurum carisine işlenir. Vergi, SGK primi, trafik cezası listeleri için.', [
    HAlan('kurum', 'Kurum / Cari', ['kurum', 'vergidairesi', 'birim', 'idare', 'alacakli']),
    _tarih,
    HAlan('vade', 'Son Ödeme / Vade', ['vade', 'vadetarihi', 'sonodemetarihi', 'odemetarihi', 'sonodeme']),
    HAlan('aciklama', 'Açıklama', ['aciklama', 'vergituru', 'vergiturkodu', 'vergiadi', 'turu', 'donem', 'cezamaddesi', 'plaka', 'belgeno', 'tahakkukno', 'konu']),
    HAlan('tutar', 'Tutar', ['tutar', 'borctutari', 'odenecektutar', 'toplam', 'toplamborc', 'cezatutari', 'kalanborc', 'borc', 'odenecek', 'tahakkuktutari'], zorunlu: true),
    HAlan('odenen', 'Ödenen (düşülür)', ['odenen', 'odenentutar', 'tahsilat']),
  ]),
  Hedef('satis_fatura', 'Satış Faturaları', 'e-Arşiv / e-Fatura giden listesi veya satır listesi. Aynı numaralı satırlar tek faturada birleşir.', [
    HAlan('no', 'Fatura No', ['faturano', 'belgeno', 'no', 'ettn', 'faturanumarasi']),
    _tarih, _cari,
    HAlan('urun', 'Ürün / Hizmet', ['urun', 'urunadi', 'mal', 'hizmet', 'malhizmet', 'aciklama']),
    HAlan('miktar', 'Miktar', ['miktar', 'adet']),
    HAlan('fiyat', 'Birim Fiyat (KDV hariç)', ['birimfiyat', 'fiyat']),
    HAlan('kdv', 'KDV %', ['kdvorani', 'kdv%', 'kdvoran']),
    HAlan('toplam', 'Toplam (KDV dahil)', ['toplam', 'odenecektutar', 'genel toplam', 'geneltoplam', 'tutar', 'vergilerdahiltoplam']),
  ]),
  Hedef('alis_fatura', 'Alış Faturaları', 'Gelen e-Fatura listesi veya alış satırları.', [
    HAlan('no', 'Fatura No', ['faturano', 'belgeno', 'no', 'ettn', 'faturanumarasi']),
    _tarih, _cari,
    HAlan('urun', 'Ürün / Hizmet', ['urun', 'urunadi', 'mal', 'hizmet', 'malhizmet', 'aciklama']),
    HAlan('miktar', 'Miktar', ['miktar', 'adet']),
    HAlan('fiyat', 'Birim Fiyat (KDV hariç)', ['birimfiyat', 'fiyat']),
    HAlan('kdv', 'KDV %', ['kdvorani', 'kdv%', 'kdvoran']),
    HAlan('toplam', 'Toplam (KDV dahil)', ['toplam', 'odenecektutar', 'geneltoplam', 'tutar', 'vergilerdahiltoplam']),
  ]),
  Hedef('cek', 'Çek / Senetler', 'Portföye çek/senet girişi.', [
    HAlan('no', 'Çek/Senet No', ['ceksenetno', 'cekno', 'senetno', 'no']),
    _cari,
    HAlan('banka', 'Banka', ['banka', 'bankaadi']),
    HAlan('vade', 'Vade', ['vade', 'vadetarihi'], zorunlu: true),
    HAlan('tutar', 'Tutar', ['tutar'], zorunlu: true),
    HAlan('yon', 'Yön (Alınan/Verilen)', ['yon', 'tur', 'turu']),
  ]),
  Hedef('not', 'Notlar / Mesajlar', 'Her satır bir not olarak saklanır.', [
    _tarih,
    HAlan('kisi', 'Kişi / Kaynak', ['kisi', 'gonderen', 'kimden', 'adsoyad']),
    HAlan('metin', 'Metin', ['mesaj', 'metin', 'aciklama', 'not', 'icerik'], zorunlu: true),
  ]),
  Hedef('serbest', 'Tabloyu Olduğu Gibi Sakla', 'Proje listeleri (DİPOS, Enerya, Gasline vb.) gibi muhasebe dışı tablolar için. "Aktarılan Tablolar"dan görüntülenir.', []),
];

Hedef hedefBul(String kod) => hedefler.firstWhere((h) => h.kod == kod);

int baslikSatiriBul(List<List<String>> rows) {
  for (var i = 0; i < rows.length && i < 15; i++) {
    final dolu = rows[i].where((x) => x.trim().isNotEmpty).length;
    final sayisal = rows[i].where((x) => RegExp(r'^[\d.,\-₺ TL]+$').hasMatch(x.trim()) && x.trim().isNotEmpty).length;
    if (dolu >= 2 && sayisal <= dolu ~/ 3) return i;
  }
  return 0;
}

Map<String, int> otomatikEsle(Hedef h, List<String> baslik) {
  final nb = baslik.map(normal).toList();
  final out = <String, int>{};
  final kullanilan = <int>{};
  for (final a in h.alanlar) {
    final es = a.es.map(normal).toList();
    var idx = -1;
    for (var i = 0; i < nb.length && idx < 0; i++) {
      if (!kullanilan.contains(i) && es.contains(nb[i])) idx = i;
    }
    for (var i = 0; i < nb.length && idx < 0; i++) {
      if (!kullanilan.contains(i) && nb[i].isNotEmpty && es.any((e) => e.length > 2 && nb[i].contains(e))) idx = i;
    }
    if (idx >= 0) {
      out[a.kod] = idx;
      kullanilan.add(idx);
    }
  }
  return out;
}

class AktarimSonuc {
  int eklendi = 0, atlandi = 0, hata = 0;
  @override
  String toString() => '$eklendi kayıt aktarıldı${atlandi > 0 ? ', $atlandi daha önce aktarıldığı için atlandı' : ''}${hata > 0 ? ', $hata satır okunamadı' : ''}';
}

Future<bool> _yeniMi(String h) async {
  final d = await DB.db;
  final k = h.length > 400 ? h.substring(0, 400) : h;
  final r = await d.query('aktarim_hash', where: 'h=?', whereArgs: [k]);
  return r.isEmpty;
}

Future<void> _isaretle(String h) async {
  final d = await DB.db;
  await d.insert('aktarim_hash', {'h': h.length > 400 ? h.substring(0, 400) : h}, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// Eşlenmiş satırları seçilen hedefe yazar.
Future<AktarimSonuc> hedefeAktar(String hedef, List<Map<String, String>> kayitlar, {String kaynak = 'Excel', bool atla = true}) async {
  final s = AktarimSonuc();
  if (hedef == 'satis_fatura' || hedef == 'alis_fatura') {
    return _faturaAktar(hedef, kayitlar, kaynak, atla);
  }
  for (final r in kayitlar) {
    final anahtar = '$hedef|${r.entries.map((e) => '${e.key}=${e.value}').join('|')}';
    try {
      if (atla && !await _yeniMi(anahtar)) {
        s.atlandi++;
        continue;
      }
      final ok = await _satirAktar(hedef, r, kaynak);
      if (ok) {
        s.eklendi++;
        await _isaretle(anahtar);
      } else {
        s.hata++;
      }
    } catch (_) {
      s.hata++;
    }
  }
  return s;
}

String _v(Map<String, String> r, String k) => (r[k] ?? '').trim();

Future<bool> _satirAktar(String hedef, Map<String, String> r, String kaynak) async {
  final tarih = tarihCoz(_v(r, 'tarih')) ?? bugun();
  switch (hedef) {
    case 'cari':
      final unvan = _v(r, 'unvan');
      if (unvan.isEmpty) return false;
      final m = <String, Object?>{'unvan': unvan};
      for (final k in ['kod', 'tip', 'tel', 'email', 'adres', 'vergi_dairesi', 'vergi_no']) {
        if (_v(r, k).isNotEmpty) m[k] = _v(r, k);
      }
      final varOlan = await DB.tek('SELECT id FROM cari WHERE (kod<>\'\' AND kod=?) OR UPPER(unvan)=UPPER(?)', [_v(r, 'kod'), unvan]);
      final id = varOlan == null ? await DB.ekle('cari', m) : varOlan['id'] as int;
      if (varOlan != null) await DB.guncelle('cari', m, id);
      final bakiye = r.containsKey('bakiye') && _v(r, 'bakiye').isNotEmpty ? sy(_v(r, 'bakiye')) : sy(_v(r, 'borc')) - sy(_v(r, 'alacak'));
      if (bakiye.abs() > 0.004) {
        await Servis.islemKaydet(bakiye > 0 ? 'c_acilis_borc' : 'c_acilis_alacak', cari: id, tarih: tarih, tutar: bakiye.abs(), aciklama: 'Açılış ($kaynak)', kaynak: kaynak);
      }
      return true;
    case 'urun':
      final ad = _v(r, 'ad');
      if (ad.isEmpty) return false;
      final m = <String, Object?>{'ad': ad};
      for (final k in ['kod', 'barkod', 'grup', 'birim']) {
        if (_v(r, k).isNotEmpty) m[k] = _v(r, k);
      }
      for (final k in ['kdv', 'alis_fiyat', 'satis_fiyat']) {
        if (_v(r, k).isNotEmpty) m[k] = sy(_v(r, k));
      }
      final varOlan = await DB.tek('SELECT id FROM urun WHERE (kod<>\'\' AND kod=?) OR (barkod<>\'\' AND barkod=?) OR UPPER(ad)=UPPER(?)', [_v(r, 'kod'), _v(r, 'barkod'), ad]);
      final id = varOlan == null ? await DB.ekle('urun', m) : varOlan['id'] as int;
      if (varOlan != null) await DB.guncelle('urun', m, id);
      final mik = sy(_v(r, 'miktar'));
      if (mik != 0) {
        await DB.ekle('stok_hareket', {
          'urun_id': id, 'depo_id': 1, 'tarih': tarih, 'tur': 'stok_acilis', 'giris': mik > 0 ? mik : 0, 'cikis': mik < 0 ? -mik : 0,
          'fiyat': sy(_v(r, 'alis_fiyat')), 'grup': DB.yeniGrup(), 'aciklama': 'Stok açılış ($kaynak)',
        });
      }
      return true;
    case 'cari_hareket':
      final c = _v(r, 'cari');
      if (c.isEmpty) return false;
      var borc = sy(_v(r, 'borc')), alacak = sy(_v(r, 'alacak'));
      final t = sy(_v(r, 'tutar'));
      if (borc == 0 && alacak == 0 && t != 0) {
        if (t > 0) {
          borc = t;
        } else {
          alacak = -t;
        }
      }
      if (borc == 0 && alacak == 0) return false;
      final id = await Servis.cariBulEkle(c);
      await DB.ekle('cari_hareket', {
        'cari_id': id, 'tarih': tarih, 'tur': 'Aktarım', 'aciklama': _v(r, 'aciklama'), 'borc': borc, 'alacak': alacak, 'grup': DB.yeniGrup(), 'kaynak': kaynak,
      });
      return true;
    case 'kasa':
    case 'banka':
      var giris = sy(_v(r, 'giris')).abs(), cikis = sy(_v(r, 'cikis')).abs();
      final t = sy(_v(r, 'tutar'));
      if (giris == 0 && cikis == 0 && t != 0) {
        if (t > 0) {
          giris = t;
        } else {
          cikis = -t;
        }
      }
      if (giris == 0 && cikis == 0) return false;
      int hesap;
      final ha = _v(r, 'hesap');
      final hb = ha.isEmpty ? null : await DB.tek('SELECT id FROM hesap WHERE tip=? AND (UPPER(ad)=UPPER(?) OR iban=?)', [hedef, ha, ha]);
      if (hb != null) {
        hesap = hb['id'] as int;
      } else if (ha.isNotEmpty && hedef == 'banka' && !RegExp(r'^\d').hasMatch(ha)) {
        hesap = await DB.ekle('hesap', {'tip': 'banka', 'ad': ha});
      } else {
        hesap = await Servis.ilkHesap(hedef);
      }
      final c = _v(r, 'cari');
      final cari = c.isEmpty ? null : await Servis.cariBulEkle(c);
      final kod = cari != null
          ? (giris > 0 ? (hedef == 'kasa' ? 'cariden_tahsilat' : 'gelen_havale') : (hedef == 'kasa' ? 'cariye_odeme' : 'giden_havale'))
          : (giris > 0 ? (hedef == 'kasa' ? 'diger_tahsilat' : 'b_diger_borc') : (hedef == 'kasa' ? 'diger_odeme' : 'b_diger_alacak'));
      await Servis.islemKaydet(kod, hesap: hesap, cari: cari, tarih: tarih, tutar: giris > 0 ? giris : cikis, aciklama: _v(r, 'aciklama'),
          kategori: _v(r, 'kategori').isEmpty ? null : _v(r, 'kategori'), kaynak: kaynak);
      return true;
    case 'borc_kaydi':
      final tutar = sy(_v(r, 'tutar')) - sy(_v(r, 'odenen'));
      if (tutar <= 0) return false;
      final kurum = _v(r, 'kurum').isEmpty ? kaynak : _v(r, 'kurum');
      final id = await Servis.cariBulEkle(kurum, tip: 'Kurum');
      final vade = tarihCoz(_v(r, 'vade'));
      await Servis.islemKaydet('alacak_dekont', cari: id, tarih: tarih, tutar: tutar,
          aciklama: '${_v(r, 'aciklama')}${vade != null ? ' (son ödeme ${gTarih(vade)})' : ''}', kaynak: kaynak);
      return true;
    case 'cek':
      final t = sy(_v(r, 'tutar'));
      final vade = tarihCoz(_v(r, 'vade'));
      if (t <= 0 || vade == null) return false;
      final yon = normal(_v(r, 'yon')).contains('veril') ? 'Verilen' : 'Alınan';
      final c = _v(r, 'cari').isEmpty ? kaynak : _v(r, 'cari');
      final id = await Servis.cariBulEkle(c);
      final g = DB.yeniGrup();
      await DB.ekle('cek_senet', {'tur': 'Çek', 'yon': yon, 'no': _v(r, 'no'), 'cari_id': id, 'banka': _v(r, 'banka'), 'tarih': tarih, 'vade': vade, 'tutar': t, 'grup': g});
      await DB.ekle('cari_hareket', {'cari_id': id, 'tarih': tarih, 'tur': '$yon Çek', 'aciklama': 'Çek ${_v(r, 'no')}', 'borc': yon == 'Verilen' ? t : 0, 'alacak': yon == 'Alınan' ? t : 0, 'grup': g});
      return true;
    case 'not':
      if (_v(r, 'metin').isEmpty) return false;
      await DB.ekle('notlar', {'tarih': tarih, 'kaynak': kaynak, 'kisi': _v(r, 'kisi'), 'metin': _v(r, 'metin')});
      return true;
  }
  return false;
}

Future<AktarimSonuc> _faturaAktar(String tur, List<Map<String, String>> kayitlar, String kaynak, bool atla) async {
  final s = AktarimSonuc();
  final gruplar = <String, List<Map<String, String>>>{};
  var sira = 0;
  for (final r in kayitlar) {
    final no = _v(r, 'no').isEmpty ? 'satir${sira++}' : _v(r, 'no');
    gruplar.putIfAbsent(no, () => []).add(r);
  }
  for (final e in gruplar.entries) {
    final ilk = e.value.first;
    final anahtar = '$tur|${e.key}|${_v(ilk, 'cari')}|${_v(ilk, 'tarih')}';
    if (atla && !await _yeniMi(anahtar)) {
      s.atlandi++;
      continue;
    }
    try {
      final c = _v(ilk, 'cari');
      final cari = c.isEmpty ? null : await Servis.cariBulEkle(c, tip: tur == 'alis_fatura' ? 'Tedarikçi' : 'Müşteri');
      final satirlar = <Map<String, Object?>>[];
      for (final r in e.value) {
        final ad = _v(r, 'urun');
        final kdv = _v(r, 'kdv').isEmpty ? 0.0 : sy(_v(r, 'kdv'));
        var mik = sy(_v(r, 'miktar'));
        if (mik == 0) mik = 1;
        var fiyat = sy(_v(r, 'fiyat'));
        if (fiyat == 0) fiyat = sy(_v(r, 'toplam')) / (1 + kdv / 100) / mik;
        if (fiyat == 0) continue;
        int? urunId;
        if (ad.isNotEmpty && _v(r, 'fiyat').isNotEmpty) {
          final u = await DB.tek('SELECT id FROM urun WHERE kod=? OR UPPER(ad)=UPPER(?)', [ad, ad]);
          urunId = u?['id'] as int?;
        }
        satirlar.add({'urun_id': urunId, 'aciklama': ad.isEmpty ? '${turlar[tur]!.ad} ${e.key}' : ad, 'miktar': mik, 'fiyat': fiyat, 'kdv': kdv});
      }
      if (satirlar.isEmpty) {
        s.hata++;
        continue;
      }
      await Servis.belgeKaydet({
        'tur': tur, 'no': e.key.startsWith('satir') ? await Servis.sonrakiNo(tur) : e.key, 'tarih': tarihCoz(_v(ilk, 'tarih')) ?? bugun(),
        'cari_id': cari, 'depo_id': 1, 'aciklama': 'Aktarım: $kaynak', 'kaynak': kaynak,
      }, satirlar);
      await _isaretle(anahtar);
      s.eklendi++;
    } catch (_) {
      s.hata++;
    }
  }
  return s;
}

/// Tabloyu satırları ve başlığıyla hedef alanlara eşleme ekranı.
/// Excel, CSV, portal (WebView) tabloları hepsi buradan geçer.
class EslestirmeEkrani extends StatefulWidget {
  final List<List<String>> satirlar;
  final String kaynak;
  final int? portalId;
  final String? varsayilanHedef;
  const EslestirmeEkrani({super.key, required this.satirlar, required this.kaynak, this.portalId, this.varsayilanHedef});
  @override
  State<EslestirmeEkrani> createState() => _EslestirmeEkraniState();
}

class _EslestirmeEkraniState extends State<EslestirmeEkrani> {
  late int baslik = baslikSatiriBul(widget.satirlar);
  late Hedef hedef = hedefBul(widget.varsayilanHedef ?? 'cari_hareket');
  Map<String, int> esle = {};
  bool atla = true, kaydetOto = false, calisiyor = false;
  late final serbestAd = TextEditingController(text: widget.kaynak);

  List<String> get basliklar {
    if (widget.satirlar.isEmpty) return [];
    final genislik = widget.satirlar.fold<int>(0, (a, r) => r.length > a ? r.length : a);
    final b = widget.satirlar[baslik];
    return List.generate(genislik, (i) => i < b.length && b[i].trim().isNotEmpty ? b[i].trim() : 'Sütun ${i + 1}');
  }

  List<List<String>> get veri => widget.satirlar.skip(baslik + 1).where((r) => r.any((x) => x.trim().isNotEmpty)).toList();

  @override
  void initState() {
    super.initState();
    esle = otomatikEsle(hedef, basliklar);
  }

  List<Map<String, String>> kayitlar() => veri.map((r) => {for (final e in esle.entries) e.key: e.value < r.length ? r[e.value] : ''}).toList();

  Future<void> aktar() async {
    final eksik = hedef.alanlar.where((a) => a.zorunlu && !esle.containsKey(a.kod)).map((a) => a.ad).toList();
    if (eksik.isNotEmpty) return mesaj(context, 'Eşlenmesi zorunlu: ${eksik.join(', ')}');
    setState(() => calisiyor = true);
    String sonuc;
    if (hedef.kod == 'serbest') {
      await DB.ekle('serbest_tablo', {'ad': serbestAd.text.trim().isEmpty ? widget.kaynak : serbestAd.text.trim(), 'kaynak': widget.kaynak, 'tarih': DateTime.now().toIso8601String(), 'veri': jsonEncode([basliklar, ...veri])});
      sonuc = '${veri.length} satırlık tablo saklandı';
    } else {
      sonuc = (await hedefeAktar(hedef.kod, kayitlar(), kaynak: widget.kaynak, atla: atla)).toString();
    }
    if (kaydetOto && widget.portalId != null) {
      final b = basliklar;
      await DB.guncelle('portal', {
        'otomatik': jsonEncode({'hedef': hedef.kod, 'esle': {for (final e in esle.entries) e.key: b[e.value]}, 'ad': serbestAd.text.trim(), 'baslikSayisi': b.length})
      }, widget.portalId!);
      sonuc += '\nEşleme kaydedildi: bu portalda ⚡ ile tek dokunuşta aktarabilirsiniz.';
    }
    if (!mounted) return;
    setState(() => calisiyor = false);
    await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Aktarım tamamlandı'), content: Text(sonuc)));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final b = basliklar;
    final ornek = veri.take(5).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Aktar: ${widget.kaynak}')),
      body: calisiyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Text('${veri.length} veri satırı, ${b.length} sütun bulundu.'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: hedef.kod,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nereye aktarılsın?'),
                items: hedefler.map((h) => DropdownMenuItem(value: h.kod, child: Text(h.ad))).toList(),
                onChanged: (v) => setState(() {
                  hedef = hedefBul(v!);
                  esle = otomatikEsle(hedef, b);
                }),
              ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(hedef.aciklama, style: const TextStyle(fontSize: 12))),
              Row(children: [
                const Text('Başlık satırı: '),
                IconButton(onPressed: baslik > 0 ? () => setState(() { baslik--; esle = otomatikEsle(hedef, basliklar); }) : null, icon: const Icon(Icons.remove)),
                Text('${baslik + 1}'),
                IconButton(onPressed: baslik < widget.satirlar.length - 2 ? () => setState(() { baslik++; esle = otomatikEsle(hedef, basliklar); }) : null, icon: const Icon(Icons.add)),
                Expanded(child: Text(widget.satirlar.isEmpty ? '' : widget.satirlar[baslik].take(4).join(' | '), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              ]),
              if (hedef.kod == 'serbest') Girdi(serbestAd, 'Tablo adı'),
              ...hedef.alanlar.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: DropdownButtonFormField<int>(
                      value: esle[a.kod] ?? -1,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: a.zorunlu ? '${a.ad} *' : a.ad),
                      items: [
                        const DropdownMenuItem(value: -1, child: Text('— kullanma —')),
                        ...List.generate(b.length, (i) => DropdownMenuItem(value: i, child: Text(b[i], overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() {
                        if (v == null || v < 0) {
                          esle.remove(a.kod);
                        } else {
                          esle[a.kod] = v;
                        }
                      }),
                    ),
                  )),
              if (hedef.kod != 'serbest')
                SwitchListTile(value: atla, title: const Text('Daha önce aktarılan satırları atla'), onChanged: (v) => setState(() => atla = v)),
              if (widget.portalId != null)
                SwitchListTile(value: kaydetOto, title: const Text('Bu eşlemeyi portal için kaydet (otomatik aktarım ⚡)'), onChanged: (v) => setState(() => kaydetOto = v)),
              const SizedBox(height: 8),
              const Text('Önizleme', style: TextStyle(fontWeight: FontWeight.bold)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: hedef.kod == 'serbest'
                    ? DataTable(columns: b.map((x) => DataColumn(label: Text(x))).toList(), rows: ornek.map((r) => DataRow(cells: List.generate(b.length, (i) => DataCell(Text(i < r.length ? r[i] : ''))))).toList())
                    : esle.isEmpty
                        ? const Padding(padding: EdgeInsets.all(8), child: Text('Henüz eşlenen sütun yok'))
                        : DataTable(
                            columns: esle.keys.map((k) => DataColumn(label: Text(hedef.alanlar.firstWhere((a) => a.kod == k).ad))).toList(),
                            rows: ornek.map((r) => DataRow(cells: esle.values.map((i) => DataCell(Text(i < r.length ? r[i] : ''))).toList())).toList(),
                          ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: aktar, icon: const Icon(Icons.download_done), label: Text('${veri.length} satırı aktar')),
              const SizedBox(height: 40),
            ]),
    );
  }
}

/// Kayıtlı eşlemeyle (portal ⚡) doğrudan aktarım
Future<String> otomatikAktar(List<List<List<String>>> tablolar, Map<String, dynamic> ayar, String kaynak) async {
  final esleAd = Map<String, String>.from(ayar['esle'] as Map);
  final hedef = ayar['hedef'] as String;
  final istenen = esleAd.values.map(normal).toSet();
  // Kayıtlı başlıkların en çok bulunduğu tabloyu ve başlık satırını seç
  List<List<String>>? enIyi;
  var enIyiBaslik = 0, enIyiPuan = 0;
  for (final t in tablolar) {
    for (var i = 0; i < t.length && i < 10; i++) {
      final p = t[i].map(normal).where(istenen.contains).length;
      if (p > enIyiPuan) {
        enIyiPuan = p;
        enIyi = t;
        enIyiBaslik = i;
      }
    }
  }
  if (enIyi == null || (istenen.isNotEmpty && enIyiPuan < (istenen.length / 2).ceil())) {
    return 'Kayıtlı tabloya uyan bir tablo bu sayfada bulunamadı. Doğru sayfayı açtığınızdan emin olun veya "Tabloları al" ile yeniden eşleyin.';
  }
  final bas = enIyi[enIyiBaslik].map(normal).toList();
  final veri = enIyi.skip(enIyiBaslik + 1).where((r) => r.any((x) => x.trim().isNotEmpty)).toList();
  if (hedef == 'serbest') {
    await DB.ekle('serbest_tablo', {'ad': (ayar['ad'] as String?)?.isNotEmpty == true ? ayar['ad'] : kaynak, 'kaynak': kaynak, 'tarih': DateTime.now().toIso8601String(), 'veri': jsonEncode([enIyi[enIyiBaslik], ...veri])});
    return '${veri.length} satırlık tablo saklandı.';
  }
  final idx = <String, int>{};
  esleAd.forEach((alan, baslikAd) {
    final i = bas.indexOf(normal(baslikAd));
    if (i >= 0) idx[alan] = i;
  });
  final kayitlar = veri.map((r) => {for (final e in idx.entries) e.key: e.value < r.length ? r[e.value] : ''}).toList();
  return (await hedefeAktar(hedef, kayitlar, kaynak: kaynak, atla: true)).toString();
}

// ---------------- Veri Aktar sekmesi ----------------

class VeriAktar extends StatelessWidget {
  const VeriAktar({super.key});

  Future<void> dosyaSec(BuildContext c) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv', 'txt', 'xls'], withData: true);
    if (r == null || r.files.isEmpty || !c.mounted) return;
    final f = r.files.first;
    if (f.bytes == null) return mesaj(c, 'Dosya okunamadı');
    try {
      final sayfalar = dosyaOku(f.name, f.bytes!);
      if (sayfalar.isEmpty) return mesaj(c, 'Dosyada veri bulunamadı');
      var ad = sayfalar.keys.first;
      if (sayfalar.length > 1 && c.mounted) {
        final s = await showModalBottomSheet<String>(
            context: c,
            builder: (_) => ListView(shrinkWrap: true, children: [
                  const ListTile(title: Text('Hangi sayfa?', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...sayfalar.entries.map((e) => ListTile(title: Text(e.key), subtitle: Text('${e.value.length} satır'), onTap: () => Navigator.pop(c, e.key))),
                ]));
        if (s == null) return;
        ad = s;
      }
      if (!c.mounted) return;
      await Navigator.push(c, MaterialPageRoute(builder: (_) => EslestirmeEkrani(satirlar: sayfalar[ad]!, kaynak: f.name)));
    } catch (e) {
      if (c.mounted) mesaj(c, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> sablon(BuildContext c) async {
    final sayfalar = <String, (List<String>, List<List<Object?>>)>{};
    for (final h in hedefler.where((h) => h.alanlar.isNotEmpty)) {
      final ad = h.ad.length > 28 ? h.ad.substring(0, 28) : h.ad;
      sayfalar[ad.replaceAll('/', '-')] = (h.alanlar.map((a) => a.ad.split(' (').first).toList(), <List<Object?>>[]);
    }
    await excelCokluPaylas('Aktarim_Sablonlari', sayfalar);
  }

  Future<void> yedek(BuildContext c) async {
    const tablolar = ['sirket', 'cari', 'cari_hareket', 'urun', 'stok_hareket', 'depo', 'belge', 'belge_satir', 'hesap', 'finans_hareket', 'cek_senet', 'recete', 'recete_kalem', 'uretim_emri', 'notlar', 'portal'];
    final sayfalar = <String, (List<String>, List<List<Object?>>)>{};
    for (final t in tablolar) {
      final r = await DB.q('SELECT * FROM $t');
      if (r.isEmpty) continue;
      sayfalar[t] = (r.first.keys.toList(), r.map((x) => x.values.toList()).toList());
    }
    await excelCokluPaylas('Yedek_${bugun()}', sayfalar);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Veri Aktar')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file, size: 36),
              title: const Text('Excel / CSV dosyası yükle'),
              subtitle: const Text('EBS listeleri, banka ekstresi, e-Fatura listesi, SGK/vergi dökümü... Sütunlar otomatik eşlenir, siz kontrol edip aktarırsınız.'),
              onTap: () => dosyaSec(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.grid_on, size: 36),
              title: const Text('Boş şablonları indir'),
              subtitle: const Text('Cari, ürün, hareket, fatura, çek için hazır sütun başlıklı Excel'),
              onTap: () => sablon(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup, size: 36),
              title: const Text('Tüm verileri Excel olarak yedekle'),
              subtitle: const Text('Her tablo ayrı sayfada; Drive, e-posta veya WhatsApp ile saklayın'),
              onTap: () => yedek(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.table_chart, size: 36),
              title: const Text('Aktarılan tablolar'),
              subtitle: const Text('Olduğu gibi saklanan portal / Excel tabloları'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SerbestTablolar())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sticky_note_2, size: 36),
              title: const Text('Notlar'),
              subtitle: const Text('WhatsApp ve portallardan not olarak alınanlar'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotListesi())),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('İpucu: EBS\'de herhangi bir listeyi (Cari Bakiye, Ürün Listesi, Fatura Listesi) Excel\'e aktarıp burada yükleyerek tüm geçmiş verinizi telefona taşıyabilirsiniz. Eski .xls dosyalarını önce .xlsx olarak kaydedin.',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      );
}

class SerbestTablolar extends StatefulWidget {
  const SerbestTablolar({super.key});
  @override
  State<SerbestTablolar> createState() => _SerbestTablolarState();
}

class _SerbestTablolarState extends State<SerbestTablolar> {
  List<Map<String, Object?>> l = [];
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT id, ad, kaynak, tarih, length(veri) boyut FROM serbest_tablo ORDER BY id DESC');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Aktarılan Tablolar')),
        body: l.isEmpty
            ? const Center(child: Text('Henüz saklanan tablo yok'))
            : ListView(
                children: l
                    .map((t) => ListTile(
                          title: Text('${t['ad']}'),
                          subtitle: Text('${t['kaynak']} • ${'${t['tarih']}'.replaceFirst('T', ' ').split('.').first}'),
                          onTap: () async {
                            final r = await DB.tek('SELECT veri FROM serbest_tablo WHERE id=?', [t['id']]);
                            final v = (jsonDecode(r!['veri'] as String) as List).map((x) => (x as List).map((y) => '$y').toList()).toList();
                            if (!context.mounted) return;
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => TabloGoster('${t['ad']}', v)));
                          },
                          onLongPress: () async {
                            if (await onay(context, 'Tablo silinsin mi?')) {
                              await DB.sil('serbest_tablo', t['id'] as int);
                              yukle();
                            }
                          },
                        ))
                    .toList()),
      );
}

class TabloGoster extends StatelessWidget {
  final String ad;
  final List<List<String>> v;
  const TabloGoster(this.ad, this.v, {super.key});
  @override
  Widget build(BuildContext context) {
    final b = v.isEmpty ? <String>[] : v.first;
    final g = v.fold<int>(0, (a, r) => r.length > a ? r.length : a);
    return Scaffold(
      appBar: AppBar(title: Text(ad), actions: [
        IconButton(icon: const Icon(Icons.ios_share), onPressed: () => excelPaylas(ad, List.generate(g, (i) => i < b.length ? b[i] : ''), v.skip(1).map((r) => r.cast<Object?>()).toList())),
        IconButton(
            icon: const Icon(Icons.input),
            tooltip: 'Muhasebeye aktar',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EslestirmeEkrani(satirlar: v, kaynak: ad)))),
      ]),
      body: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: List.generate(g, (i) => DataColumn(label: Text(i < b.length ? b[i] : ''))),
            rows: v.skip(1).map((r) => DataRow(cells: List.generate(g, (i) => DataCell(Text(i < r.length ? r[i] : ''))))).toList(),
          ),
        ),
      ),
    );
  }
}

class NotListesi extends StatefulWidget {
  const NotListesi({super.key});
  @override
  State<NotListesi> createState() => _NotListesiState();
}

class _NotListesiState extends State<NotListesi> {
  List<Map<String, Object?>> l = [];
  String ara = '';
  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    l = await DB.q('SELECT * FROM notlar ORDER BY tarih DESC, id DESC');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = normal(ara);
    final f = l.where((x) => n.isEmpty || normal('${x['kisi']} ${x['metin']} ${x['kaynak']}').contains(n)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notlar')),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            final m = await metinSor(context, 'Yeni not');
            if (m != null && m.isNotEmpty) {
              await DB.ekle('notlar', {'tarih': bugun(), 'kaynak': 'Elle', 'metin': m});
              yukle();
            }
          }),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => ara = v))),
        Expanded(
          child: ListView(
              children: f
                  .map((x) => ListTile(
                        title: Text('${x['metin']}'),
                        subtitle: Text('${gTarih(x['tarih'])} • ${x['kaynak'] ?? ''} ${x['kisi'] ?? ''}'),
                        onLongPress: () async {
                          if (await onay(context, 'Not silinsin mi?')) {
                            await DB.sil('notlar', x['id'] as int);
                            yukle();
                          }
                        },
                      ))
                  .toList()),
        ),
      ]),
    );
  }
}
