import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'ortak.dart';

/// Belge türü: stok yönü (+1 giriş / -1 çıkış), cari yönü (+1 cari borçlanır / -1 cari alacaklanır)
class BT {
  final String kod, ad, grup;
  final int stok, cari;
  final bool alis;
  const BT(this.kod, this.ad, this.grup, this.stok, this.cari, this.alis);
}

const _bt = [
  BT('alis_fatura', 'Alış Faturası', 'Fatura', 1, -1, true),
  BT('satis_fatura', 'Satış Faturası', 'Fatura', -1, 1, false),
  BT('alis_iade_fatura', 'Alış İade Faturası', 'Fatura', -1, 1, true),
  BT('satis_iade_fatura', 'Satış İade Faturası', 'Fatura', 1, -1, false),
  BT('alis_irsaliye', 'Alış İrsaliyesi', 'İrsaliye', 1, 0, true),
  BT('satis_irsaliye', 'Satış İrsaliyesi', 'İrsaliye', -1, 0, false),
  BT('alis_iade_irsaliye', 'Alış İade İrsaliyesi', 'İrsaliye', -1, 0, true),
  BT('satis_iade_irsaliye', 'Satış İade İrsaliyesi', 'İrsaliye', 1, 0, false),
  BT('alis_fis', 'Alış Fişi', 'Fiş', 1, -1, true),
  BT('satis_fis', 'Satış Fişi', 'Fiş', -1, 1, false),
  BT('alis_iade_fis', 'Alış İade Fişi', 'Fiş', -1, 1, true),
  BT('satis_iade_fis', 'Satış İade Fişi', 'Fiş', 1, -1, false),
  BT('hizli_satis', 'Hızlı Satış', 'Hızlı Satış', -1, 1, false),
  BT('hizli_satis_iade', 'Hızlı Satış İade', 'Hızlı Satış', 1, -1, false),
  BT('siparis_alinan', 'Alınan Sipariş (Satış)', 'Sipariş', 0, 0, false),
  BT('siparis_verilen', 'Verilen Sipariş (Satınalma)', 'Sipariş', 0, 0, true),
  BT('stok_giris', 'Stok Giriş Fişi', 'Stok', 1, 0, true),
  BT('stok_cikis', 'Stok Çıkış Fişi', 'Stok', -1, 0, true),
  BT('sayim_fazlasi', 'Sayım Fazlası', 'Stok', 1, 0, true),
  BT('sayim_eksigi', 'Sayım Eksiği', 'Stok', -1, 0, true),
  BT('fire', 'Fire Fişi', 'Stok', -1, 0, true),
  BT('sarf', 'Sarf Fişi', 'Stok', -1, 0, true),
  BT('uretimden_giris', 'Üretimden Giriş', 'Stok', 1, 0, true),
  BT('stok_acilis', 'Stok Açılış Fişi', 'Stok', 1, 0, true),
  BT('stok_devir', 'Stok Devir Fişi', 'Stok', 1, 0, true),
  BT('depo_transfer', 'Depo Transfer Fişi', 'Stok', 0, 0, true),
];

final turlar = {for (final t in _bt) t.kod: t};
List<BT> grupTurleri(String g) => _bt.where((t) => t.grup == g).toList();

const satisTurleri = "'satis_fatura','satis_fis','hizli_satis','satis_iade_fatura','satis_iade_fis','hizli_satis_iade'";
const alisTurleri = "'alis_fatura','alis_fis','alis_iade_fatura','alis_iade_fis'";
const maliyetTurleri =
    "'alis_fatura','alis_fis','alis_irsaliye','stok_acilis','stok_devir','stok_giris','uretimden_giris','sayim_fazlasi'";

/// İşlem tanımı: hesap (kasa/banka) ve cari etkileri
class IT {
  final String ad;
  final int hesap, karsi, cari, karsiCari;
  final String? hesapTip, karsiTip;
  final bool kategori;
  final String? not;
  const IT(this.ad,
      {this.hesap = 0,
      this.karsi = 0,
      this.cari = 0,
      this.karsiCari = 0,
      this.hesapTip,
      this.karsiTip,
      this.kategori = false,
      this.not});
}

