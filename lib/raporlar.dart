import 'package:flutter/material.dart';

import 'belge.dart';
import 'db.dart';
import 'ortak.dart';
import 'servis.dart';

// ---------------- Cari ----------------

Widget cariHareketListesi() => RaporEkrani(
      baslik: 'Cari Hareket Listesi',
      kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('unvan', 'Cari'), Kolon('tur', 'İşlem'), Kolon('aciklama', 'Açıklama'), Kolon('borc', 'Borç', para: true), Kolon('alacak', 'Alacak', para: true)],
      veri: (b, s) => DB.q('SELECT h.*, c.unvan FROM cari_hareket h LEFT JOIN cari c ON c.id=h.cari_id WHERE h.tarih BETWEEN ? AND ? ORDER BY h.tarih DESC, h.id DESC', [b, s]),
      tikla: belgeVeyaHareket,
    );

Widget cariFisListesi() => RaporEkrani(
      baslik: 'Cari Fiş Listesi',
      kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('tur', 'Fiş Türü'), Kolon('cariler', 'Cari'), Kolon('aciklama', 'Açıklama'), Kolon('borc', 'Borç', para: true), Kolon('alacak', 'Alacak', para: true)],
      veri: (b, s) => DB.q('''SELECT MIN(h.tarih) tarih, h.tur, GROUP_CONCAT(c.unvan, ', ') cariler, MAX(h.aciklama) aciklama,
          SUM(h.borc) borc, SUM(h.alacak) alacak, h.grup, MAX(h.belge_id) belge_id FROM cari_hareket h LEFT JOIN cari c ON c.id=h.cari_id
          WHERE h.tarih BETWEEN ? AND ? GROUP BY h.grup ORDER BY tarih DESC''', [b, s]),
      tikla: belgeVeyaHareket,
    );

Widget cariRaporu(String tip) {
  final borclu = tip == 'borclu';
  return RaporEkrani(
    baslik: borclu ? 'Bize Borçlu Cariler' : 'Borçlu Olduğumuz Cariler',
    tarihli: false,
    kolonlar: const [Kolon('unvan', 'Cari'), Kolon('tel', 'Telefon'), Kolon('son', 'Son Hareket', tarih: true), Kolon('bakiye', 'Bakiye', para: true)],
    veri: (b, s) async {
      final r = await DB.q('''SELECT c.unvan, c.tel, MAX(h.tarih) son, SUM(h.borc-h.alacak) bakiye FROM cari c JOIN cari_hareket h ON h.cari_id=c.id
        GROUP BY c.id HAVING bakiye ${borclu ? '> 0.005' : '< -0.005'} ORDER BY ABS(bakiye) DESC''');
      return r;
    },
  );
}

Future<void> belgeVeyaHareket(BuildContext c, Map<String, Object?> r) async {
  final b = r['belge_id'] as int?;
  if (b != null) {
    final bl = await DB.tek('SELECT tur FROM belge WHERE id=?', [b]);
    if (bl != null && c.mounted) {
      await Navigator.push(c, MaterialPageRoute(builder: (_) => BelgeForm(bl['tur'] as String, id: b)));
      return;
    }
  }
  if (c.mounted) await hareketTikla(c, r);
}

// ---------------- Ürün / Stok ----------------

Widget urunFisListesi() => RaporEkrani(
      baslik: 'Ürün Fiş Listesi',
      kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('turad', 'Fiş Türü'), Kolon('no', 'No'), Kolon('aciklama', 'Açıklama'), Kolon('genel_toplam', 'Tutar', para: true)],
      veri: (b, s) async {
        final r = await DB.q("SELECT b.* FROM belge b WHERE b.tur IN ('stok_giris','stok_cikis','sayim_fazlasi','sayim_eksigi','fire','sarf','uretimden_giris','stok_acilis','stok_devir','depo_transfer') AND b.tarih BETWEEN ? AND ? ORDER BY b.tarih DESC", [b, s]);
        return r.map((x) => {...x, 'turad': turlar[x['tur']]?.ad, 'belge_id': x['id']}).toList();
      },
      tikla: belgeVeyaHareket,
    );

Widget urunHareketListesi() => RaporEkrani(
      baslik: 'Ürün Hareket Listesi',
      kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('urun', 'Ürün'), Kolon('depo', 'Depo'), Kolon('aciklama', 'İşlem'), Kolon('giris', 'Giriş', sayi: true), Kolon('cikis', 'Çıkış', sayi: true), Kolon('fiyat', 'Birim Fiyat', para: true)],
      veri: (b, s) => DB.q('SELECT s.*, u.ad urun, d.ad depo FROM stok_hareket s JOIN urun u ON u.id=s.urun_id LEFT JOIN depo d ON d.id=s.depo_id WHERE s.tarih BETWEEN ? AND ? ORDER BY s.tarih DESC, s.id DESC', [b, s]),
      tikla: belgeVeyaHareket,
    );

