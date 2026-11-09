import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'menu.dart';
import 'ortak.dart';
import 'senkron.dart';

/// Açılışta gösterilen giriş ekranı.
/// Kullanıcılar Firebase konsolundan yönetici tarafından eklenir; burada kayıt olunmaz.
class GirisEkrani extends StatefulWidget {
  /// true ise girişten sonra ana menü yerine önceki ekrana dönülür.
  final bool geriDon;
  const GirisEkrani({super.key, this.geriDon = false});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final eposta = TextEditingController();
  final sifre = TextEditingController();
  bool bekle = false, gizli = true;

  void _devam() {
    if (widget.geriDon) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AnaMenu()));
    }
  }

  Future<void> giris() async {
    final e = eposta.text.trim();
    if (e.isEmpty || sifre.text.isEmpty) return mesaj(context, 'E-posta ve şifre girin');
    setState(() => bekle = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: sifre.text);
      await Senkron.basla();
      if (!mounted) return;
      final eski = await DB.tek('SELECT COUNT(*) n FROM cari');
      if (!mounted) return;
      if (((eski?['n'] as int?) ?? 0) > 0 &&
          await onay(context,
              'Bu telefonda daha önce girilmiş kayıtlar var. Buluta gitmediyse şimdi gönderilsin mi? (Sonra "Eşitleme ve Güncelleme" ekranından da yapabilirsiniz.)')) {
        await Senkron.hepsiniGonder();
      }
      if (mounted) _devam();
    } on FirebaseAuthException catch (x) {
      if (!mounted) return;
      final m = switch (x.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => 'E-posta veya şifre hatalı',
        'network-request-failed' => 'İnternet bağlantısı yok',
        'user-disabled' => 'Bu kullanıcı devre dışı bırakılmış',
        'too-many-requests' => 'Çok fazla deneme yapıldı, biraz sonra tekrar deneyin',
        _ => 'Giriş yapılamadı (${x.code})',
      };
      mesaj(context, m);
    } catch (x) {
      if (mounted) mesaj(context, 'Giriş yapılamadı ($x)');
    } finally {
      if (mounted) setState(() => bekle = false);
    }
  }

  Future<void> sifremiUnuttum() async {
    final e = eposta.text.trim();
    if (e.isEmpty) return mesaj(context, 'Önce e-posta adresinizi yazın');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
      if (mounted) mesaj(context, 'Şifre sıfırlama bağlantısı e-postanıza gönderildi');
    } on FirebaseAuthException catch (x) {
      if (mounted) mesaj(context, 'Gönderilemedi (${x.code})');
    }
  }

  Future<void> girissiz() async {
    if (!await onay(context, 'Girişsiz kullanımda veriler sadece bu telefonda kalır, diğer telefonlarla paylaşılmaz. Devam edilsin mi?')) return;
    await DB.ayarYaz('girissiz', '1');
    if (mounted) _devam();
  }

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.geriDon ? AppBar(title: const Text('Giriş')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.account_balance_wallet, size: 64, color: r.primary),
                const SizedBox(height: 8),
                const Text('Ön Muhasebe', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Kones Mühendislik', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (!Senkron.kurulu)
                  const Card(child: ListTile(leading: Icon(Icons.cloud_off), title: Text('Bulut eşitleme kurulmamış'))),
                TextField(
                  controller: eposta,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sifre,
                  obscureText: gizli,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => giris(),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(gizli ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => gizli = !gizli)),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: bekle || !Senkron.kurulu ? null : giris,
                  icon: bekle ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                  label: const Text('Giriş Yap'),
                ),
                TextButton(onPressed: Senkron.kurulu ? sifremiUnuttum : null, child: const Text('Şifremi unuttum')),
                const Divider(height: 32),
                if (!widget.geriDon)
                  OutlinedButton.icon(onPressed: girissiz, icon: const Icon(Icons.phone_android), label: const Text('Girişsiz devam et (sadece bu telefon)')),
                const SizedBox(height: 12),
                const Text('Kullanıcılar yönetici tarafından eklenir. Aynı hesapla giren tüm telefonlar aynı verileri görür.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