const islemler = <String, IT>{
  // Cariler menüsü
  'borc_dekont': IT('Borç Dekontu', cari: 1, not: 'Cari hesabı borçlandırır (bize borcu artar).'),
  'alacak_dekont': IT('Alacak Dekontu', cari: -1, not: 'Cari hesabı alacaklandırır (bizim ona borcumuz artar).'),
  'tahsilat': IT('Tahsilat', hesap: 1, cari: -1),
  'odeme': IT('Ödeme', hesap: -1, cari: 1),
  'c_acilis_borc': IT('Açılış Borç', cari: 1),
  'c_acilis_alacak': IT('Açılış Alacak', cari: -1),
  'c_devir_borc': IT('Devir Borç', cari: 1),
  'c_devir_alacak': IT('Devir Alacak', cari: -1),
  'cari_virman': IT('Cari Virman', cari: -1, karsiCari: 1, not: 'Tutar 1. cariden alınıp 2. cariye aktarılır.'),
  // Banka menüsü
  'gelen_havale': IT('Gelen Havale/EFT', hesap: 1, cari: -1, hesapTip: 'banka'),
  'giden_havale': IT('Giden Havale/EFT', hesap: -1, cari: 1, hesapTip: 'banka'),
  'para_yatirma': IT('Para Yatırma', hesap: 1, karsi: -1, hesapTip: 'banka', karsiTip: 'kasa',
      not: 'Kasadan bankaya para yatırılır.'),
  'para_cekme': IT('Para Çekme', hesap: -1, karsi: 1, hesapTip: 'banka', karsiTip: 'kasa',
      not: 'Bankadan çekilip kasaya konur.'),
  'b_diger_borc': IT('Diğer Borç İşlemi', hesap: 1, hesapTip: 'banka', kategori: true,
      not: 'Banka hesabına giriş (faiz geliri, iade vb.).'),
  'b_diger_alacak': IT('Diğer Alacak İşlemi', hesap: -1, hesapTip: 'banka', kategori: true,
      not: 'Banka hesabından çıkış (masraf, komisyon, vergi, SGK ödemesi vb.).'),
  'b_acilis_borc': IT('Açılış Borç', hesap: 1, hesapTip: 'banka', not: 'Açılış bakiyesi (hesaptaki para).'),
  'b_acilis_alacak': IT('Açılış Alacak', hesap: -1, hesapTip: 'banka', not: 'Eksi açılış bakiyesi (KMH vb.).'),
  'b_devir_borc': IT('Devir Borç', hesap: 1, hesapTip: 'banka'),
  'b_devir_alacak': IT('Devir Alacak', hesap: -1, hesapTip: 'banka'),
  'hesap_virman': IT('Hesap Virman', hesap: -1, karsi: 1, hesapTip: 'banka', karsiTip: 'banka',
      not: '1. hesaptan 2. hesaba aktarım.'),
  // Kasa menüsü
  'cariden_tahsilat': IT('Cariden Tahsilat', hesap: 1, cari: -1, hesapTip: 'kasa'),
  'cariye_odeme': IT('Cariye Ödeme', hesap: -1, cari: 1, hesapTip: 'kasa'),
  'diger_tahsilat': IT('Diğer Tahsilat', hesap: 1, hesapTip: 'kasa', kategori: true),
  'diger_odeme': IT('Diğer Ödeme (Gider)', hesap: -1, hesapTip: 'kasa', kategori: true),
  'devir_gelir': IT('Devir Gelir', hesap: 1, hesapTip: 'kasa'),
  'devir_gider': IT('Devir Gider', hesap: -1, hesapTip: 'kasa'),
  'acilis_gelir': IT('Açılış Gelir', hesap: 1, hesapTip: 'kasa'),
  'acilis_gider': IT('Açılış Gider', hesap: -1, hesapTip: 'kasa'),
  'kasa_virman': IT('Kasa Virman', hesap: -1, karsi: 1, hesapTip: 'kasa', karsiTip: 'kasa',
      not: '1. kasadan 2. kasaya aktarım.'),
};

/// Kasa/banka çıkışlarından "gider" sayılan türler (kar/zarar için)
const giderTurleri = "'Diğer Ödeme (Gider)','Diğer Alacak İşlemi'";
const gelirTurleri = "'Diğer Tahsilat','Diğer Borç İşlemi'";