Widget urunOzetListesi() => RaporEkrani(
      baslik: 'Ürün Özet Listesi',
      kolonlar: const [Kolon('kod', 'Kod'), Kolon('ad', 'Ürün'), Kolon('devir', 'Önceki', sayi: true), Kolon('giris', 'Giriş', sayi: true), Kolon('cikis', 'Çıkış', sayi: true), Kolon('kalan', 'Kalan', sayi: true)],
      veri: (b, s) => DB.q('''SELECT u.kod, u.ad,
          IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id AND tarih<?),0) devir,
          IFNULL((SELECT SUM(giris) FROM stok_hareket WHERE urun_id=u.id AND tarih BETWEEN ? AND ?),0) giris,
          IFNULL((SELECT SUM(cikis) FROM stok_hareket WHERE urun_id=u.id AND tarih BETWEEN ? AND ?),0) cikis,
          IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id AND tarih<=?),0) kalan
          FROM urun u ORDER BY u.ad''', [b, b, s, b, s, s]),
    );

Widget urunDurumListesi() => RaporEkrani(
      baslik: 'Ürün Durum Listesi',
      tarihli: false,
      kolonlar: const [Kolon('kod', 'Kod'), Kolon('ad', 'Ürün'), Kolon('stok', 'Stok', sayi: true), Kolon('kritik', 'Kritik', sayi: true), Kolon('maliyet', 'Ort. Maliyet', para: true), Kolon('deger', 'Stok Değeri', para: true), Kolon('durum', 'Durum')],
      veri: (b, s) async {
        final r = await DB.q('''SELECT u.kod, u.ad, u.kritik, IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0) stok,
          IFNULL((SELECT SUM(giris*fiyat)/NULLIF(SUM(giris),0) FROM stok_hareket WHERE urun_id=u.id AND giris>0 AND tur IN ($maliyetTurleri)), u.alis_fiyat) maliyet
          FROM urun u ORDER BY u.ad''');
        return r.map((x) {
          final st = sy(x['stok']), kr = sy(x['kritik']);
          return {...x, 'deger': st * sy(x['maliyet']), 'durum': st < 0 ? 'EKSİ STOK' : (kr > 0 && st <= kr ? 'Kritik' : 'Normal')};
        }).toList();
      },
    );

Widget depoStokRaporu() => RaporEkrani(
      baslik: 'Depo Bazında Stok',
      tarihli: false,
      kolonlar: const [Kolon('depo', 'Depo'), Kolon('ad', 'Ürün'), Kolon('stok', 'Miktar', sayi: true)],
      veri: (b, s) => DB.q('SELECT d.ad depo, u.ad, SUM(s.giris-s.cikis) stok FROM stok_hareket s JOIN urun u ON u.id=s.urun_id JOIN depo d ON d.id=s.depo_id GROUP BY d.id, u.id HAVING ABS(stok)>0.0001 ORDER BY d.id, u.ad'),
    );

Widget barkodListesi() => RaporEkrani(
      baslik: 'Barkod / Etiket Listesi',
      tarihli: false,
      kolonlar: const [Kolon('barkod', 'Barkod'), Kolon('kod', 'Kod'), Kolon('ad', 'Ürün'), Kolon('fiyat', 'Fiyat (KDV dahil)', para: true)],
      veri: (b, s) => DB.q('SELECT barkod, kod, ad, satis_fiyat*(1+kdv/100.0) fiyat FROM urun ORDER BY ad'),
      ust: const Padding(padding: EdgeInsets.all(8), child: Text('Excel olarak paylaşıp etiket yazıcısı programında açabilirsiniz.', style: TextStyle(fontSize: 12))),
    );

// ---------------- Fatura / İrsaliye / Fiş / Sipariş ----------------

Widget belgeSatirListesi(String grup, String baslik) {
  final kodlar = grupTurleri(grup).map((t) => "'${t.kod}'").join(',');
  return RaporEkrani(
    baslik: baslik,
    kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('no', 'No'), Kolon('turad', 'Tür'), Kolon('unvan', 'Cari'), Kolon('urun', 'Ürün/Hizmet'), Kolon('miktar', 'Miktar', sayi: true), Kolon('fiyat', 'Fiyat', para: true), Kolon('tutar', 'Tutar', para: true)],
    veri: (b, s) async {
      final r = await DB.q('''SELECT b.id belge_id, b.tarih, b.no, b.tur, c.unvan, IFNULL(u.ad, bs.aciklama) urun, bs.miktar, bs.fiyat, bs.tutar
        FROM belge_satir bs JOIN belge b ON b.id=bs.belge_id LEFT JOIN cari c ON c.id=b.cari_id LEFT JOIN urun u ON u.id=bs.urun_id
        WHERE b.tur IN ($kodlar) AND b.tarih BETWEEN ? AND ? ORDER BY b.tarih DESC''', [b, s]);
      return r.map((x) => {...x, 'turad': turlar[x['tur']]?.ad}).toList();
    },
    tikla: belgeVeyaHareket,
  );
}

