import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Yerel SQLite veritabanı. Tüm veriler telefonda tutulur.
class DB {
  static Database? _db;

  static Future<Database> get db async => _db ??= await _ac();

  static Future<Database> _ac() async {
    final yol = p.join(await getDatabasesPath(), 'on_muhasebe.db');
    return openDatabase(
      yol,
      version: surum,
      onCreate: (d, v) async {
        for (final s in _sema) {
          await d.execute(s);
        }
        await _baslangic(d);
        await _ekTablolar(d);
      },
      onUpgrade: (d, eski, yeni) => _ekTablolar(d),
      // Daha yeni bir sürümden geri dönülürse veriyi silme, olduğu gibi kullan.
      onDowngrade: (d, eski, yeni) => _ekTablolar(d),
      onOpen: _ekTablolar,
    );
  }

  /// Veritabanı şema sürümü. 1.0.10'dan üst üste kurulumda tablolar korunur,
  /// eksik olanlar (_ekTablolar) eklenir.
  static const surum = 20;

  /// Bulutla eşitlenen tablolar ve anahtar sütunları.
  static const esitlenen = <String, String>{
    'sirket': 'id', 'cari': 'id', 'cari_hareket': 'id', 'depo': 'id', 'urun': 'id',
    'stok_hareket': 'id', 'recete': 'id', 'recete_kalem': 'id', 'uretim_emri': 'id',
    'belge': 'id', 'belge_satir': 'id', 'hesap': 'id', 'finans_hareket': 'id',
    'cek_senet': 'id', 'portal': 'id', 'serbest_tablo': 'id', 'notlar': 'id',
    'aktarim_hash': 'h', 'wa_mesaj': 'anahtar',
  };

  /// 1.0.0 sonrası eklenen tablolar (ayar, değişiklik kaydı, WhatsApp mesajları)
  /// ve değişiklikleri yakalayan tetikleyiciler. Her açılışta güvenle çalışır.
  static Future<void> _ekTablolar(Database d) async {
    await d.execute('CREATE TABLE IF NOT EXISTS ayar(k TEXT PRIMARY KEY, v TEXT)');
    await d.execute('CREATE TABLE IF NOT EXISTS degisiklik(id INTEGER PRIMARY KEY AUTOINCREMENT, tablo TEXT, kayit_id INTEGER, sil INTEGER DEFAULT 0)');
    try {
      await d.execute('ALTER TABLE degisiklik ADD COLUMN anahtar TEXT');
    } catch (_) {/* sütun zaten var */}
    await d.execute('UPDATE degisiklik SET anahtar=CAST(kayit_id AS TEXT) WHERE anahtar IS NULL AND kayit_id IS NOT NULL');
    await d.execute('CREATE TABLE IF NOT EXISTS wa_mesaj(anahtar TEXT PRIMARY KEY, sohbet TEXT, kisi TEXT, metin TEXT, zaman INTEGER)');
    // Tetikleyiciler sadece giriş yapılmışken (ayar esitle=1) kayıt tutar.
    const kosul = "(SELECT v FROM ayar WHERE k='esitle')='1'";
    for (final e in esitlenen.entries) {
      final t = e.key, k = e.value;
      final idMi = k == 'id';
      String ekle(String kaynak, int sil) =>
          "INSERT INTO degisiklik(tablo, kayit_id, anahtar, sil) VALUES('$t', ${idMi ? '$kaynak.id' : 'NULL'}, CAST($kaynak.$k AS TEXT), $sil);";
      await d.execute('CREATE TRIGGER IF NOT EXISTS es_${t}_i AFTER INSERT ON $t WHEN $kosul BEGIN ${ekle('NEW', 0)} END');
      await d.execute('CREATE TRIGGER IF NOT EXISTS es_${t}_u AFTER UPDATE ON $t WHEN $kosul BEGIN ${ekle('NEW', 0)} END');
      await d.execute('CREATE TRIGGER IF NOT EXISTS es_${t}_d AFTER DELETE ON $t WHEN $kosul BEGIN ${ekle('OLD', 1)} END');
    }
  }

  static Future<String?> ayarAl(String k) async {
    final r = await tek('SELECT v FROM ayar WHERE k=?', [k]);
    return r?['v'] as String?;
  }