class Servis {
  static Future<String> islemKaydet(String kod,
      {int? hesap,
      int? karsiHesap,
      int? cari,
      int? karsiCari,
      required String tarih,
      required double tutar,
      String? aciklama,
      String? kategori,
      String? kaynak,
      DatabaseExecutor? tx}) async {
    final t = islemler[kod]!;
    final g = DB.yeniGrup();
    Future<void> yap(DatabaseExecutor x) async {
      if (t.hesap != 0 && hesap != null) {
        await x.insert('finans_hareket', {
          'hesap_id': hesap, 'tarih': tarih, 'tur': t.ad, 'cari_id': cari, 'kategori': kategori,
          'aciklama': aciklama, 'giris': t.hesap > 0 ? tutar : 0, 'cikis': t.hesap < 0 ? tutar : 0,
          'grup': g, 'kaynak': kaynak,
        });
      }
      if (t.karsi != 0 && karsiHesap != null) {
        await x.insert('finans_hareket', {
          'hesap_id': karsiHesap, 'tarih': tarih, 'tur': t.ad, 'kategori': kategori, 'aciklama': aciklama,
          'giris': t.karsi > 0 ? tutar : 0, 'cikis': t.karsi < 0 ? tutar : 0, 'grup': g, 'kaynak': kaynak,
        });
      }
      if (t.cari != 0 && cari != null) {
        await x.insert('cari_hareket', {
          'cari_id': cari, 'tarih': tarih, 'tur': t.ad, 'aciklama': aciklama,
          'borc': t.cari > 0 ? tutar : 0, 'alacak': t.cari < 0 ? tutar : 0, 'grup': g, 'kaynak': kaynak,
        });
      }
      if (t.karsiCari != 0 && karsiCari != null) {
        await x.insert('cari_hareket', {
          'cari_id': karsiCari, 'tarih': tarih, 'tur': t.ad, 'aciklama': aciklama,
          'borc': t.karsiCari > 0 ? tutar : 0, 'alacak': t.karsiCari < 0 ? tutar : 0, 'grup': g, 'kaynak': kaynak,
        });
      }
    }

    if (tx != null) {
      await yap(tx);
    } else {
      final d = await DB.db;
      await d.transaction((x) => yap(x));
    }
    return g;
  }

  static Future<String> sonrakiNo(String tur) async {
    final on = tur.split('_').map((e) => e.isEmpty ? '' : e[0]).join().toUpperCase();
    final r = await DB.tek('SELECT COUNT(*) n FROM belge WHERE tur=?', [tur]);
    final n = ((r?['n'] as int?) ?? 0) + 1;
    return '$on${n.toString().padLeft(6, '0')}';
  }