Widget kdvRaporu() => RaporEkrani(
      baslik: 'Aylık KDV / Alış-Satış Raporu',
      kolonlar: const [Kolon('ay', 'Ay'), Kolon('satis', 'Satış Matrah', para: true), Kolon('hes_kdv', 'Hesaplanan KDV', para: true), Kolon('alis', 'Alış Matrah', para: true), Kolon('ind_kdv', 'İndirilecek KDV', para: true), Kolon('fark', 'Fark', para: true)],
      veri: (b, s) async {
        final r = await DB.q('''SELECT substr(tarih,1,7) ay,
          SUM(CASE WHEN tur IN ('satis_fatura','satis_fis','hizli_satis') THEN ara_toplam-iskonto WHEN tur IN ('satis_iade_fatura','satis_iade_fis','hizli_satis_iade') THEN -(ara_toplam-iskonto) ELSE 0 END) satis,
          SUM(CASE WHEN tur IN ('satis_fatura','satis_fis','hizli_satis') THEN kdv_toplam WHEN tur IN ('satis_iade_fatura','satis_iade_fis','hizli_satis_iade') THEN -kdv_toplam ELSE 0 END) hes_kdv,
          SUM(CASE WHEN tur IN ('alis_fatura','alis_fis') THEN ara_toplam-iskonto WHEN tur IN ('alis_iade_fatura','alis_iade_fis') THEN -(ara_toplam-iskonto) ELSE 0 END) alis,
          SUM(CASE WHEN tur IN ('alis_fatura','alis_fis') THEN kdv_toplam WHEN tur IN ('alis_iade_fatura','alis_iade_fis') THEN -kdv_toplam ELSE 0 END) ind_kdv
          FROM belge WHERE tarih BETWEEN ? AND ? GROUP BY ay ORDER BY ay''', [b, s]);
        return r.map((x) => {...x, 'fark': sy(x['hes_kdv']) - sy(x['ind_kdv'])}).toList();
      },
    );

Widget siparisIzleme(bool toplam) => RaporEkrani(
      baslik: toplam ? 'Ürün Bazında Sipariş Toplam' : 'Ürün Bazında Sipariş İzleme',
      kolonlar: toplam
          ? const [Kolon('urun', 'Ürün'), Kolon('alinan', 'Alınan (müşteri)', sayi: true), Kolon('verilen', 'Verilen (tedarikçi)', sayi: true), Kolon('stok', 'Mevcut Stok', sayi: true), Kolon('ihtiyac', 'İhtiyaç', sayi: true)]
          : const [Kolon('tarih', 'Tarih', tarih: true), Kolon('no', 'No'), Kolon('yon', 'Tür'), Kolon('unvan', 'Cari'), Kolon('urun', 'Ürün'), Kolon('miktar', 'Miktar', sayi: true), Kolon('durum', 'Durum')],
      veri: (b, s) async {
        if (!toplam) {
          final r = await DB.q('''SELECT b.id belge_id, b.tarih, b.no, b.tur, b.durum, c.unvan, IFNULL(u.ad, bs.aciklama) urun, bs.miktar FROM belge_satir bs JOIN belge b ON b.id=bs.belge_id
            LEFT JOIN cari c ON c.id=b.cari_id LEFT JOIN urun u ON u.id=bs.urun_id WHERE b.tur IN ('siparis_alinan','siparis_verilen') AND b.tarih BETWEEN ? AND ? ORDER BY b.tarih DESC''', [b, s]);
          return r.map((x) => {...x, 'yon': x['tur'] == 'siparis_alinan' ? 'Alınan' : 'Verilen'}).toList();
        }
        final r = await DB.q('''SELECT u.ad urun,
          SUM(CASE WHEN b.tur='siparis_alinan' THEN bs.miktar ELSE 0 END) alinan,
          SUM(CASE WHEN b.tur='siparis_verilen' THEN bs.miktar ELSE 0 END) verilen,
          IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0) stok
          FROM belge_satir bs JOIN belge b ON b.id=bs.belge_id JOIN urun u ON u.id=bs.urun_id
          WHERE b.tur IN ('siparis_alinan','siparis_verilen') AND b.durum<>'Kapandı' AND b.tarih BETWEEN ? AND ? GROUP BY u.id ORDER BY u.ad''', [b, s]);
        return r.map((x) {
          final ih = sy(x['alinan']) - sy(x['verilen']) - sy(x['stok']);
          return {...x, 'ihtiyac': ih > 0 ? ih : 0};
        }).toList();
      },
      tikla: toplam ? null : belgeVeyaHareket,
    );

// ---------------- Üretim ----------------

Widget uretimCiktiRaporu() => RaporEkrani(
      baslik: 'Çıktı Raporu',
      kolonlar: const [Kolon('tarih', 'Tarih', tarih: true), Kolon('urun', 'Mamul'), Kolon('giris', 'Miktar', sayi: true), Kolon('fiyat', 'Birim Maliyet', para: true), Kolon('toplam', 'Toplam Maliyet', para: true)],
      veri: (b, s) => DB.q("SELECT s.tarih, u.ad urun, s.giris, s.fiyat, s.giris*s.fiyat toplam FROM stok_hareket s JOIN urun u ON u.id=s.urun_id WHERE s.tur='uretimden_giris' AND s.tarih BETWEEN ? AND ? ORDER BY s.tarih DESC", [b, s]),
    );

