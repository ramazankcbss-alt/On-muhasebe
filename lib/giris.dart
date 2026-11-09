import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'guncelleme.dart';
import 'menu.dart';
import 'ortak.dart';
import 'senkron.dart';

/// Açılış kapısı: oturum açıksa (veya girişsiz kullanım seçildiyse) ana menü, değilse giriş ekranı.
class Kapi extends StatefulWidget {
  const Kapi({super.key});
  @override
  State<Kapi> createState() => _KapiState();
}

class _KapiState extends State<Kapi> with WidgetsBindingObserver {
  bool hazir = false, girissiz = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    () async {
      await DB.db;
      await Senkron.firebaseBaslat();
      girissiz = await DB.ayarOku('giris') == 'yok';
      if (mounted) setState(() => hazir = true);
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed || s == AppLifecycleState.paused) {
      Senkron.gonder().catchError((_) => 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hazir) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!Senkron.acik) return const AnaMenu();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final u = s.data;
        if (u != null) {
          Future.microtask(Senkron.baslat);
          return const AnaMenu();
        }
        Future.microtask(Senkron.durdur);
        return girissiz ? const AnaMenu() : const GirisEkrani();
      },
    );
  }
}

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final eposta = TextEditingController();
  final sifre = TextEditingController();
  bool bekle = false, gizli = true;

  Future<void> giris() async {
    if (eposta.text.trim().isEmpty || sifre.text.isEmpty) return;
    setState(() => bekle = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: eposta.text.trim(), password: sifre.text);
      await DB.ayarYaz('giris', null);
      await Senkron.baslat();
      if (mounted && Navigator.canPop(context)) Navigator.popUntil(context, (r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mesaj(
          context,
          switch (e.code) {
            'invalid-email' => 'E-posta adresi geçersiz',
            'invalid-credential' || 'wrong-password' || 'user-not-found' => 'E-posta veya şifre hatalı',
            'too-many-requests' => 'Çok fazla deneme, biraz sonra tekrar deneyin',
            'network-request-failed' => 'İnternet bağlantısı yok',
            _ => 'Giriş yapılamadı (${e.code})',
          });
    } finally {
      if (mounted) setState(() => bekle = false);
    }
  }

  Future<void> sifreSifirla() async {
    if (eposta.text.trim().isEmpty) return mesaj(context, 'Önce e-posta adresinizi yazın');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: eposta.text.trim());
      if (mounted) mesaj(context, 'Şifre sıfırlama bağlantısı e-postanıza gönderildi');
    } on FirebaseAuthException catch (e) {
      if (mounted) mesaj(context, e.code == 'invalid-email' ? 'E-posta adresi geçersiz' : 'Giriş yapılamadı (${e.code})');
    }
  }

  Future<void> devam() async {
    if (!await onay(context, 'Girişsiz kullanımda veriler sadece bu telefonda kalır, diğer telefonlarla paylaşılmaz. Devam edilsin mi?')) return;
    await DB.ayarYaz('giris', 'yok');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AnaMenu()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: Navigator.canPop(context) ? AppBar(title: const Text('Giriş')) : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.account_balance_wallet, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                const Text('Ön Muhasebe', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Kones Mühendislik', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: eposta,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sifre,
                  obscureText: gizli,
                  onSubmitted: (_) => giris(),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(gizli ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => gizli = !gizli)),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: bekle ? null : giris,
                  icon: bekle ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                  label: const Text('Giriş Yap'),
                ),
                TextButton(onPressed: sifreSifirla, child: const Text('Şifremi unuttum')),
                const Divider(height: 32),
                if (!Navigator.canPop(context))
                  OutlinedButton.icon(onPressed: devam, icon: const Icon(Icons.phone_android), label: const Text('Girişsiz devam et (sadece bu telefon)')),
                const SizedBox(height: 12),
                const Text('Kullanıcılar yönetici tarafından eklenir. Aynı hesapla giren tüm telefonlar aynı verileri görür.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}

/// Eşitleme ve Güncelleme ekranı
class SenkronEkrani extends StatefulWidget {
  const SenkronEkrani({super.key});
  @override
  State<SenkronEkrani> createState() => _SenkronEkraniState();
}

class _SenkronEkraniState extends State<SenkronEkrani> {
  int bekleyen = 0;
  String surum = '';

  @override
  void initState() {
    super.initState();
    yukle();
    Senkron.durum.addListener(yukle);
  }

  @override
  void dispose() {
    Senkron.durum.removeListener(yukle);
    super.dispose();
  }

  Future<void> yukle() async {
    final n = await Senkron.bekleyenSayisi();
    final v = await Guncelleme.mevcut();
    if (mounted) {
      setState(() {
        bekleyen = n;
        surum = v;
      });
    }
  }

  Future<void> esitle({bool zorla = false}) async {
    try {
      await Senkron.gonder(zorla: zorla);
    } catch (e) {
      if (mounted) mesaj(context, 'Gönderilemedi: $e');
    }
    yukle();
  }

  Future<void> hepsi() async {
    try {
      final n = await Senkron.gonder(zorla: true);
      if (mounted) mesaj(context, '$n kayıt gönderim sırasına alındı');
    } catch (e) {
      if (mounted) mesaj(context, 'Gönderilemedi: $e');
    }
    yukle();
  }

  Future<void> cikis() async {
    if (!await onay(context, 'Çıkış yapılsın mı? Veriler telefonda kalır.')) return;
    await Senkron.durdur();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  String metin(String d) => switch (d) {
        'bagli' => 'Bağlı, veriler eşitleniyor',
        'cevrimdisi' => 'İnternet bağlantısı yok',
        'gonderiyor' => 'Gönderiliyor...',
        'hata' => 'Eşitleme hatası',
        _ => 'Giriş yapılmadı (veriler sadece bu telefonda)',
      };

  @override
  Widget build(BuildContext context) {
    final u = Senkron.acik ? FirebaseAuth.instance.currentUser : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Eşitleme ve Güncelleme')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        const ListTile(dense: true, title: Text('Eşitleme', style: TextStyle(fontWeight: FontWeight.bold))),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(u == null ? Icons.cloud_off : Icons.cloud_done, color: u == null ? Colors.grey : Colors.green),
              title: Text(u?.email ?? (Senkron.acik ? 'Giriş yapılmadı (veriler sadece bu telefonda)' : 'Bulut eşitleme kurulmamış')),
              subtitle: u == null ? null : ValueListenableBuilder<String>(valueListenable: Senkron.durum, builder: (_, d, __) => Text(metin(d))),
            ),
            if (u != null) ...[
              ListTile(dense: true, leading: const Icon(Icons.schedule_send), title: Text('Gönderilmeyi bekleyen: $bekleyen')),
              ListTile(leading: const Icon(Icons.sync), title: const Text('Şimdi eşitle'), onTap: esitle),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Bu telefondaki tüm verileri yeniden gönder'),
                subtitle: const Text('Girişten önce bu telefonda girilmiş kayıtlar buluta gitmediyse'),
                onTap: hepsi,
              ),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Çıkış yap'), onTap: cikis),
            ] else if (Senkron.acik)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Giriş yap ve verileri paylaş'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GirisEkrani())).then((_) => setState(() {})),
              ),
          ]),
        ),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.info_outline), title: Text('Sürüm $surum')),
            ListTile(leading: const Icon(Icons.system_update), title: const Text('Güncellemeleri denetle'), onTap: () => Guncelleme.kontrol(context, sor: true)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Kullanıcılar yönetici tarafından eklenir. Aynı hesapla giren tüm telefonlar aynı verileri görür.', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
