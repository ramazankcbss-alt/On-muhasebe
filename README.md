# Ön Muhasebe (EBS Ticari benzeri) – Android

Kones Mühendislik için EBS Yazılım Ticari 7.0 menü yapısını birebir izleyen, telefonda çalışan ön muhasebe uygulaması.
Flutter ile yazıldı; veriler **telefonda** (SQLite) tutulur, internet gerekmez (portallar hariç).

## Ana ekrandaki bölümler

| Bölüm | İçerik |
|---|---|
| Cariler | Hesap tanımla, borç/alacak dekontu, çoklu dekont, tahsilat, ödeme, çoklu ödeme/tahsilat, açılış/devir, cari virman, cari hesap/fiş/hareket/bakiye listeleri, ekstre |
| Ürünler | Ürün ve depo tanımla, stok giriş/çıkış, sayım fazlası/eksiği, fire, sarf, üretimden giriş, açılış/devir, depo transfer, hızlı fiyat değişikliği, hızlı güncelleme, barkod listesi, ürün listeleri |
| Üretim | Reçeteler, üretim emri (hammadde düşer, mamul maliyetiyle girer), çıktı raporu, eksik listesi, durum listesi |
| İrsaliye / Fatura / Fiş | Alış, satış, iadeler; listeler, satır listeleri; irsaliyeyi faturaya dönüştürme (stok iki kez düşmez); peşin/veresiye; aylık KDV raporu |
| EFatura | GİB e-Arşiv portalını uygulama içinde açar, listeleri tabloyla içeri alır |
| Hızlı Satış | Barkodla kasa ekranı (nakit/kart/veresiye), iade, fiyat gör, gün sonu, günlük satış, satış dökümü, kâr/zarar analizleri |
| Sipariş | Alınan/verilen sipariş, sipariş → irsaliye/fatura, ürün bazında izleme ve toplam |
| Banka / Kasa | Hesap tanımlama, havale/EFT, para yatırma/çekme, diğer gelir-gider (kategorili), açılış/devir, virman, fiş/hareket/bakiye listeleri |
| Çek-Senet | Alınan/verilen çek-senet, tahsil/ödeme/ciro/karşılıksız, bordro, ortalama vade, vadesi yaklaşanlar |
| Kar/Zarar, Yönetim | Kar/zarar (fatura-fiş, cari-stok), kazanç analizleri, genel durum, faaliyet, nakit akış (beklenen çek ve fatura vadeleri dahil), en çok satış yapılan 20 müşteri/ürün, şirket bilgisi |
| **Veri Aktar** | Excel (.xlsx) / CSV yükleme, sütunları otomatik eşleme, boş şablonlar, tüm verinin Excel yedeği |
| **Portallar** | e-Devlet, GİB Dijital Vergi Dairesi, e-Arşiv, trafik cezası, SGK e-Bildirge, SGK/Bağ-Kur borç, Enerya, Gasline-Prizma, DİPOS IV (+ istediğiniz kadar yeni portal) |
| **WhatsApp** | Dışa aktarılan sohbetten tutarlı mesajları bulup tahsilat/ödeme/gider/not olarak işler |

Tüm listeler ve raporlar sağ üstteki paylaş düğmesiyle **Excel** olarak WhatsApp, e-posta veya Drive'a gönderilebilir.

## Portallardan veri alma nasıl çalışır

1. Portallar'da ilgili satıra dokunun; site uygulamanın içinde açılır.
2. Girişi **kendiniz** yaparsınız (e-Devlet şifresi, SMS, e-imza). Şifre uygulamaya kaydedilmez; oturum çerezi telefonda kalır.
3. Borç listesi, fatura listesi, proje listesi gibi verinin olduğu sayfaya gidin.
4. ▦ **Tabloları al** → sayfadaki tablolardan birini seçin → nereye aktarılacağını seçin (kurum borcu, satış faturası, banka hareketi, olduğu gibi sakla...).
5. "Bu eşlemeyi portal için kaydet" açıksa, sonraki girişlerde sağ üstteki ⚡ ile **tek dokunuşta** aktarılır. Aynı satır ikinci kez eklenmez.

Enerya, Gasline-Prizma ve DİPOS IV'ün giriş adreslerini bir kez girmeniz gerekir (satıra uzun basın).

Sınırlar: Kamu portallarının herkese açık bir API'si yoktur ve girişler SMS/e-imza ister; bu yüzden giriş hiçbir zaman arka planda kendiliğinden yapılamaz. Uygulama, sizin açtığınız oturumdaki ekranı okur. Site tasarımı değişirse kayıtlı eşleme bir kez yeniden yapılır.

## WhatsApp'tan veri alma

WhatsApp başka uygulamaların mesajları okumasına izin vermez. Sohbet → ⋮ → Diğer → **Sohbeti dışa aktar** → Medya olmadan → Dosyalara kaydet. Sonra uygulamada WhatsApp → "Sohbet dosyası seç".

## APK'yı derleme (telefondan)

1. GitHub'da **özel (private)** bir depo açın (ör. `on-muhasebe`). Bu uygulama mali veri ve kamu portalı oturumları taşıdığı için depo özel olmalı.
2. Bu klasördeki tüm dosyaları (gizli `.github` klasörü dahil) depoya yükleyin.
3. Actions sekmesinde **APK Derle** kendiliğinden çalışır (~8-10 dk). Bitince **Releases** altında `app-release.apk` çıkar; telefona indirip kurun.
4. Her kod değişikliğinde yeni sürüm oluşur ve eskisinin üzerine kurulur (`imza/debug.keystore` sabit imza sağlar; silmeyin).

## Veri güvenliği

- Tüm muhasebe verisi telefonda tutulur. Düzenli olarak **Veri Aktar → Tüm verileri Excel olarak yedekle** ile yedek alın.
- Vergi no, GSM, e-posta gibi bilgiler koda yazılmadı; Yönetim → Şirket Bilgisi'nden girin.

## EBS'den farklı olanlar

- Senet yazdırma ayarları yok (telefondan yazıcıya senet basılmıyor).
- e-Fatura **gönderimi** özel entegratör sözleşmesi ve API anahtarı gerektirir; şimdilik GİB e-Arşiv portalı uygulama içinden kullanılır ve listeler içeri alınır.
- Barkod yazdırma, etiket programına aktarılacak Excel listesi olarak verilir.