Widget uretimEksikListesi() => RaporEkrani(
      baslik: 'Genel Üretim Eksik Listesi',
      tarihli: false,
      kolonlar: const [Kolon('ad', 'Hammadde'), Kolon('gerekli', 'Gerekli', sayi: true), Kolon('stok', 'Stok', sayi: true), Kolon('eksik', 'Eksik', sayi: true)],
      veri: (b, s) async {
        final r = await DB.q('''SELECT u.ad, SUM(k.miktar*e.miktar/IFNULL(NULLIF(r.miktar,0),1)) gerekli,
          IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0) stok
          FROM uretim_emri e JOIN recete r ON r.id=e.recete_id JOIN recete_kalem k ON k.recete_id=r.id JOIN urun u ON u.id=k.urun_id
          WHERE e.durum='Bekliyor' GROUP BY u.id ORDER BY u.ad''');
        return r.map((x) {
          final e = sy(x['gerekli']) - sy(x['stok']);
          return {...x, 'eksik': e > 0 ? e : 0};
        }).toList();
      },
    );

Widget uretimDurumListesi() => RaporEkrani(
      baslik: 'Üretim Durum Listesi',
      kolonlar: const [Kolon('id', 'Emir'), Kolon('tarih', 'Tarih', tarih: true), Kolon('urun', 'Mamul'), Kolon('miktar', 'Miktar', sayi: true), Kolon('durum', 'Durum')],
      veri: (b, s) => DB.q('SELECT e.id, e.tarih, e.miktar, e.durum, u.ad urun FROM uretim_emri e JOIN recete r ON r.id=e.recete_id LEFT JOIN urun u ON u.id=r.urun_id WHERE e.tarih BETWEEN ? AND ? ORDER BY e.tarih DESC', [b, s]),
    );

// ---------------- Kasa / Banka ----------------

Widget finansHareketListesi(String tip, String baslik, {bool fis = false}) => RaporEkrani(
      baslik: baslik,
      kolonlar: [
        const Kolon('tarih', 'Tarih', tarih: true),
        Kolon('hesap', tip == 'kasa' ? 'Kasa' : 'Hesap'),
        const Kolon('tur', 'İşlem'),
        const Kolon('unvan', 'Cari'),
        const Kolon('kategori', 'Kategori'),
        const Kolon('aciklama', 'Açıklama'),
        const Kolon('giris', 'Giriş', para: true),
        const Kolon('cikis', 'Çıkış', para: true),
      ],
      veri: (b, s) => DB.q('''SELECT ${fis ? 'MIN(f.tarih) tarih, GROUP_CONCAT(h.ad, \' → \') hesap, MAX(f.tur) tur, MAX(c.unvan) unvan, MAX(f.kategori) kategori, MAX(f.aciklama) aciklama, SUM(f.giris) giris, SUM(f.cikis) cikis, f.grup' : 'f.*, h.ad hesap, c.unvan'}
          FROM finans_hareket f JOIN hesap h ON h.id=f.hesap_id LEFT JOIN cari c ON c.id=f.cari_id
          WHERE h.tip=? AND f.tarih BETWEEN ? AND ? ${fis ? 'GROUP BY f.grup' : ''} ORDER BY tarih DESC''', [tip, b, s]),
      tikla: hareketTikla,
    );

Widget hesapEkstre(String tip) => RaporEkrani(
      baslik: tip == 'kasa' ? 'Kasa Bakiye Listesi' : 'Banka Hesap Listesi',
      kolonlar: const [Kolon('ad', 'Hesap'), Kolon('iban', 'IBAN'), Kolon('giris', 'Toplam Giriş', para: true), Kolon('cikis', 'Toplam Çıkış', para: true), Kolon('bakiye', 'Bakiye', para: true)],
      veri: (b, s) => DB.q('''SELECT h.ad, h.iban, IFNULL(SUM(f.giris),0) giris, IFNULL(SUM(f.cikis),0) cikis, IFNULL(SUM(f.giris-f.cikis),0) bakiye
          FROM hesap h LEFT JOIN finans_hareket f ON f.hesap_id=h.id AND f.tarih<=? WHERE h.tip=? GROUP BY h.id ORDER BY h.id''', [s, tip]),
    );

Widget giderRaporu() => RaporEkrani(
      baslik: 'Gelir / Gider Kategorileri',
      kolonlar: const [Kolon('kategori', 'Kategori'), Kolon('gelir', 'Gelir', para: true), Kolon('gider', 'Gider', para: true)],
      veri: (b, s) => DB.q('''SELECT IFNULL(NULLIF(kategori,''),'(Kategorisiz)') kategori, SUM(CASE WHEN tur IN ($gelirTurleri) THEN giris ELSE 0 END) gelir,
          SUM(CASE WHEN tur IN ($giderTurleri) THEN cikis ELSE 0 END) gider FROM finans_hareket
          WHERE tur IN ($gelirTurleri, $giderTurleri) AND tarih BETWEEN ? AND ? GROUP BY 1 ORDER BY gider DESC''', [b, s]),
    );

// ---------------- Çek / Senet ----------------