  static Future<void> ayarYaz(String k, String? v) async {
    final d = await db;
    if (v == null) {
      await d.delete('ayar', where: 'k=?', whereArgs: [k]);
    } else {
      await d.insert('ayar', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static const _sema = [
    '''CREATE TABLE sirket(id INTEGER PRIMARY KEY, kod TEXT, unvan TEXT, adres TEXT, adres2 TEXT,
      tel TEXT, faks TEXT, gsm TEXT, vergi_dairesi TEXT, vergi_no TEXT, web TEXT, email TEXT,
      banka TEXT, sube TEXT, sube_kodu TEXT, hesap_no TEXT, notlar TEXT)''',
    '''CREATE TABLE cari(id INTEGER PRIMARY KEY AUTOINCREMENT, kod TEXT, unvan TEXT NOT NULL,
      tip TEXT DEFAULT 'Müşteri', tel TEXT, email TEXT, adres TEXT, vergi_dairesi TEXT,
      vergi_no TEXT, notlar TEXT)''',
    '''CREATE TABLE cari_hareket(id INTEGER PRIMARY KEY AUTOINCREMENT, cari_id INTEGER, tarih TEXT,
      tur TEXT, aciklama TEXT, borc REAL DEFAULT 0, alacak REAL DEFAULT 0, belge_id INTEGER,
      grup TEXT, kaynak TEXT)''',
    'CREATE TABLE depo(id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT)',
    '''CREATE TABLE urun(id INTEGER PRIMARY KEY AUTOINCREMENT, kod TEXT, ad TEXT NOT NULL,
      barkod TEXT, grup TEXT, birim TEXT DEFAULT 'Adet', kdv REAL DEFAULT 20,
      alis_fiyat REAL DEFAULT 0, satis_fiyat REAL DEFAULT 0, kritik REAL DEFAULT 0)''',
    '''CREATE TABLE stok_hareket(id INTEGER PRIMARY KEY AUTOINCREMENT, urun_id INTEGER, depo_id INTEGER,
      tarih TEXT, tur TEXT, giris REAL DEFAULT 0, cikis REAL DEFAULT 0, fiyat REAL DEFAULT 0,
      belge_id INTEGER, grup TEXT, aciklama TEXT)''',
    'CREATE TABLE recete(id INTEGER PRIMARY KEY AUTOINCREMENT, urun_id INTEGER, ad TEXT, miktar REAL DEFAULT 1)',
    'CREATE TABLE recete_kalem(id INTEGER PRIMARY KEY AUTOINCREMENT, recete_id INTEGER, urun_id INTEGER, miktar REAL)',
    '''CREATE TABLE uretim_emri(id INTEGER PRIMARY KEY AUTOINCREMENT, recete_id INTEGER, tarih TEXT,
      miktar REAL, depo_id INTEGER, durum TEXT DEFAULT 'Bekliyor', aciklama TEXT)''',
    '''CREATE TABLE belge(id INTEGER PRIMARY KEY AUTOINCREMENT, tur TEXT, no TEXT, tarih TEXT, vade TEXT,
      cari_id INTEGER, depo_id INTEGER, hedef_depo_id INTEGER, aciklama TEXT, ara_toplam REAL DEFAULT 0,
      iskonto REAL DEFAULT 0, kdv_toplam REAL DEFAULT 0, genel_toplam REAL DEFAULT 0,
      odeme TEXT DEFAULT 'acik', hesap_id INTEGER, stok_etkisiz INTEGER DEFAULT 0,
      durum TEXT DEFAULT 'Açık', kaynak_id INTEGER, grup TEXT, kaynak TEXT)''',
    '''CREATE TABLE belge_satir(id INTEGER PRIMARY KEY AUTOINCREMENT, belge_id INTEGER, urun_id INTEGER,
      aciklama TEXT, miktar REAL, birim TEXT, fiyat REAL, kdv REAL, iskonto REAL DEFAULT 0, tutar REAL)''',
    // tip: kasa | banka
    'CREATE TABLE hesap(id INTEGER PRIMARY KEY AUTOINCREMENT, tip TEXT, ad TEXT, sube TEXT, iban TEXT)',
    '''CREATE TABLE finans_hareket(id INTEGER PRIMARY KEY AUTOINCREMENT, hesap_id INTEGER, tarih TEXT,
      tur TEXT, cari_id INTEGER, kategori TEXT, aciklama TEXT, giris REAL DEFAULT 0, cikis REAL DEFAULT 0,
      grup TEXT, kaynak TEXT)''',
    '''CREATE TABLE cek_senet(id INTEGER PRIMARY KEY AUTOINCREMENT, tur TEXT, yon TEXT, no TEXT,
      cari_id INTEGER, banka TEXT, tarih TEXT, vade TEXT, tutar REAL, durum TEXT DEFAULT 'Portföyde',
      aciklama TEXT, grup TEXT, durum_grup TEXT)''',
    'CREATE TABLE portal(id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT, url TEXT, kategori TEXT, notlar TEXT, otomatik TEXT)',
    'CREATE TABLE aktarim_hash(h TEXT PRIMARY KEY)',
    'CREATE TABLE serbest_tablo(id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT, kaynak TEXT, tarih TEXT, veri TEXT)',
    'CREATE TABLE notlar(id INTEGER PRIMARY KEY AUTOINCREMENT, tarih TEXT, kaynak TEXT, kisi TEXT, metin TEXT)',
    'CREATE INDEX ix_ch ON cari_hareket(cari_id)',
    'CREATE INDEX ix_sh ON stok_hareket(urun_id)',
    'CREATE INDEX ix_fh ON finans_hareket(hesap_id)',
    'CREATE INDEX ix_bs ON belge_satir(belge_id)',
  ];

  static Future<void> _baslangic(Database d) async {
    // Vergi no, GSM, e-posta gibi bilgiler kaynak koda yazılmaz; uygulamada Şirket Bilgisi'nden girilir.
    await d.insert('sirket', {
      'id': 1,
      'kod': 'TİCARİ',
      'unvan': 'KONES MÜHENDİSLİK',
      'adres': 'KONYA',
      'adres2': 'KARATAY',
      'vergi_dairesi': 'MEVLANA',
    });
    await d.insert('depo', {'ad': 'Merkez Depo'});
    await d.insert('hesap', {'tip': 'kasa', 'ad': 'Merkez Kasa'});
    const portallar = [
      ['e-Devlet', 'https://www.turkiye.gov.tr', 'Kamu'],
      ['GİB Dijital Vergi Dairesi', 'https://dijital.gib.gov.tr', 'Gelir İdaresi'],
      ['GİB e-Arşiv Portal', 'https://earsivportal.efatura.gov.tr', 'Gelir İdaresi'],
      ['Trafik Cezası Sorgulama', 'https://www.turkiye.gov.tr/emniyet-arac-plakasina-yazilan-ceza-sorgulama', 'Kamu'],
      ['SGK e-Bildirge (İşveren)', 'https://ebildirge.sgk.gov.tr', 'SGK'],
      ['SGK / Bağ-Kur Borç Sorgu (e-Devlet)', 'https://www.turkiye.gov.tr/sosyal-guvenlik-kurumu', 'SGK'],
      ['Enerya Firma Portalı', '', 'Doğalgaz'],
      ['Gasline - Prizma A.Ş.', '', 'Doğalgaz'],
      ['DİPOS IV', '', 'Doğalgaz'],
    ];
    for (final x in portallar) {
      await d.insert('portal', {'ad': x[0], 'url': x[1], 'kategori': x[2]});
    }
  }

  static Future<List<Map<String, Object?>>> q(String sql, [List<Object?>? a]) async =>
      (await db).rawQuery(sql, a);

  static Future<Map<String, Object?>?> tek(String sql, [List<Object?>? a]) async {
    final r = await q(sql, a);
    return r.isEmpty ? null : r.first;
  }

  static Future<int> ekle(String t, Map<String, Object?> m) async => (await db).insert(t, idli(m));

  static int _sonId = 0;

  /// Telefonlar arasında çakışmayan kayıt numarası (zamana dayalı).
  /// Birden çok telefon aynı anda kayıt girse de aynı numara oluşmaz.
  static int yeniId() {
    final n = DateTime.now().microsecondsSinceEpoch;
    _sonId = n > _sonId ? n : _sonId + 1;
    return _sonId;
  }

  /// Haritada id yoksa yeni bir id ekler.
  static Map<String, Object?> idli(Map<String, Object?> m) => m['id'] == null ? {...m, 'id': yeniId()} : m;

  static Future<int> guncelle(String t, Map<String, Object?> m, int id) async =>
      (await db).update(t, m, where: 'id=?', whereArgs: [id]);

  static Future<int> sil(String t, int id) async => (await db).delete(t, where: 'id=?', whereArgs: [id]);

  static final _r = Random();
  static String yeniGrup() =>
      '${DateTime.now().microsecondsSinceEpoch}${_r.nextInt(99999).toString().padLeft(5, '0')}';

  /// Aynı işlemden doğan tüm hareketleri (cari, stok, kasa/banka) ve bağlı belgeyi siler.
  static Future<void> grupSilTx(DatabaseExecutor tx, String grup, {bool belgeDahil = false}) async {
    for (final t in ['cari_hareket', 'stok_hareket', 'finans_hareket']) {
      await tx.delete(t, where: 'grup=?', whereArgs: [grup]);
    }
    if (belgeDahil) {
      final b = await tx.query('belge', columns: ['id'], where: 'grup=?', whereArgs: [grup]);
      for (final x in b) {
        await tx.delete('belge_satir', where: 'belge_id=?', whereArgs: [x['id']]);
      }
      await tx.delete('belge', where: 'grup=?', whereArgs: [grup]);
      await tx.update('cek_senet', {'durum_grup': null, 'durum': 'Portföyde'},
          where: 'durum_grup=?', whereArgs: [grup]);
      await tx.delete('cek_senet', where: 'grup=?', whereArgs: [grup]);
    }
  }

  static Future<void> grupSil(String grup) async {
    final d = await db;
    await d.transaction((tx) => grupSilTx(tx, grup, belgeDahil: true));
  }
}
