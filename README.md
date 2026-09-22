# Fatura Mega Okuyucu

Türk **e-Fatura / e-Arşiv / e-SMM (Serbest Meslek Makbuzu)** PDF'lerini toplu
olarak okuyan, tarayıcıda çalışan tek dosyalık bir araç. Her PDF için önce
**karekod (QR)** okunur; QR bulunamazsa sayfa metni üzerinde **regex** ile
alanlar çıkarılır. Çıkan veriler bir tabloda toplanır ve **KDV / tevkifat /
ödenecek tutar** ilişkileri otomatik matematiksel kontrolden geçirilir.

Muhasebeciler, mali müşavirler ve Ba/Bs formu hazırlayanlar için; onlarca
faturayı tek tek açıp elle veri girmek yerine sürükle-bırak ile saniyeler
içinde tablo çıkarmak üzere yapıldı.

> **Her şey tarayıcıda, yerelde çalışır.** Hiçbir fatura, hiçbir veri hiçbir
> sunucuya gönderilmez. Uygulama `file://` altında, internetsiz çalışacak
> şekilde tasarlandı (tek istisna: `pdf.js` ilk yüklemede CDN'den çekilir,
> sonra tarayıcı önbelleğine alınır — bkz. [Sınırlamalar](#sınırlamalar)).

> ⚠️ **Yasal uyarı / sorumluluk reddi:** Bu, **bağımsız bir gönüllü aracıdır**;
> GİB veya başka bir resmi kurumla **hiçbir bağlantısı yoktur**, resmi bir
> onayı/sertifikası yoktur. "Olduğu gibi" ([MIT lisansı](LICENSE)), **hiçbir
> garanti vermeden** sunulur. Karekod/regex ile çıkarılan veriler ve
> matematiksel doğrulama sonuçları **yalnızca ön kontrol ve zaman kazandırma
> amaçlıdır** — beyanname, muhasebe kaydı veya herhangi bir mali/hukuki karar
> için **tek başına dayanak olarak kullanılmamalıdır**. Sonuçları her zaman
> faturanın kendisiyle ve gerekiyorsa bir mali müşavirle teyit edin. Aracın
> kullanımından doğacak her türlü sonuçtan (yanlış/eksik okuma, hesaplama
> farkı, mevzuat değişikliği vb.) kullanıcı kendisi sorumludur; yazar(lar)
> hiçbir sorumluluk kabul etmez.

---

## Hızlı başlangıç

**En basit yol:** `FaturaMegaOkuyucu.html` dosyasını çift tıklayıp tarayıcıda
açın, fatura PDF'lerini pencereye sürükleyip bırakın. Hepsi bu.

**Yerel sunucuyla (geliştirme):**

```bash
node server.js
# http://localhost:8080 adresini açın
```

**Windows kurulumu (sağ tık → Gönder menüsü entegrasyonu):**
[Inno Setup](https://jrsoftware.org/isdl.php) ile `fatura_mega_okuyucu.iss`
dosyasını derleyin. Kurulumdan sonra Explorer'da birden fazla PDF seçip
**sağ tık → Gönder → Fatura Mega Okuyucu** ile doğrudan uygulamaya
atabilirsiniz. Ayrıntı: [Windows entegrasyonu](#windows-entegrasyonu-nasıl-çalışır).

---

## Ne yapar

| Özellik | Açıklama |
|---|---|
| **Çift motorlu QR okuma** | Önce [ZXing-wasm](https://github.com/zxing-js/zxing-wasm) (hızlı + toleranslı), bulamazsa [jsQR](https://github.com/cozmo/jsQR). İkisi de `<script>` ile gömülü — ağ/CORS gerektirmez. |
| **Sistematik tarama** | `SCAN_PASSES` dizisi: sağ üst köşe → sol üst köşe → üst şerit → tüm sayfa, her biri artan ölçeklerle. Çok sayfalı PDF'lerde tüm sayfalar denenir. |
| **Regex yedeği** | QR yoksa sayfa metninden alan çıkarır. Kurallar **sol panelden düzenlenebilir** ve `mega_config.json` ile taşınabilir. |
| **e-Fatura + e-SMM** | İki belge türü ayrı ayrı ele alınır — farklı QR şemaları, farklı alan kümeleri, farklı doğrulama kuralları. Bkz. [QR şemaları](docs/qr-semalari.md). |
| **Matematiksel doğrulama** | KDV matrahı + hesaplanan KDV = vergiler dahil toplam; vergiler dahil − tevkifat = ödenecek; tevkifat oranı standart GİB fraksiyonlarından biri mi; olası iskonto tespiti. Sorunlu satırlar kırmızı işaretlenir. |
| **Mükerrer tespiti** | Aynı ETTN veya fatura no birden fazla satırdaysa uyarır. |
| **Türetilmiş alanlar** | Tevkifat tutarı ve oranı QR'da olmasa bile `Vergiler Dahil − Ödenecek` üzerinden hesaplanır. |
| **Dışa aktarma** | Panoya kopyala (Excel'e yapıştırmaya hazır) veya CSV indir. |
| **Manuel QR işaretleme** | Otomatik bulunamayan karekodu fareyle işaretleyip taratma; belirli bir satırı seçili yöntemle yeniden tarama (⋮ menüsü). |
| **Kalem tablosu doğrulama** | Fatura içindeki "Sıra No" satır tablosunu (ürün/hizmet kalemleri) pdf.js metin konumlarından ve gerçek çizgi verisinden tespit eder, kalemlerin toplamını karekoddaki "Mal/Hizmet Tutarı" ile karşılaştırır. Tek fatura için 📋 butonu, tüm yüklenen faturalar için "🧾 Kalem Kontrolü (Tümü)" ile toplu tarama. "👁 Görsel Doğrulama" tespit edilen satır/sütun sınırlarını PDF sayfasının üzerine çizerek gösterir. |
| **Hibrit çizgi algılama** | Tablo satır/sütun çizgileri önce PDF'in **kendi vektör çizim verisinden** (`getOperatorList` + SVG, piksel/renk eşiği gerektirmez) okunur — kenarlıklı (stroke'lu) hücre kutularının kenarları da tanınır. Bir eksende hiçbir çizgi bulunamazsa, o eksen için **piksel-kapsam** yöntemi (renderlenmiş sayfa üzerinde koyuluk taraması) yedek olarak devreye girer. 285+ gerçek faturayla doğrulandı; farklı yazılımların çok çeşitli çizim tarzlarına (ince çizgi, kenarlıklı kutu, çizgisiz) dayanıklı. |

---

## QR şemaları — neden bu araç var

GİB'in karekod standardı asgari düzeyde: yazılım firmasına göre alan isimleri
ve içerik ciddi şekilde değişiyor. Bu araç gerçek faturalarla test edilerek
bu farklılıkların üstesinden gelecek şekilde yazıldı. Keşfedilen şemalar
ve tüm alan varyantları ayrı belgede:

**→ [docs/qr-semalari.md](docs/qr-semalari.md)**

Özetle:

- **e-Fatura (ticari):** `vkntckn`, `avkntckn`, `senaryo`, `malhizmettoplam`,
  `vergidahil`, `odenecek`, `hesaplanankdv(oran)`, `kdvmatrah(oran)` ...
- **e-SMM Varyant 1 (minimal):** `{"tur":"e-SMM", "no", "tarih", "net",
  "tahsilat", "VKNTCKN"}` — kırılım yok, alıcı VKN'si bile yok.
- **e-SMM Varyant 2 (detaylı):** `brutucret`, `kdvtutari`, `kdvtevkifat`,
  `gvstopaj`, `netucret`, `tahsilkdv`, `tahsilat` — tam kırılım, `tur` alanı yok.

"Hesaplanan KDV" alanının kimi yazılımda **tevkifat sonrası net**, kimisinde
**tevkifat öncesi tam** yazılması gibi tuzaklar da belgede anlatıldı.

---

## Matematiksel doğrulama kuralları

Uygulamanın en altında, muhasebeci gözüyle sade Türkçe açıklamalarıyla
listelenir. Kısaca:

**e-Fatura:**
1. `KDV Matrahları Toplamı + Hesaplanan KDV Toplamı = Vergiler Dahil Toplam`
2. `Vergiler Dahil Toplam − Tevkifat Toplamı = Ödenecek Tutar`
3. `KDV Matrahları + Hesaplanan KDV [− Tevkifat] = Ödenecek Tutar` (bağımsız çapraz kontrol)
4. Tevkifat oranı ∈ {1/10, 2/10, 3/10, 4/10, 5/10, 5,5/10, 7/10, 9/10, 10/10}
5. `Mal/Hizmet Tutarı − KDV Matrahları Toplamı` → olası iskonto (bilgi amaçlı)

**e-SMM (yalnızca detaylı QR şemasında):**
- `KDV Tutarı − KDV Tevkifatı = Tahsil Edilen KDV`
- `Brüt Ücret − G.V. Stopaj Tutarı = Net Ücret`
- `Net Ücret + Tahsil Edilen KDV = Net Tahsilat`

İlgili tutar bulunamayan kontrol sessizce atlanır — "hata" sayılmaz.
Özel vergiler (ÖİV, konaklama, damga vb.) hiçbir formüle katılmaz, yalnızca
kendi sütunlarında gösterilir.

---

## Windows entegrasyonu nasıl çalışır

`fatura_mega_okuyucu.iss` kurulumu üç şey yapar:

1. Dosyaları `%LOCALAPPDATA%\Programs\Fatura Mega Okuyucu` altına kopyalar (admin gerektirmez).
2. Başlat menüsü + masaüstü kısayolu ekler.
3. **Gönder (SendTo)** menüsüne kısayol ekler.

"Gönder" ile dosya seçildiğinde `mega_launcher.bat` çalışır:

- `build_temp_data.ps1` her açılışta `mega_config.json`'ı `temp_config.js`'e tazeler.
- Seçilen PDF'ler base64'e çevrilip `temp_files.js`'e yazılır.
- `msedge --app=...?auto=1` açılır; sayfa `temp_files.js`'ten dosyaları alıp
  otomatik işlemeye başlar.

> **Neden base64?** `file://` altında çalışan bir sayfa, tarayıcı güvenlik
> politikası gereği `fetch()`/`XMLHttpRequest` ile başka yerel dosyaları
> okuyamaz (Chromium her `file://` URL'yi izole origin sayar). Dosyayı
> `<script>` ile taşımanın tek güvenilir yolu metne (base64'e) çevirmek.
> `--allow-file-access-from-files` bayrağı denendi; kurumsal ortamlarda
> Edge politikası bunu engelleyebiliyor, base64 her ortamda çalışıyor.

`temp_config.js` ve `temp_files.js` **launcher tarafından üretilir**, depoya
girmez (`.gitignore`). Uygulama bu dosyalar yokken de sorunsuz açılır
(404 sessizce yutulur).

---

## Sınırlamalar

- **Taranmış / görüntü tabanlı PDF'ler:** Metin katmanı olmayan (yalnızca
  görsel veya vektör-path olarak çizilmiş) PDF'lerde regex çalışamaz. QR
  varsa okunur, yoksa satır boş kalır. OCR kapsam dışı.
- **`pdf.js` CDN bağımlılığı:** `pdf.min.js` ve `pdf.worker.min.js`
  ilk yüklemede `cdnjs.cloudflare.com`'dan çekilir (sonra tarayıcı
  önbelleğinde). Tamamen çevrimdışı kullanım için bu iki dosyayı da yerel
  indirip `<script src>` yolunu değiştirin.
- **Kısmi kalem tevkifatı:** Faturada birden fazla kalem olup yalnızca bir
  kısmı tevkifata tabiyse, QR yalnızca fatura toplamını verdiği için oran
  "standart dışı" görünebilir — kesinti aslında standart olsa bile. Uyarı
  metni bu durumu açıklar.
- **Sadece Chromium (Edge/Chrome) test edildi.** Firefox'ta `file://`
  davranışı farklı olabilir.
- **Kalem tablosu doğrulama her faturada çalışmaz:** "Sıra No" (veya market/
  toptancı fişlerinde EAN barkod) kavramı hiç olmayan bazı belge türlerinde
  (GSM/internet hat detaylı telekom faturaları gibi) veya metin katmanı
  olmayan taranmış PDF'lerde kalem tablosu bulunamaz — bu durumda
  "Bulunamadı" gösterilir, ana QR/regex okuması bundan etkilenmez. Bazı
  vendor'larda kalem toplamının karekoddaki "Mal/Hizmet Tutarı" ile birebir
  eşleşmemesi (iskonto öncesi/sonrası veya KDV dahil/hariç fiyatlandırma
  farkı gibi) gerçek bir muhasebe nüansı olabilir, illa hata anlamına gelmez.
- **Kalem tablosu, e-SMM (Serbest Meslek Makbuzu) için tasarlanmadı:**
  Özellik "Sıra No" tablolu **e-Fatura** için geliştirilip test edildi.
  e-SMM makbuzlarının tablo yapısı tamamen farklı (Brüt Ücret / Net Ücret /
  Net Tahsilat, hiç "Tutar" sütunu yok) ve bazı vendor'larda özet metni veri
  satırına karışıp kalem tablosunu bozuk gösterebilir. e-SMM'nin kendi
  matematiksel doğrulaması (bkz. yukarıdaki kurallar) zaten doğrudan QR
  verisinden çalışıyor ve bundan etkilenmez — kalem tablosu e-SMM'de
  yalnızca "bonus" bir gösterimdir, ana sonucu etkilemez.

---

## Katkı ve gizlilik

- **Gerçek fatura PDF'i commit etmeyin.** `.gitignore` tüm `*.pdf`'i ve
  `ornek_pdfler_e-smm/`, `Örnek faturalar/` klasörlerini engeller —
  gene de PR açmadan önce kontrol edin.
- Test için sentetik / anonim PDF kullanın (uydurma VKN: `1111111111`,
  uydurma isimler).
- Yeni bir QR şeması varyantı bulursanız [docs/qr-semalari.md](docs/qr-semalari.md)'ye
  ekleyin — asıl kıymet bu bilgide.

## Kullanılan üçüncü taraf bileşenler

| Bileşen | Lisans | Kullanım |
|---|---|---|
| [pdf.js](https://github.com/mozilla/pdf.js) | Apache-2.0 | PDF render + metin çıkarma |
| [jsQR](https://github.com/cozmo/jsQR) | Apache-2.0 | QR okuma (yedek motor) |
| [zxing-wasm](https://github.com/zxing-js/zxing-wasm) | MIT / Apache-2.0 | QR okuma (birincil motor) |

## Lisans

[MIT](LICENSE)