Widget cekRaporu(String tip) => RaporEkrani(
      baslik: tip == 'vade' ? 'Vadesi Yaklaşan Çek/Senetler (30 gün)' : 'Çek/Senet Bordrosu',
      tarihli: tip != 'vade',
      kolonlar: const [Kolon('yon', 'Yön'), Kolon('tur', 'Tür'), Kolon('no', 'No'), Kolon('unvan', 'Cari'), Kolon('banka', 'Banka'), Kolon('tarih', 'Tarih', tarih: true), Kolon('vade', 'Vade', tarih: true), Kolon('durum', 'Durum'), Kolon('tutar', 'Tutar', para: true)],
      veri: (b, s) => tip == 'vade'
          ? DB.q("SELECT k.*, c.unvan FROM cek_senet k LEFT JOIN cari c ON c.id=k.cari_id WHERE durum='Portföyde' AND vade<=? ORDER BY vade", [tarihS(DateTime.now().add(const Duration(days: 30)))])
          : DB.q('SELECT k.*, c.unvan FROM cek_senet k LEFT JOIN cari c ON c.id=k.cari_id WHERE k.tarih BETWEEN ? AND ? ORDER BY k.tarih DESC', [b, s]),
    );

// ---------------- Satış / Kar-Zarar ----------------

const _satisSql = '''SELECT bs.*, b.cari_id, b.tarih, b.tur, b.odeme,
  CASE WHEN b.tur LIKE '%iade%' THEN -1 ELSE 1 END sg FROM belge_satir bs JOIN belge b ON b.id=bs.belge_id
  WHERE b.tur IN ($satisTurleri) AND b.tarih BETWEEN ? AND ?''';

const _maliyetAlt = '''IFNULL((SELECT SUM(s.giris*s.fiyat)/NULLIF(SUM(s.giris),0) FROM stok_hareket s WHERE s.urun_id=x.urun_id AND s.giris>0
  AND s.tur IN ($maliyetTurleri)), (SELECT alis_fiyat FROM urun WHERE id=x.urun_id))''';

List<Map<String, Object?>> _karEkle(List<Map<String, Object?>> r) => r.map((x) {
      final sat = sy(x['satis']), mal = sy(x['maliyet']);
      return {...x, 'kar': sat - mal, 'oran': sat == 0 ? '' : '%${((sat - mal) / sat * 100).toStringAsFixed(1)}'};
    }).toList();

const _karKolon = [Kolon('satis', 'Satış (KDV hariç)', para: true), Kolon('maliyet', 'Maliyet', para: true), Kolon('kar', 'Kâr', para: true), Kolon('oran', 'Kâr %')];

Widget karZararUrun({String baslik = 'Kar/Zarar Analizi'}) => RaporEkrani(
      baslik: baslik,
      kolonlar: const [Kolon('ad', 'Ürün / Hizmet'), Kolon('miktar', 'Miktar', sayi: true), ..._karKolon],
      veri: (b, s) async => _karEkle(await DB.q('''SELECT IFNULL(u.ad, x.aciklama) ad, SUM(x.sg*x.miktar) miktar, SUM(x.sg*x.tutar) satis,
          SUM(x.sg*x.miktar*IFNULL($_maliyetAlt,0)) maliyet FROM ($_satisSql) x LEFT JOIN urun u ON u.id=x.urun_id
          GROUP BY IFNULL(CAST(x.urun_id AS TEXT), x.aciklama) ORDER BY satis DESC''', [b, s])),
    );

Widget karZararCari({bool detay = false, String? baslik}) => RaporEkrani(
      baslik: baslik ?? (detay ? 'Kar/Zarar Analizi (Cari Hesap Detaylı)' : 'Kar/Zarar Analizi (Cari Hesap)'),
      kolonlar: [const Kolon('unvan', 'Cari'), if (detay) const Kolon('ad', 'Ürün / Hizmet'), if (detay) const Kolon('miktar', 'Miktar', sayi: true), ..._karKolon],
      veri: (b, s) async => _karEkle(await DB.q('''SELECT IFNULL(c.unvan,'(Perakende)') unvan, ${detay ? 'IFNULL(u.ad, x.aciklama) ad, SUM(x.sg*x.miktar) miktar,' : ''}
          SUM(x.sg*x.tutar) satis, SUM(x.sg*x.miktar*IFNULL($_maliyetAlt,0)) maliyet
          FROM ($_satisSql) x LEFT JOIN cari c ON c.id=x.cari_id LEFT JOIN urun u ON u.id=x.urun_id
          GROUP BY x.cari_id ${detay ? ', IFNULL(CAST(x.urun_id AS TEXT), x.aciklama)' : ''} ORDER BY unvan, satis DESC''', [b, s])),
    );