  /// Belgeyi kaydeder; stok, cari ve (peşin ise) kasa/banka hareketlerini oluşturur.
  static Future<int> belgeKaydet(Map<String, Object?> b, List<Map<String, Object?>> satirlar, {int? id}) async {
    final d = await DB.db;
    return d.transaction((tx) async {
      final t = turlar[b['tur']]!;
      String grup;
      if (id != null) {
        final o = await tx.query('belge', columns: ['grup'], where: 'id=?', whereArgs: [id]);
        grup = (o.isNotEmpty ? o.first['grup'] as String? : null) ?? DB.yeniGrup();
        await DB.grupSilTx(tx, grup);
        await tx.delete('belge_satir', where: 'belge_id=?', whereArgs: [id]);
      } else {
        grup = DB.yeniGrup();
      }
      double ara = 0, kdvT = 0, isk = 0;
      final temiz = <Map<String, Object?>>[];
      for (final s in satirlar) {
        final m = sy(s['miktar']), f = sy(s['fiyat']), ik = sy(s['iskonto']), k = sy(s['kdv']);
        final brut = m * f, iskT = brut * ik / 100, net = brut - iskT;
        ara += brut;
        isk += iskT;
        kdvT += net * k / 100;
        temiz.add({
          'urun_id': s['urun_id'], 'aciklama': s['aciklama'], 'miktar': m, 'birim': s['birim'],
          'fiyat': f, 'kdv': k, 'iskonto': ik, 'tutar': net,
        });
      }
      final genel = ara - isk + kdvT;
      final m = Map<String, Object?>.from(b)
        ..remove('id')
        ..['ara_toplam'] = ara
        ..['iskonto'] = isk
        ..['kdv_toplam'] = kdvT
        ..['genel_toplam'] = genel
        ..['grup'] = grup;
      int bid;
      if (id != null) {
        await tx.update('belge', m, where: 'id=?', whereArgs: [id]);
        bid = id;
      } else {
        bid = await tx.insert('belge', m);
      }
      final tarih = b['tarih'] as String;
      final depo = (b['depo_id'] as int?) ?? 1;
      final no = b['no'] ?? '';
      final stokEtkisiz = b['stok_etkisiz'] == 1;
      for (final s in temiz) {
        await tx.insert('belge_satir', {...s, 'belge_id': bid});
        final uid = s['urun_id'] as int?;
        if (uid == null || stokEtkisiz) continue;
        final mik = s['miktar'] as double;
        final birimNet = mik == 0 ? 0.0 : (s['tutar'] as double) / mik;
        Future<void> hareket(int dep, double giris, double cikis) => tx.insert('stok_hareket', {
              'urun_id': uid, 'depo_id': dep, 'tarih': tarih, 'tur': t.kod, 'giris': giris, 'cikis': cikis,
              'fiyat': birimNet, 'belge_id': bid, 'grup': grup, 'aciklama': '${t.ad} $no',
            });
        if (t.kod == 'depo_transfer') {
          await hareket(depo, 0, mik);
          await hareket((b['hedef_depo_id'] as int?) ?? depo, mik, 0);
        } else if (t.stok != 0) {
          await hareket(depo, t.stok > 0 ? mik : 0, t.stok < 0 ? mik : 0);
        }
      }
      final cari = b['cari_id'] as int?;
      if (t.cari != 0 && cari != null) {
        await tx.insert('cari_hareket', {
          'cari_id': cari, 'tarih': tarih, 'tur': t.ad, 'aciklama': '${t.ad} $no',
          'borc': t.cari > 0 ? genel : 0, 'alacak': t.cari < 0 ? genel : 0, 'belge_id': bid, 'grup': grup,
        });
      }
      final hesap = b['hesap_id'] as int?;
      if (t.cari != 0 && (b['odeme'] ?? 'acik') != 'acik' && hesap != null) {
        final tahsil = t.cari > 0;
        await tx.insert('finans_hareket', {
          'hesap_id': hesap, 'tarih': tarih, 'tur': tahsil ? 'Tahsilat' : 'Ödeme', 'cari_id': cari,
          'kategori': t.ad, 'aciklama': '${t.ad} $no', 'giris': tahsil ? genel : 0, 'cikis': tahsil ? 0 : genel,
          'grup': grup,
        });
        if (cari != null) {
          await tx.insert('cari_hareket', {
            'cari_id': cari, 'tarih': tarih, 'tur': tahsil ? 'Tahsilat' : 'Ödeme', 'aciklama': '${t.ad} $no',
            'borc': tahsil ? 0 : genel, 'alacak': tahsil ? genel : 0, 'belge_id': bid, 'grup': grup,
          });
        }
      }
      final kaynakId = b['kaynak_id'] as int?;
      if (kaynakId != null && id == null) {
        await tx.update('belge', {'durum': 'Kapandı'}, where: 'id=?', whereArgs: [kaynakId]);
      }
      return bid;
    });
  }

  static Future<double> ortMaliyet(int urunId) async {
    final r = await DB.tek('''SELECT IFNULL(SUM(giris*fiyat)/NULLIF(SUM(giris),0),
        (SELECT alis_fiyat FROM urun WHERE id=?)) m FROM stok_hareket WHERE urun_id=? AND giris>0
        AND tur IN ($maliyetTurleri)''', [urunId, urunId]);
    return sy(r?['m']);
  }

  static Future<double> stok(int urunId) async {
    final r = await DB.tek('SELECT IFNULL(SUM(giris-cikis),0) s FROM stok_hareket WHERE urun_id=?', [urunId]);
    return sy(r?['s']);
  }

  static Future<int> cariBulEkle(String ad, {String? tip}) async {
    final a = ad.trim();
    final r = await DB.tek('SELECT id FROM cari WHERE kod=? OR UPPER(unvan)=UPPER(?)', [a, a]);
    if (r != null) return r['id'] as int;
    return DB.ekle('cari', {'unvan': a, if (tip != null) 'tip': tip});
  }

  static Future<int> urunBulEkle(String ad, {double fiyat = 0, bool alis = false}) async {
    final a = ad.trim();
    final r = await DB.tek('SELECT id FROM urun WHERE kod=? OR barkod=? OR UPPER(ad)=UPPER(?)', [a, a, a]);
    if (r != null) return r['id'] as int;
    return DB.ekle('urun', {'ad': a, alis ? 'alis_fiyat' : 'satis_fiyat': fiyat});
  }

  static Future<int> ilkHesap(String tip) async {
    final r = await DB.tek('SELECT id FROM hesap WHERE tip=? ORDER BY id LIMIT 1', [tip]);
    if (r != null) return r['id'] as int;
    return DB.ekle('hesap', {'tip': tip, 'ad': tip == 'kasa' ? 'Merkez Kasa' : 'Banka'});
  }
}
