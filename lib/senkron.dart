import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'firebase_ayar.dart';

/// Telefonlar arası bulut eşitleme (Firebase Firestore).
///
/// * Veriler her zaman telefondaki SQLite'ta durur; uygulama internetsiz de çalışır.
/// * Giriş yapılmışken her ekleme/güncelleme/silme `degisiklik` tablosuna yazılır (DB.ins/upd/del)
///   ve sırayla buluta gönderilir.
/// * Diğer telefonların kayıtları dinlenir ve bu telefona işlenir.
/// * Bulutta yol: firmalar/{firma}/tablolar/{tablo}/kayitlar/{id}
///   Belge = kaydın sütunları + `_ts` (sunucu zamanı) + silinmişse `_sil`.
class Senkron {
  static const firma = 'kones';

  /// kapali, cevrimdisi, bagli, gonderiyor, hata
  static final durum = ValueNotifier<String>('kapali');

  /// Başka telefondan veri geldiğinde artar (ekranlar yenilenir).
  static final degisti = ValueNotifier<int>(0);

  static bool acik = false;
  static final List<StreamSubscription> _abonelik = [];
  static Timer? _zaman;
  static bool _gonderiyor = false;

  static FirebaseFirestore get _fs => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _kayitlar(String tablo) =>
      _fs.collection('firmalar').doc(firma).collection('tablolar').doc(tablo).collection('kayitlar');

  static User? get kullanici => acik ? FirebaseAuth.instance.currentUser : null;

  static Future<void> firebaseBaslat() async {
    try {
      await Firebase.initializeApp(options: firebaseAyar);
      acik = true;
    } catch (_) {
      acik = false;
    }
  }

  /// Girişten sonra eşitlemeyi başlatır.
  static String? _uid;

  static Future<void> baslat() async {
    final u = kullanici;
    if (u == null || _uid == u.uid) return;
    _uid = u.uid;
    DB.kayitTut = true;
    durum.value = 'bagli';
    await oku();
    _zaman?.cancel();
    _zaman = Timer.periodic(const Duration(seconds: 30), (_) => gonder());
    unawaited(gonder());
  }

  /// Çıkışta eşitlemeyi durdurur. Veriler telefonda kalır.
  static Future<void> durdur() async {
    for (final a in _abonelik) {
      await a.cancel();
    }
    _abonelik.clear();
    _zaman?.cancel();
    _zaman = null;
    _uid = null;
    DB.kayitTut = false;
    durum.value = 'kapali';
  }

  static Future<int> bekleyenSayisi() async {
    final r = await DB.tek('SELECT COUNT(*) n FROM degisiklik');
    return (r?['n'] as int?) ?? 0;
  }

  static Future<List<String>> _tablolar() async => (await DB.q(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name<>'android_metadata'"))
      .map((r) => '${r['name']}')
      .where((t) => !DB.esitlenmez.contains(t))
      .toList();

  /// Sıradaki değişiklikleri gönderir. [zorla] true ise bu telefondaki tüm kayıtlar önce sıraya alınır
  /// (girişten önce girilmiş ve buluta gitmemiş kayıtlar için). Gönderilen kayıt sayısını döner.
  static Future<int> gonder({bool zorla = false}) async {
    if (kullanici == null) return 0;
    final d = await DB.db;
    if (zorla) {
      await d.transaction((tx) async {
        for (final t in await _tablolar()) {
          await tx.rawInsert('INSERT INTO degisiklik(tablo, kayit_id, sil) SELECT ?, id, 0 FROM $t', [t]);
        }
      });
    }
    if (_gonderiyor) return 0;
    _gonderiyor = true;
    var n = 0;
    try {
      while (true) {
        final l = await d.rawQuery('SELECT * FROM degisiklik ORDER BY id LIMIT 400');
        if (l.isEmpty) break;
        durum.value = 'gonderiyor';
        final batch = _fs.batch();
        final son = <String, Map<String, Object?>>{};
        for (final x in l) {
          son['${x['tablo']}/${x['kayit_id']}'] = x;
        }
        for (final x in son.values) {
          final t = '${x['tablo']}';
          final id = x['kayit_id'];
          final ref = _kayitlar(t).doc('$id');
          final r = x['sil'] == 1 ? null : await DB.tek('SELECT * FROM $t WHERE id=?', [id]);
          if (r == null) {
            batch.set(ref, {'id': id, '_sil': true, '_ts': FieldValue.serverTimestamp()});
          } else {
            batch.set(ref, {...r, '_ts': FieldValue.serverTimestamp()});
          }
        }
        await batch.commit().timeout(const Duration(seconds: 60));
        await d.delete('degisiklik', where: 'id<=?', whereArgs: [l.last['id']]);
        n += son.length;
      }
      durum.value = 'bagli';
    } on TimeoutException {
      durum.value = 'cevrimdisi';
    } catch (_) {
      durum.value = 'hata';
      rethrow;
    } finally {
      _gonderiyor = false;
    }
    return n;
  }

  /// Her tabloyu dinler; son alınandan sonra değişen kayıtları bu telefona yerleştirir.
  static Future<void> oku() async {
    for (final a in _abonelik) {
      await a.cancel();
    }
    _abonelik.clear();
    for (final t in await _tablolar()) {
      final son = int.tryParse(await DB.ayarOku('son_$t') ?? '') ?? 0;
      _abonelik.add(_kayitlar(t)
          .where('_ts', isGreaterThan: Timestamp.fromDate(DateTime.fromMicrosecondsSinceEpoch(son)))
          .orderBy('_ts')
          .snapshots()
          .listen((s) => yerlestir(t, s), onError: (_) => durum.value = 'hata'));
    }
  }

  static Future<void> yerlestir(String t, QuerySnapshot<Map<String, dynamic>> s) async {
    final belgeler = s.docChanges
        .where((c) => c.type != DocumentChangeType.removed && !c.doc.metadata.hasPendingWrites)
        .map((c) => c.doc.data())
        .whereType<Map<String, dynamic>>()
        .where((x) => x['_ts'] is Timestamp)
        .toList();
    if (belgeler.isEmpty) return;
    final d = await DB.db;
    final kolonlar = (await d.rawQuery('PRAGMA table_info($t)')).map((r) => '${r['name']}').toSet();
    var enSon = 0;
    await d.transaction((tx) async {
      for (final x in belgeler) {
        final z = (x['_ts'] as Timestamp).toDate().microsecondsSinceEpoch;
        if (z > enSon) enSon = z;
        final id = x['id'];
        if (id is! int) continue;
        // Bu telefonda henüz gönderilmemiş bir değişiklik varsa o kazanır.
        final bek = await tx.query('degisiklik', where: 'tablo=? AND kayit_id=?', whereArgs: [t, id]);
        if (bek.isNotEmpty) continue;
        if (x['_sil'] == true) {
          await tx.delete(t, where: 'id=?', whereArgs: [id]);
        } else {
          final v = Map<String, Object?>.from(x)..removeWhere((k, _) => !kolonlar.contains(k));
          await tx.insert(t, v, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (enSon > 0) {
        await tx.insert('ayar', {'k': 'son_$t', 'v': '$enSon'}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    degisti.value++;
  }
}