Widget gunlukSatis({bool detay = false}) => RaporEkrani(
      baslik: detay ? 'Günlük Satış Detaylı Rapor' : 'Günlük Satış Raporu',
      kolonlar: detay
          ? const [Kolon('tarih', 'Tarih', tarih: true), Kolon('no', 'Belge'), Kolon('unvan', 'Cari'), Kolon('ad', 'Ürün'), Kolon('miktar', 'Miktar', sayi: true), Kolon('tutar', 'Tutar (KDV hariç)', para: true)]
          : const [Kolon('tarih', 'Tarih', tarih: true), Kolon('adet', 'Belge Sayısı', sayi: true), Kolon('satis', 'Satış', para: true), Kolon('iade', 'İade', para: true), Kolon('net', 'Net (KDV dahil)', para: true)],
      veri: (b, s) => detay
          ? DB.q('''SELECT b.id belge_id, b.tarih, b.no, c.unvan, IFNULL(u.ad, bs.aciklama) ad, CASE WHEN b.tur LIKE '%iade%' THEN -bs.miktar ELSE bs.miktar END miktar,
              CASE WHEN b.tur LIKE '%iade%' THEN -bs.tutar ELSE bs.tutar END tutar FROM belge_satir bs JOIN belge b ON b.id=bs.belge_id
              LEFT JOIN cari c ON c.id=b.cari_id LEFT JOIN urun u ON u.id=bs.urun_id WHERE b.tur IN ($satisTurleri) AND b.tarih BETWEEN ? AND ? ORDER BY b.tarih DESC''', [b, s])
          : DB.q('''SELECT tarih, COUNT(*) adet, SUM(CASE WHEN tur LIKE '%iade%' THEN 0 ELSE genel_toplam END) satis,
              SUM(CASE WHEN tur LIKE '%iade%' THEN genel_toplam ELSE 0 END) iade,
              SUM(CASE WHEN tur LIKE '%iade%' THEN -genel_toplam ELSE genel_toplam END) net
              FROM belge WHERE tur IN ($satisTurleri) AND tarih BETWEEN ? AND ? GROUP BY tarih ORDER BY tarih DESC''', [b, s]),
      tikla: detay ? belgeVeyaHareket : null,
    );

Widget gunSonu() => OzetEkrani(
      baslik: 'Gün Sonu Özet Rapor',
      veri: (b, s) async {
        final r = await DB.q('''SELECT tur, odeme, h.tip, COUNT(*) n, SUM(genel_toplam) t FROM belge b LEFT JOIN hesap h ON h.id=b.hesap_id
            WHERE tur IN ('hizli_satis','hizli_satis_iade') AND tarih BETWEEN ? AND ? GROUP BY tur, odeme, h.tip''', [b, s]);
        double nakit = 0, kart = 0, veresiye = 0, iade = 0;
        int adet = 0;
        for (final x in r) {
          final t = sy(x['t']);
          adet += (x['n'] as int?) ?? 0;
          if (x['tur'] == 'hizli_satis_iade') {
            iade += t;
          } else if (x['odeme'] == 'acik') {
            veresiye += t;
          } else if (x['tip'] == 'kasa') {
            nakit += t;
          } else {
            kart += t;
          }
        }
        return [
          const MapEntry('Hızlı satış', null),
          MapEntry('İşlem sayısı', '$adet'),
          MapEntry('Nakit', nakit),
          MapEntry('Kart / Banka', kart),
          MapEntry('Veresiye', veresiye),
          MapEntry('İade', -iade),
          MapEntry('NET', nakit + kart + veresiye - iade),
        ];
      },
    );

Widget satisDokumu() => RaporEkrani(
      baslik: 'Satış Dökümü',
      kolonlar: const [Kolon('ad', 'Ürün / Hizmet'), Kolon('miktar', 'Miktar', sayi: true), Kolon('satis', 'Tutar (KDV hariç)', para: true), Kolon('ort', 'Ort. Fiyat', para: true)],
      veri: (b, s) async {
        final r = await DB.q('''SELECT IFNULL(u.ad, x.aciklama) ad, SUM(x.sg*x.miktar) miktar, SUM(x.sg*x.tutar) satis FROM ($_satisSql) x LEFT JOIN urun u ON u.id=x.urun_id
          GROUP BY IFNULL(CAST(x.urun_id AS TEXT), x.aciklama) ORDER BY miktar DESC''', [b, s]);
        return r.map((x) => {...x, 'ort': sy(x['miktar']) == 0 ? 0 : sy(x['satis']) / sy(x['miktar'])}).toList();
      },
    );

Widget satisOzet() => RaporEkrani(
      baslik: 'Satış Özet Raporu (Aylık)',
      kolonlar: const [Kolon('ay', 'Ay'), Kolon('belge', 'Belge', sayi: true), Kolon('matrah', 'Matrah', para: true), Kolon('kdv', 'KDV', para: true), Kolon('toplam', 'Toplam', para: true)],
      veri: (b, s) => DB.q('''SELECT substr(tarih,1,7) ay, COUNT(*) belge, SUM((CASE WHEN tur LIKE '%iade%' THEN -1 ELSE 1 END)*(ara_toplam-iskonto)) matrah,
          SUM((CASE WHEN tur LIKE '%iade%' THEN -1 ELSE 1 END)*kdv_toplam) kdv, SUM((CASE WHEN tur LIKE '%iade%' THEN -1 ELSE 1 END)*genel_toplam) toplam
          FROM belge WHERE tur IN ($satisTurleri) AND tarih BETWEEN ? AND ? GROUP BY ay ORDER BY ay DESC''', [b, s]),
    );

