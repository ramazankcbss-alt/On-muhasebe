import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'firebase_ayar.dart';
import 'giris.dart';
import 'guncelleme.dart';
import 'ortak.dart';

/// Telefonlar arası bulut eşitleme (Firebase Firestore).
///
/// Çalışma şekli:
/// * Veriler her zaman telefondaki SQLite'ta durur; uygulama internetsiz de çalışır.
/// * Giriş yapılmışken her ekleme/değişiklik/silme, tetikleyicilerle `degisiklik`
///   tablosuna yazılır ve sırayla buluta gönderilir.
/// * Diğer telefonların gönderdikleri dinlenir ve bu telefona işlenir.
/// * Bulutta yol: sirketler/kones/kayitlar/{tablo}~{anahtar}
class Senkron {
  static bool kurulu = false;
  static final durum = ValueNotifier<String>('');
  static final bekleyen = ValueNotifier<int>(0);

  static StreamSubscription? _dinleyici;
  static Timer? _zamanlayici;
  static bool _gonderiyor = false;
  static String _cihaz = '';
  static final Map<String, Set<String>> _sutunlar = {};

  static CollectionReference<Map<String, dynamic>> get _kayitlar =>
      FirebaseFirestore.instance.collection('sirketler').doc('kones').collection('kayitlar');

  static User? get kullanici => kurulu ? FirebaseAuth.instance.currentUser : null;

  /// Uygulama açılırken bir kez çağrılır.
  static Future<void> firebaseBaslat() async {
    try {
      await Firebase.initializeApp(options: firebaseAyar);
      kurulu = true;
    } catch (e) {
      kurulu = false;
      durum.value = 'Bulut eşitleme kurulmamış';
    }
    _cihaz = await DB.ayarAl('cihaz') ?? '';
    if (_cihaz.isEmpty) {
      final r = Random.secure();
      _cihaz = List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
      await DB.ayarYaz('cihaz', _cihaz);
    }
    if (kullanici != null) {
      await basla();
    } else if (kurulu) {
      durum.value = 'Giriş yapılmadı (veriler sadece bu telefonda)';
    }
  }

