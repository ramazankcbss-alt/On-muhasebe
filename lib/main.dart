import 'package:flutter/material.dart';

import 'db.dart';
import 'giris.dart';
import 'menu.dart';
import 'senkron.dart';
import 'wa_bildirim.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OnMuhasebeApp());
}

class OnMuhasebeApp extends StatefulWidget {
  const OnMuhasebeApp({super.key});
  @override
  State<OnMuhasebeApp> createState() => _OnMuhasebeAppState();
}

class _OnMuhasebeAppState extends State<OnMuhasebeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      Senkron.gonder();
      WaBildirim.topla();
    } else if (s == AppLifecycleState.paused) {
      Senkron.gonder();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ön Muhasebe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF00897B),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
        ),
        home: const _Acilis(),
      );
}

/// Firebase'i başlatır; giriş yapılmamışsa ve "girişsiz devam" seçilmemişse giriş ekranını gösterir.
class _Acilis extends StatefulWidget {
  const _Acilis();
  @override
  State<_Acilis> createState() => _AcilisState();
}

class _AcilisState extends State<_Acilis> {
  @override
  void initState() {
    super.initState();
    _basla();
  }

  Future<void> _basla() async {
    await DB.db;
    await Senkron.firebaseBaslat();
    WaBildirim.topla();
    final girissiz = await DB.ayarAl('girissiz') == '1';
    if (!mounted) return;
    final girisGerek = Senkron.kurulu && Senkron.kullanici == null && !girissiz;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => girisGerek ? const GirisEkrani() : const AnaMenu()));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