Future<List<MapEntry<String, Object?>>> _karZararOzet(String b, String s) async {
  final sat = await DB.tek('SELECT SUM(x.sg*x.tutar) satis, SUM(x.sg*x.miktar*IFNULL($_maliyetAlt,0)) maliyet FROM ($_satisSql) x', [b, s]);
  final gg = await DB.tek('''SELECT SUM(CASE WHEN tur IN ($gelirTurleri) THEN giris ELSE 0 END) gelir,
      SUM(CASE WHEN tur IN ($giderTurleri) THEN cikis ELSE 0 END) gider FROM finans_hareket WHERE tarih BETWEEN ? AND ?''', [b, s]);
  final alis = await DB.tek('''SELECT SUM(CASE WHEN tur LIKE '%iade%' THEN -(ara_toplam-iskonto) ELSE ara_toplam-iskonto END) a FROM belge WHERE tur IN ($alisTurleri) AND tarih BETWEEN ? AND ?''', [b, s]);
  final satis = sy(sat?['satis']), maliyet = sy(sat?['maliyet']), gelir = sy(gg?['gelir']), gider = sy(gg?['gider']);
  return [
    const MapEntry('Satışlar', null),
    MapEntry('Net satış (KDV hariç)', satis),
    MapEntry('Satılan malın maliyeti', -maliyet),
    MapEntry('BRÜT KÂR', satis - maliyet),
    const MapEntry('Diğer', null),
    MapEntry('Diğer gelirler (kasa/banka)', gelir),
    MapEntry('Giderler (kasa/banka)', -gider),
    MapEntry('NET KÂR / ZARAR', satis - maliyet + gelir - gider),
    const MapEntry('Bilgi', null),
    MapEntry('Dönem alışları (KDV hariç)', alis?['a'] == null ? 0 : sy(alis!['a'])),
  ];
}

Widget karZararFaturaFis() => const OzetEkrani(baslik: 'Kar/Zarar (Fatura-Fiş)', veri: _karZararOzet);

Widget genelRapor() => OzetEkrani(baslik: 'Genel Rapor', veri: (b, s) async => [...await _karZararOzet(b, s), ...await _faaliyet(b, s)]);

// ---------------- Yönetim ----------------

Future<List<MapEntry<String, Object?>>> genelDurumVeri(String b, String s) async {
  final c = await DB.tek('''SELECT SUM(CASE WHEN bk>0 THEN bk ELSE 0 END) alacak, SUM(CASE WHEN bk<0 THEN -bk ELSE 0 END) borc
      FROM (SELECT SUM(borc-alacak) bk FROM cari_hareket WHERE tarih<=? GROUP BY cari_id)''', [s]);
  final h = await DB.q('SELECT h.tip, IFNULL(SUM(f.giris-f.cikis),0) b FROM hesap h LEFT JOIN finans_hareket f ON f.hesap_id=h.id AND f.tarih<=? GROUP BY h.tip', [s]);
  double kasa = 0, banka = 0;
  for (final x in h) {
    if (x['tip'] == 'kasa') kasa = sy(x['b']); else banka = sy(x['b']);
  }
  final cek = await DB.tek("SELECT SUM(CASE WHEN yon='Alınan' THEN tutar ELSE 0 END) a, SUM(CASE WHEN yon='Verilen' THEN tutar ELSE 0 END) v FROM cek_senet WHERE durum='Portföyde'");
  final stok = await DB.tek('''SELECT SUM(st*m) d FROM (SELECT IFNULL((SELECT SUM(giris-cikis) FROM stok_hareket WHERE urun_id=u.id),0) st,
      IFNULL((SELECT SUM(giris*fiyat)/NULLIF(SUM(giris),0) FROM stok_hareket WHERE urun_id=u.id AND giris>0 AND tur IN ($maliyetTurleri)), u.alis_fiyat) m FROM urun u) WHERE st>0''');
  final alacak = sy(c?['alacak']), borc = sy(c?['borc']), ca = sy(cek?['a']), cv = sy(cek?['v']), sd = sy(stok?['d']);
  return [
    const MapEntry('Varlıklar', null),
    MapEntry('Kasa', kasa),
    MapEntry('Banka', banka),
    MapEntry('Müşteri alacakları (cari)', alacak),
    MapEntry('Portföydeki çek/senet', ca),
    MapEntry('Stok değeri (maliyetle)', sd),
    const MapEntry('Borçlar', null),
    MapEntry('Tedarikçi / kurum borçları (cari)', -borc),
    MapEntry('Ödenmemiş verilen çek/senet', -cv),
    const MapEntry('Sonuç', null),
    MapEntry('NET VARLIK', kasa + banka + alacak + ca + sd - borc - cv),
  ];
}

Widget genelDurum() => const OzetEkrani(baslik: 'Genel Durum Raporu', veri: genelDurumVeri, tarihli: false);