  /// Girişten sonra eşitlemeyi başlatır.
  static Future<void> basla() async {
    if (kullanici == null) return;
    await DB.ayarYaz('esitle', '1');
    await DB.ayarYaz('girissiz', null);
    durum.value = 'Bağlı, veriler eşitleniyor';
    _dinle();
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 30), (_) => gonder());
    unawaited(gonder());
  }

  /// Çıkışta eşitlemeyi durdurur. Veriler telefonda kalır.
  static Future<void> durdur() async {
    await _dinleyici?.cancel();
    _dinleyici = null;
    _zamanlayici?.cancel();
    _zamanlayici = null;
    await DB.ayarYaz('esitle', null);
    final d = await DB.db;
    await d.delete('degisiklik');
    bekleyen.value = 0;
    if (kurulu) await FirebaseAuth.instance.signOut();
    durum.value = 'Giriş yapılmadı (veriler sadece bu telefonda)';
  }

  // ---------------- Gönderme ----------------

  static Future<int> bekleyenSay() async {
    final r = await DB.tek('SELECT COUNT(*) n FROM degisiklik');
    bekleyen.value = (r?['n'] as int?) ?? 0;
    return bekleyen.value;
  }

  /// Sıradaki değişiklikleri buluta gönderir. Gönderilen kayıt sayısını döner.
  static Future<int> gonder() async {
    if (kullanici == null || _gonderiyor) return 0;
    _gonderiyor = true;
    var toplam = 0;
    try {
      final d = await DB.db;
      while (true) {
        final l = await d.rawQuery('SELECT * FROM degisiklik ORDER BY id LIMIT 400');
        if (l.isEmpty) break;
        // Aynı kayda ait birden çok değişiklikten sadece son durumu gönder.
        final son = <String, Map<String, Object?>>{};
        for (final x in l) {
          final a = '${x['anahtar'] ?? x['kayit_id']}';
          son['${x['tablo']}~$a'] = {...x, 'anahtar': a};
        }
        final batch = FirebaseFirestore.instance.batch();
        for (final e in son.entries) {
          final t = '${e.value['tablo']}';
          final k = DB.esitlenen[t];
          if (k == null) continue;
          final a = '${e.value['anahtar']}';
          final r = await d.query(t, where: '$k=?', whereArgs: [k == 'id' ? int.tryParse(a) ?? a : a]);
          final v = r.isEmpty ? null : r.first;
          if (v != null && jsonEncode(v).length > 900000) continue; // Firestore belge sınırı (1 MB)
          batch.set(_kayitlar.doc(_belgeAdi(t, a)), {
            't': t,
            'a': a,
            'v': v,
            'sil': v == null,
            'z': FieldValue.serverTimestamp(),
            'c': _cihaz,
            'u': kullanici?.email,
          });
        }
        await batch.commit().timeout(const Duration(seconds: 60));
        final ids = l.map((x) => x['id']).join(',');
        await d.rawDelete('DELETE FROM degisiklik WHERE id IN ($ids)');
        toplam += son.length;
      }
      durum.value = 'Bağlı, veriler eşitleniyor';
    } on TimeoutException {
      durum.value = 'İnternet bağlantısı yok';
    } catch (e) {
      durum.value = 'Eşitleme hatası: $e';
    } finally {
      _gonderiyor = false;
      await bekleyenSay();
    }
    return toplam;
  }

  /// Bu telefondaki tüm kayıtları gönderim sırasına koyar
  /// (girişten önce girilmiş ve buluta gitmemiş kayıtlar için).
  static Future<int> hepsiniGonder() async {
    final d = await DB.db;
    await d.transaction((tx) async {
      for (final e in DB.esitlenen.entries) {
        final idMi = e.value == 'id';
        await tx.rawInsert(
            "INSERT INTO degisiklik(tablo, kayit_id, anahtar, sil) SELECT '${e.key}', ${idMi ? 'id' : 'NULL'}, CAST(${e.value} AS TEXT), 0 FROM ${e.key}");
      }
    });
    await bekleyenSay();
    unawaited(gonder());
    return bekleyen.value;
  }

  // ---------------- Alma ----------------

  static void _dinle() {
    _dinleyici?.cancel();
    () async {
      final son = int.tryParse(await DB.ayarAl('son_alinan') ?? '') ?? 0;
      _dinleyici = _kayitlar
          .where('z', isGreaterThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(son))
          .orderBy('z')
          .snapshots()
          .listen(_isle, onError: (e) => durum.value = 'Eşitleme hatası: $e');
    }();
  }

  static Future<void> _isle(QuerySnapshot<Map<String, dynamic>> s) async {
    final degisen = s.docChanges
        .where((c) => c.type != DocumentChangeType.removed)
        .map((c) => c.doc.data())
        .whereType<Map<String, dynamic>>()
        .where((x) => x['z'] is Timestamp && x['c'] != _cihaz)
        .toList();
    if (degisen.isEmpty) return;
    final d = await DB.db;
    var enSon = 0;
    await d.transaction((tx) async {
      await tx.insert('ayar', {'k': 'esitle', 'v': '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final x in degisen) {
        final t = '${x['t']}';
        final k = DB.esitlenen[t];
        final z = (x['z'] as Timestamp).millisecondsSinceEpoch;
        if (z > enSon) enSon = z;
        if (k == null) continue;
        final a = '${x['a']}';
        // Bu telefonda henüz gönderilmemiş bir değişiklik varsa o kazanır.
        final bek = await tx.rawQuery('SELECT 1 FROM degisiklik WHERE tablo=? AND anahtar=? LIMIT 1', [t, a]);
        if (bek.isNotEmpty) continue;
        final anahtar = k == 'id' ? int.tryParse(a) ?? a : a;
        if (x['sil'] == true || x['v'] == null) {
          await tx.delete(t, where: '$k=?', whereArgs: [anahtar]);
        } else {
          final sutun = await _sutunlarAl(tx, t);
          final v = Map<String, Object?>.from(x['v'] as Map)..removeWhere((key, _) => !sutun.contains(key));
          await tx.insert(t, v, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await tx.insert('ayar', {'k': 'esitle', 'v': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
      if (enSon > 0) {
        await tx.insert('ayar', {'k': 'son_alinan', 'v': '$enSon'}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    yenilendi.value++;
  }

  /// Başka telefondan veri geldiğinde ekranların yenilenmesi için.
  static final yenilendi = ValueNotifier<int>(0);

  static Future<Set<String>> _sutunlarAl(DatabaseExecutor tx, String t) async {
    final v = _sutunlar[t];
    if (v != null) return v;
    final r = await tx.rawQuery('PRAGMA table_info($t)');
    return _sutunlar[t] = r.map((x) => '${x['name']}').toSet();
  }

  static String _belgeAdi(String t, String a) {
    final temiz = a.replaceAll('/', '_');
    final ad = '$t~$temiz';
    return ad.length <= 700 ? ad : '$t~h${a.hashCode.toRadixString(16)}${a.length}';
  }
}

/// "Eşitleme ve Güncelleme" ekranı
class SenkronEkrani extends StatefulWidget {
  const SenkronEkrani({super.key});
  @override
  State<SenkronEkrani> createState() => _SenkronEkraniState();
}

class _SenkronEkraniState extends State<SenkronEkrani> {
  bool calisiyor = false;
  String surum = '';

  @override
  void initState() {
    super.initState();
    Senkron.bekleyenSay();
    Guncelleme.mevcutSurum().then((v) => mounted ? setState(() => surum = v) : null);
  }

  Future<void> esitle() async {
    setState(() => calisiyor = true);
    final n = await Senkron.gonder();
    if (!mounted) return;
    setState(() => calisiyor = false);
    mesaj(context, n == 0 ? Senkron.durum.value : '$n kayıt gönderildi');
  }

  Future<void> hepsi() async {
    if (!await onay(context,
        'Girişten önce bu telefonda girilmiş kayıtlar buluta gitmediyse bu işlemi kullanın. Bu telefondaki tüm kayıtlar yeniden gönderilir; diğer telefonlardaki kayıtlar silinmez. Devam edilsin mi?')) {
      return;
    }
    final n = await Senkron.hepsiniGonder();
    if (mounted) mesaj(context, '$n kayıt gönderim sırasına alındı');
  }

  Future<void> cikis() async {
    if (!await onay(context, 'Çıkış yapılsın mı? Veriler telefonda kalır.')) return;
    await Senkron.durdur();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GirisEkrani()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = Senkron.kullanici;
    return Scaffold(
      appBar: AppBar(title: const Text('Eşitleme ve Güncelleme')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(u == null ? Icons.cloud_off : Icons.cloud_done, color: u == null ? Colors.grey : Colors.green),
              title: Text(u?.email ?? 'Giriş yapılmadı'),
              subtitle: ValueListenableBuilder<String>(valueListenable: Senkron.durum, builder: (_, v, __) => Text(v)),
            ),
            if (u != null)
              ValueListenableBuilder<int>(
                valueListenable: Senkron.bekleyen,
                builder: (_, n, __) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule_send),
                  title: Text(n == 0 ? 'Gönderilmeyi bekleyen kayıt yok' : '$n değişiklik gönderilmeyi bekliyor'),
                ),
              ),
            const Divider(height: 1),
            if (u != null) ...[
              ListTile(
                leading: calisiyor ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                title: const Text('Şimdi eşitle'),
                onTap: calisiyor ? null : esitle,
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Bu telefondaki tüm verileri yeniden gönder'),
                subtitle: const Text('Girişten önce girilmiş kayıtlar için'),
                onTap: hepsi,
              ),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Çıkış yap'), onTap: cikis),
            ] else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Giriş yap ve verileri paylaş'),
                enabled: Senkron.kurulu,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GirisEkrani(geriDon: true))).then((_) => setState(() {})),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.info_outline), title: const Text('Sürüm'), trailing: Text(surum)),
            ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Güncellemeleri denetle'),
              onTap: () => Guncelleme.denetle(context, sessiz: false),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Kullanıcılar yönetici tarafından eklenir. Aynı hesapla giren tüm telefonlar aynı verileri görür. '
              'İnternet yokken girilen kayıtlar bağlantı gelince gönderilir.',
              style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
