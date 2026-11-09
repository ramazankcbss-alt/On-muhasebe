import 'package:flutter/material.dart';

import 'aktar.dart';
import 'belge.dart';
import 'cari.dart';
import 'cek.dart';
import 'db.dart';
import 'entegrasyon.dart';
import 'hizli.dart';
import 'ortak.dart';
import 'raporlar.dart';
import 'sirket.dart';
import 'uretim.dart';
import 'urun.dart';
import 'whatsapp.dart';

class MI {
  final String ad;
  final IconData ikon;
  final Widget Function() ekran;
  final bool ayirac;
  const MI(this.ad, this.ikon, this.ekran, {this.ayirac = false});
}

class Modul {
  final String ad;
  final IconData ikon;
  final Color renk;
  final List<MI> ogeler;
  const Modul(this.ad, this.ikon, this.renk, this.ogeler);
}

Widget _bf(String tur) => BelgeForm(tur);
Widget _is(String kod) => IslemForm(kod);

/// EBS Ticari 7.0 menü yapısının aynısı + yeni bölümler
final moduller = <Modul>[
  Modul('Cariler', Icons.groups, Colors.brown, [
    MI('Hesap Tanımla', Icons.person_add, () => const CariForm()),
    MI('Borç Dekontu', Icons.arrow_upward, () => _is('borc_dekont'), ayirac: true),
    MI('Alacak Dekontu', Icons.arrow_downward, () => _is('alacak_dekont')),
    MI('Çoklu Borç/Alacak Dekontu', Icons.playlist_add, () => const CokluIslem(odemeTahsilat: false)),
    MI('Tahsilat', Icons.call_received, () => _is('tahsilat')),
    MI('Ödeme', Icons.call_made, () => _is('odeme')),
    MI('Çoklu Ödeme/Tahsilat', Icons.playlist_add_check, () => const CokluIslem(odemeTahsilat: true)),
    MI('Açılış Borç', Icons.flag, () => _is('c_acilis_borc')),
    MI('Açılış Alacak', Icons.outlined_flag, () => _is('c_acilis_alacak')),
    MI('Devir Borç', Icons.redo, () => _is('c_devir_borc')),
    MI('Devir Alacak', Icons.undo, () => _is('c_devir_alacak')),
    MI('Cari Virman', Icons.swap_horiz, () => _is('cari_virman')),
    MI('Cari Hesap Listesi', Icons.list_alt, () => const CariListe(), ayirac: true),
    MI('Cari Fiş Listesi', Icons.receipt_long, cariFisListesi),
    MI('Cari Hareket Listesi', Icons.timeline, cariHareketListesi),
    MI('Cari Bakiye Listesi', Icons.account_balance_wallet, () => const CariListe(sadeceBakiyeli: true)),
    MI('Rapor: Bize Borçlu Cariler', Icons.trending_up, () => cariRaporu('borclu'), ayirac: true),
    MI('Rapor: Borçlu Olduğumuz Cariler', Icons.trending_down, () => cariRaporu('alacakli')),
  ]),
  Modul('Ürünler', Icons.inventory_2, Colors.blueGrey, [
    MI('Ürün Tanımla', Icons.add_box, () => const UrunForm()),
    MI('Depo Tanımla', Icons.warehouse, () => const BasitListe('depo', 'Depolar')),
    MI('Stok Giriş Fişi', Icons.move_to_inbox, () => _bf('stok_giris'), ayirac: true),
    MI('Stok Çıkış Fişi', Icons.outbox, () => _bf('stok_cikis')),
    MI('Sayım Fazlası', Icons.exposure_plus_1, () => _bf('sayim_fazlasi')),
    MI('Sayım Eksiği', Icons.exposure_neg_1, () => _bf('sayim_eksigi')),
    MI('Fire Fişi', Icons.delete_sweep, () => _bf('fire')),
    MI('Sarf Fişi', Icons.build, () => _bf('sarf')),
    MI('Üretimden Giriş', Icons.factory, () => _bf('uretimden_giris')),
    MI('Stok Açılış Fişi', Icons.flag, () => _bf('stok_acilis')),
    MI('Stok Devir Fişi', Icons.redo, () => _bf('stok_devir')),
    MI('Depo Transfer Fişi', Icons.local_shipping, () => _bf('depo_transfer')),
    MI('Barkod Yazdır', Icons.qr_code_2, barkodListesi, ayirac: true),
    MI('Hızlı Fiyat Değişiklik', Icons.price_change, () => const HizliFiyat()),
    MI('Ürün Hızlı Güncelleme', Icons.edit_note, () => const UrunHizliGuncelle()),
    MI('Ürün Listesi', Icons.list, () => const UrunListe(), ayirac: true),
    MI('Ürün Fiş Listesi', Icons.receipt, urunFisListesi),
    MI('Ürün Hareket Listesi', Icons.timeline, urunHareketListesi),
    MI('Ürün Özet Listesi', Icons.summarize, urunOzetListesi),
    MI('Ürün Durum Listesi', Icons.inventory, urunDurumListesi),
    MI('Rapor: Depo Bazında Stok', Icons.warehouse, depoStokRaporu, ayirac: true),
  ]),
  Modul('Üretim', Icons.precision_manufacturing, Colors.grey, [
    MI('Reçeteler', Icons.menu_book, () => const ReceteListe()),
    MI('Üretim Emri', Icons.assignment, () => const UretimEmirleri()),
    MI('Çıktı Raporu', Icons.output, uretimCiktiRaporu, ayirac: true),
    MI('Genel Üretim Eksik Listesi', Icons.report_problem, uretimEksikListesi),
    MI('Üretim Durum Listesi', Icons.fact_check, uretimDurumListesi),
  ]),
  Modul('İrsaliye', Icons.local_shipping, Colors.indigo, [
    MI('Alış İrsaliyesi', Icons.input, () => _bf('alis_irsaliye')),
    MI('Satış İrsaliyesi', Icons.output, () => _bf('satis_irsaliye')),
    MI('Alış İade İrsaliyesi', Icons.keyboard_return, () => _bf('alis_iade_irsaliye'), ayirac: true),
    MI('Satış İade İrsaliyesi', Icons.assignment_return, () => _bf('satis_iade_irsaliye')),
    MI('İrsaliye Listesi', Icons.list, () => const BelgeListe('İrsaliye', baslik: 'İrsaliye Listesi'), ayirac: true),
    MI('Rapor: İrsaliye Satır Listesi', Icons.table_rows, () => belgeSatirListesi('İrsaliye', 'İrsaliye Satır Listesi'), ayirac: true),
  ]),
  Modul('Fatura', Icons.receipt_long, Colors.green, [
    MI('Alış Faturası', Icons.input, () => _bf('alis_fatura')),
    MI('Satış Faturası', Icons.output, () => _bf('satis_fatura')),
    MI('Alış İade Faturası', Icons.keyboard_return, () => _bf('alis_iade_fatura'), ayirac: true),
    MI('Satış İade Faturası', Icons.assignment_return, () => _bf('satis_iade_fatura')),
    MI('Fatura Listesi', Icons.list, () => const BelgeListe('Fatura', baslik: 'Fatura Listesi'), ayirac: true),
    MI('Fatura Satır Listesi', Icons.table_rows, () => belgeSatirListesi('Fatura', 'Fatura Satır Listesi')),
    MI('Rapor: Aylık KDV / Alış-Satış', Icons.percent, kdvRaporu, ayirac: true),
  ]),
  Modul('EFatura', Icons.cloud_upload, Colors.red, [
    MI('Gelen Fatura', Icons.call_received, () => _portal('GİB e-Arşiv Portal')),
    MI('Giden Fatura', Icons.call_made, () => _portal('GİB e-Arşiv Portal')),
    MI('eArşiv Fatura', Icons.cloud, () => _portal('GİB e-Arşiv Portal'), ayirac: true),
    MI('EFatura-EArşiv Tanım', Icons.settings, () => const PortalListe(), ayirac: true),
  ]),
  Modul('Fiş', Icons.receipt, Colors.teal, [
    MI('Alış Fişi', Icons.input, () => _bf('alis_fis')),
    MI('Satış Fişi', Icons.output, () => _bf('satis_fis')),
    MI('Alış İade Fişi', Icons.keyboard_return, () => _bf('alis_iade_fis'), ayirac: true),
    MI('Satış İade Fişi', Icons.assignment_return, () => _bf('satis_iade_fis')),
    MI('Fiş Listesi', Icons.list, () => const BelgeListe('Fiş', baslik: 'Fiş Listesi'), ayirac: true),
    MI('Fiş Satır Listesi', Icons.table_rows, () => belgeSatirListesi('Fiş', 'Fiş Satır Listesi')),
  ]),
  Modul('Hızlı Satış', Icons.point_of_sale, Colors.orange, [
    MI('Hızlı Satış', Icons.shopping_cart, () => const HizliSatis()),
    MI('Hızlı Satış İade', Icons.remove_shopping_cart, () => const HizliSatis(iade: true)),
    MI('Fiyat Gör', Icons.sell, () => const FiyatGor(), ayirac: true),
    MI('Gün Sonu Özet Rapor', Icons.today, gunSonu, ayirac: true),
    MI('Günlük Satış Raporu', Icons.calendar_view_day, () => gunlukSatis()),
    MI('Günlük Satış Detaylı Rapor', Icons.view_list, () => gunlukSatis(detay: true)),
    MI('Satış Dökümü', Icons.format_list_numbered, satisDokumu),
    MI('Kar/Zarar Analizi', Icons.analytics, () => karZararUrun()),
    MI('Kar/Zarar Analizi (Cari Hesap)', Icons.person_search, () => karZararCari()),
    MI('Kar/Zarar Analizi (Cari Hesap Detaylı)', Icons.manage_search, () => karZararCari(detay: true)),
    MI('Genel Rapor', Icons.assessment, genelRapor),
  ]),
  Modul('Sipariş', Icons.shopping_bag, Colors.cyan, [
    MI('Alınan Sipariş (Satış)', Icons.call_received, () => _bf('siparis_alinan')),
    MI('Verilen Sipariş (Satınalma)', Icons.call_made, () => _bf('siparis_verilen')),
    MI('Sipariş Listesi', Icons.list, () => const BelgeListe('Sipariş', baslik: 'Sipariş Listesi'), ayirac: true),
    MI('Ürün Bazında Sipariş İzleme', Icons.track_changes, () => siparisIzleme(false)),
    MI('Ürün Bazında Sipariş Toplam', Icons.functions, () => siparisIzleme(true)),
  ]),
  Modul('Banka', Icons.account_balance, Colors.blue, [
    MI('Banka Hesabı Tanımla', Icons.add_card, () => const BasitListe('hesap', 'Banka Hesapları', tip: 'banka')),
    MI('Gelen Havale/EFT', Icons.call_received, () => _is('gelen_havale'), ayirac: true),
    MI('Giden Havale/EFT', Icons.call_made, () => _is('giden_havale')),
    MI('Para Yatırma', Icons.savings, () => _is('para_yatirma')),
    MI('Para Çekme', Icons.atm, () => _is('para_cekme')),
    MI('Diğer Borç İşlemi', Icons.add_circle_outline, () => _is('b_diger_borc')),
    MI('Diğer Alacak İşlemi', Icons.remove_circle_outline, () => _is('b_diger_alacak')),
    MI('Açılış Borç', Icons.flag, () => _is('b_acilis_borc')),
    MI('Açılış Alacak', Icons.outlined_flag, () => _is('b_acilis_alacak')),
    MI('Devir Borç', Icons.redo, () => _is('b_devir_borc')),
    MI('Devir Alacak', Icons.undo, () => _is('b_devir_alacak')),
    MI('Hesap Virman', Icons.swap_horiz, () => _is('hesap_virman')),
    MI('Banka Hesap Listesi', Icons.list, () => hesapEkstre('banka'), ayirac: true),
    MI('Banka Fiş Listesi', Icons.receipt, () => finansHareketListesi('banka', 'Banka Fiş Listesi', fis: true)),
    MI('Banka Hareket Listesi', Icons.timeline, () => finansHareketListesi('banka', 'Banka Hareket Listesi')),
  ]),
  Modul('Çek-Senet', Icons.edit_document, Colors.deepPurple, [
    MI('Çek/Senet Bordroları', Icons.list_alt, () => cekRaporu('bordro')),
    MI('Çek ve Senetler', Icons.money, () => const CekListe()),
    MI('Ortalama Vade', Icons.av_timer, () => const OrtalamaVade(), ayirac: true),
    MI('Rapor: Vadesi Yaklaşanlar', Icons.alarm, () => cekRaporu('vade'), ayirac: true),
  ]),
  Modul('Kasa', Icons.point_of_sale, Colors.amber, [
    MI('Kasa Tanımla', Icons.add_box, () => const BasitListe('hesap', 'Kasalar', tip: 'kasa')),
    MI('Cariden Tahsilat', Icons.call_received, () => _is('cariden_tahsilat'), ayirac: true),
    MI('Cariye Ödeme', Icons.call_made, () => _is('cariye_odeme')),
    MI('Diğer Tahsilat', Icons.add_circle_outline, () => _is('diger_tahsilat')),
    MI('Diğer Ödeme', Icons.remove_circle_outline, () => _is('diger_odeme')),
    MI('Devir Gelir', Icons.redo, () => _is('devir_gelir')),
    MI('Devir Gider', Icons.undo, () => _is('devir_gider')),
    MI('Açılış Gelir', Icons.flag, () => _is('acilis_gelir')),
    MI('Açılış Gider', Icons.outlined_flag, () => _is('acilis_gider')),
    MI('Kasa Virman', Icons.swap_horiz, () => _is('kasa_virman')),
    MI('Kasa Fiş Listesi', Icons.receipt, () => finansHareketListesi('kasa', 'Kasa Fiş Listesi', fis: true), ayirac: true),
    MI('Kasa Hareket Listesi', Icons.timeline, () => finansHareketListesi('kasa', 'Kasa Hareket Listesi')),
    MI('Kasa Bakiye Listesi', Icons.account_balance_wallet, () => hesapEkstre('kasa')),
    MI('Rapor: Gelir / Gider Kategorileri', Icons.pie_chart, giderRaporu, ayirac: true),
  ]),
  Modul('Kar/Zarar', Icons.insights, Colors.pink, [
    MI('Kar/Zarar (Fatura-Fiş)', Icons.request_quote, karZararFaturaFis),
    MI('Kar/Zarar (Cari - Stok)', Icons.person_search, () => karZararCari(baslik: 'Kar/Zarar (Cari - Stok)', detay: true)),
    MI('Satış Özet Raporu', Icons.summarize, satisOzet, ayirac: true),
    MI('Günlük Satış Raporu', Icons.calendar_view_day, () => gunlukSatis()),
    MI('Günlük Satış Detaylı Rapor', Icons.view_list, () => gunlukSatis(detay: true)),
    MI('Genel Rapor', Icons.assessment, genelRapor),
    MI('Kazanç Analizi', Icons.analytics, () => karZararUrun(baslik: 'Kazanç Analizi'), ayirac: true),
    MI('Kazanç Analizi (Cari Hesap)', Icons.person, () => karZararCari(baslik: 'Kazanç Analizi (Cari Hesap)')),
    MI('Kazanç Analizi (Cari Hesap Detaylı)', Icons.manage_search, () => karZararCari(baslik: 'Kazanç Analizi (Cari Hesap Detaylı)', detay: true)),
  ]),
  Modul('Yönetim', Icons.supervisor_account, Colors.lightGreen, [
    MI('Genel Durum Raporu', Icons.dashboard, genelDurum),
    MI('Faaliyet Raporu', Icons.event_note, faaliyetRaporu),
    MI('Nakit Akış Raporu', Icons.waterfall_chart, () => nakitAkis(), ayirac: true),
    MI('Nakit Akış (Detaylı) Raporu', Icons.list, () => nakitAkis(detay: true)),
    MI('En Çok Satış Yapılan 20 Müşteri', Icons.emoji_events, () => enCok(true), ayirac: true),
    MI('En Çok Satış Yapılan 20 Ürün', Icons.star, () => enCok(false)),
    MI('Şirket Bilgisi', Icons.business, () => const SirketBilgisi(), ayirac: true),
  ]),
  Modul('Veri Aktar', Icons.upload_file, Colors.deepOrange, [
    MI('Excel / CSV Yükle', Icons.upload_file, () => const VeriAktar()),
    MI('Aktarılan Tablolar', Icons.table_chart, () => const SerbestTablolar()),
    MI('Notlar', Icons.sticky_note_2, () => const NotListesi()),
  ]),
  Modul('Portallar', Icons.language, Colors.indigoAccent, [
    MI('Tüm Portallar', Icons.language, () => const PortalListe()),
    MI('e-Devlet', Icons.account_balance, () => _portal('e-Devlet'), ayirac: true),
    MI('GİB Dijital Vergi Dairesi', Icons.request_page, () => _portal('GİB Dijital Vergi Dairesi')),
    MI('Trafik Cezası', Icons.directions_car, () => _portal('Trafik Cezası Sorgulama')),
    MI('SGK e-Bildirge', Icons.health_and_safety, () => _portal('SGK e-Bildirge (İşveren)')),
    MI('SGK / Bağ-Kur Borç', Icons.payments, () => _portal('SGK / Bağ-Kur Borç Sorgu (e-Devlet)')),
    MI('Enerya Firma Portalı', Icons.local_fire_department, () => _portal('Enerya Firma Portalı')),
    MI('Gasline - Prizma A.Ş.', Icons.gas_meter, () => _portal('Gasline - Prizma A.Ş.')),
    MI('DİPOS IV', Icons.architecture, () => _portal('DİPOS IV')),
  ]),
  Modul('WhatsApp', Icons.chat, const Color(0xFF25D366), [
    MI('Sohbetten Veri Al', Icons.chat, () => const WhatsappAktar()),
    MI('Notlar', Icons.sticky_note_2, () => const NotListesi()),
  ]),
];