Future<List<MapEntry<String, Object?>>> _faaliyet(String b, String s) async {
  final r = await DB.q('SELECT tur, COUNT(*) n, SUM(genel_toplam) t FROM belge WHERE tarih BETWEEN ? AND ? GROUP BY tur', [b, s]);
  final f = await DB.q('SELECT tur, SUM(giris) g, SUM(cikis) c FROM finans_hareket WHERE tarih BETWEEN ? AND ? GROUP BY tur', [b, s]);
  return [
    const MapEntry('Belgeler (adet / KDV dahil tutar)', null),
    ...r.map((x) => MapEntry('${turlar[x['tur']]?.ad ?? x['tur']} (${x['n']})', sy(x['t']))),
    const MapEntry('Kasa / Banka hareketleri', null),
    ...f.map((x) => MapEntry('${x['tur']}', sy(x['g']) - sy(x['c']))),
  ];
}

Widget faaliyetRaporu() => const OzetEkrani(baslik: 'Faaliyet Raporu', veri: _faaliyet);

Widget nakitAkis({bool detay = false}) => RaporEkrani(
      baslik: detay ? 'Nakit Akış (Detaylı) Raporu' : 'Nakit Akış Raporu',
      kolonlar: detay
          ? const [Kolon('tarih', 'Tarih', tarih: true), Kolon('kaynak', 'Kaynak'), Kolon('aciklama', 'Açıklama'), Kolon('giris', 'Giriş', para: true), Kolon('cikis', 'Çıkış', para: true)]
          : const [Kolon('ay', 'Ay'), Kolon('giris', 'Giriş', para: true), Kolon('cikis', 'Çıkış', para: true), Kolon('net', 'Net', para: true)],
      veri: (b, s) async {
        const icTransfer = "'Para Yatırma','Para Çekme','Hesap Virman','Kasa Virman'";
        if (!detay) {
          return DB.q('''SELECT substr(tarih,1,7) ay, SUM(giris) giris, SUM(cikis) cikis, SUM(giris-cikis) net FROM finans_hareket
              WHERE tur NOT IN ($icTransfer) AND tarih BETWEEN ? AND ? GROUP BY ay ORDER BY ay''', [b, s]);
        }
        final gercek = await DB.q('''SELECT f.tarih, h.ad || ' / ' || f.tur kaynak, IFNULL(c.unvan,'') || ' ' || IFNULL(f.aciklama,'') aciklama, f.giris, f.cikis
            FROM finans_hareket f JOIN hesap h ON h.id=f.hesap_id LEFT JOIN cari c ON c.id=f.cari_id WHERE f.tur NOT IN ($icTransfer) AND f.tarih BETWEEN ? AND ?''', [b, s]);
        final beklenen = await DB.q('''SELECT k.vade tarih, 'Beklenen ' || k.yon || ' ' || k.tur kaynak, IFNULL(c.unvan,'') || ' ' || IFNULL(k.no,'') aciklama,
            CASE WHEN yon='Alınan' THEN tutar ELSE 0 END giris, CASE WHEN yon='Verilen' THEN tutar ELSE 0 END cikis
            FROM cek_senet k LEFT JOIN cari c ON c.id=k.cari_id WHERE durum='Portföyde' AND vade>=?''', [bugun()]);
        final vadeli = await DB.q('''SELECT b.vade tarih, 'Fatura vadesi' kaynak, IFNULL(c.unvan,'') || ' ' || b.no aciklama,
            CASE WHEN b.tur IN ('satis_fatura') THEN b.genel_toplam ELSE 0 END giris, CASE WHEN b.tur IN ('alis_fatura') THEN b.genel_toplam ELSE 0 END cikis
            FROM belge b LEFT JOIN cari c ON c.id=b.cari_id WHERE b.vade>=? AND b.odeme='acik' AND b.tur IN ('satis_fatura','alis_fatura')''', [bugun()]);
        final t = [...gercek, ...beklenen, ...vadeli];
        t.sort((x, y) => '${y['tarih']}'.compareTo('${x['tarih']}'));
        return t;
      },
    );

Widget enCok(bool musteri) => RaporEkrani(
      baslik: musteri ? 'En Çok Satış Yapılan 20 Müşteri' : 'En Çok Satış Yapılan 20 Ürün',
      kolonlar: musteri
          ? const [Kolon('ad', 'Müşteri'), Kolon('belge', 'Belge', sayi: true), Kolon('satis', 'Satış (KDV hariç)', para: true)]
          : const [Kolon('ad', 'Ürün / Hizmet'), Kolon('miktar', 'Miktar', sayi: true), Kolon('satis', 'Satış (KDV hariç)', para: true)],
      veri: (b, s) => musteri
          ? DB.q('''SELECT c.unvan ad, COUNT(DISTINCT x.belge_id) belge, SUM(x.sg*x.tutar) satis FROM ($_satisSql) x JOIN cari c ON c.id=x.cari_id
              GROUP BY x.cari_id ORDER BY satis DESC LIMIT 20''', [b, s])
          : DB.q('''SELECT IFNULL(u.ad, x.aciklama) ad, SUM(x.sg*x.miktar) miktar, SUM(x.sg*x.tutar) satis FROM ($_satisSql) x LEFT JOIN urun u ON u.id=x.urun_id
              GROUP BY IFNULL(CAST(x.urun_id AS TEXT), x.aciklama) ORDER BY satis DESC LIMIT 20''', [b, s]),
    );