/// Portalı adıyla bulup açar (adres yoksa düzenleme ekranı)
Widget _portal(String ad) => _PortalAc(ad);

class _PortalAc extends StatelessWidget {
  final String ad;
  const _PortalAc(this.ad);
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>?>(
        future: DB.tek('SELECT * FROM portal WHERE ad=?', [ad]),
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final p = s.data;
          if (p == null) return const PortalListe();
          if ('${p['url'] ?? ''}'.isEmpty) return PortalForm(p);
          return PortalWeb(p);
        },
      );
}

class AnaMenu extends StatefulWidget {
  const AnaMenu({super.key});
  @override
  State<AnaMenu> createState() => _AnaMenuState();
}

class _AnaMenuState extends State<AnaMenu> {
  String firma = '';
  Map<String, Object?> ozet = {};

  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    final s = await DB.tek('SELECT unvan FROM sirket WHERE id=1');
    final k = await DB.tek("SELECT IFNULL(SUM(giris-cikis),0) b FROM finans_hareket f JOIN hesap h ON h.id=f.hesap_id WHERE h.tip='kasa'");
    final b = await DB.tek("SELECT IFNULL(SUM(giris-cikis),0) b FROM finans_hareket f JOIN hesap h ON h.id=f.hesap_id WHERE h.tip='banka'");
    final c = await DB.tek('SELECT SUM(CASE WHEN bk>0 THEN bk ELSE 0 END) a, SUM(CASE WHEN bk<0 THEN -bk ELSE 0 END) b FROM (SELECT SUM(borc-alacak) bk FROM cari_hareket GROUP BY cari_id)');
    final cek = await DB.tek("SELECT COUNT(*) n FROM cek_senet WHERE durum='Portföyde' AND vade<=?", [tarihS(DateTime.now().add(const Duration(days: 7)))]);
    if (!mounted) return;
    setState(() {
      firma = '${s?['unvan'] ?? ''}';
      ozet = {'Kasa': sy(k?['b']), 'Banka': sy(b?['b']), 'Alacaklar': sy(c?['a']), 'Borçlar': sy(c?['b']), 'cek': cek?['n'] ?? 0};
    });
  }

  Future<void> ac(Modul m) async {
    final w = await showModalBottomSheet<Widget>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: m.ogeler.length > 8 ? .75 : .5,
        maxChildSize: .95,
        builder: (_, sc) => ListView(controller: sc, children: [
          ListTile(leading: Icon(m.ikon, color: m.renk), title: Text(m.ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          for (final o in m.ogeler) ...[
            if (o.ayirac) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(dense: true, leading: Icon(o.ikon, size: 22), title: Text(o.ad), onTap: () => Navigator.pop(context, o.ekran())),
          ],
        ]),
      ),
    );
    if (w == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    yukle();
  }

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    Widget kart(String a, String k) => Expanded(
          child: Card(
            color: r.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(children: [
                Text(a, style: const TextStyle(fontSize: 12)),
                FittedBox(child: Text(para(ozet[k]), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ön Muhasebe', style: TextStyle(fontSize: 18)),
          Text(firma, style: const TextStyle(fontSize: 12)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.business),
              tooltip: 'Şirket Bilgisi',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SirketBilgisi()));
                yukle();
              }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: yukle,
        child: ListView(padding: const EdgeInsets.all(8), children: [
          Row(children: [kart('Kasa', 'Kasa'), kart('Banka', 'Banka')]),
          Row(children: [kart('Alacaklar', 'Alacaklar'), kart('Borçlar', 'Borçlar')]),
          if ((ozet['cek'] as int? ?? 0) > 0)
            Card(
              color: Colors.orange[100],
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text('${ozet['cek']} çek/senedin vadesi 7 gün içinde'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => cekRaporu('vade'))),
              ),
            ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: moduller
                .map((m) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => ac(m),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(m.ikon, size: 34, color: m.renk),
                          const SizedBox(height: 6),
                          Text(m.ad, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
}
