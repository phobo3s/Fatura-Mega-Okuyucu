# Fatura Modeli ve Özet Kutusu

Bu belge, uygulamanın bir faturayı **nasıl parçalara ayırdığını** ve özellikle
faturanın altındaki **özet kutusunu** (Mal/Hizmet, İskonto, KDV, Vergiler Dahil,
Ödenecek...) nasıl okuyup doğruladığını anlatır. Kodu okumadan önce bunu okuyun.

İçindekiler: [1. Model](#1-fatura-üç-öğeden-oluşur) ·
[2. Kaynak önceliği](#2-toplamlar-nereden-gelir) ·
[3. Özet nasıl okunur](#3-özet-kutusu-nasıl-okunur) ·
[4. Etiket kataloğu](#4-etiket-kataloğu) ·
[5. Bağıntılar](#5-bağıntılar-çift-anlamlı-sayıyı-hesapla-çözmek) ·
[6. Yabancı para birimi](#6-yabancı-para-birimli-faturalar) ·
[7. Satıra uygulama](#7-satıra-uygulama-ve-doğrulama) ·
[8. Nasıl ölçtük](#8-nasıl-ölçtük) ·
[9. Sınırlamalar](#9-bilinen-sınırlamalar) ·
[10. Kodda nerede](#10-kodda-nerede) ·
[11. Yeni etiket ekleme](#11-yeni-etiket-ekleme-rehberi)

---

## 1. Fatura üç öğeden oluşur

| Öğe | İçerdiği | Nereden okunur | Kod |
|---|---|---|---|
| **Kimlik** | fatura no, tarih, VKN, ETTN, senaryo, tip | karekod, yoksa regex | `tryExtractViaQr`, `tryExtractViaRegex` |
| **Kalemler tablosu** | ürün/hizmet satırları | sayfa metni + çizgiler | `detectLineItemTable` |
| **Özet kutusu** | Mal/Hizmet, iskonto, KDV, Vergiler Dahil, Ödenecek | sayfa metni (etiket + değer) | `extractSummaryBlock` |

Üçü birbirinden bağımsız okunur; bu yüzden biri başarısız olsa diğerleri çalışır.

## 2. Toplamlar nereden gelir

Toplam tutarlar (Mal/Hizmet, Vergiler Dahil, Ödenecek, oranlı KDV, para birimi)
için öncelik sırası:

1. **Karekod** — varsa her zaman esas alınır, özet ona **asla dokunmaz**.
2. **Özet kutusu** — karekod yoksa.
3. **Regex** — yedek. Özet bir alanı bulamadıysa regex'in okuduğu değer kalır.

Özet ile regex **çelişirse** özet esas alınır ve doğrulama kutusunda sarı ⚠ ile
"regex X → özet Y" diye belirtilir (sessiz değil). **Kimlik alanları** özetten
gelemez; karekod yoksa regex'ten gelir.

## 3. Özet kutusu nasıl okunur

- Kutu **çizgiyle değil metinle** bulunur: bir satırda en sağdaki tutar *değer*,
  solunda kalan metin *etiket*tir. (Çizgi tespiti bu projede defalarca dekoratif
  alt çizgilere takıldı; metin çok daha güvenilir.)
- Etiket bir **anahtara** indirgenir: büyük harf, Türkçe harfler katlanmış
  (Ö→O, İ→I...), boşluk/noktalama/`%oran` silinmiş.
  `"Toplam İskonto :"` → `TOPLAMISKONTO`. Bu sayede `"Ödenecek Tutar :"`,
  `"ÖDENECEK TUTAR"`, `"Ödenecek Tutar (TL)"` hepsi aynı anahtardır.
- Aynı alan birden çok yerde geçerse **en alttaki (son) satır** kazanır; özet
  her zaman faturanın altındadır.
- Tutarın yanındaki `TL`/`EUR` birimi de okunur (bkz. [6](#6-yabancı-para-birimli-faturalar)).

## 4. Etiket kataloğu

Katalog 360 dosyalık gerçek korpustan çıkarıldı ve her etiket **karekodun gerçek
tutarlarıyla** karşılaştırılarak doğrulandı.

### 4a. Tek anlamlı etiketler (etiket bakılarak rol verilir)

| Etiket (örnekler) | Rol |
|---|---|
| Toplam İskonto, İskonto, İndirim Tutarı | İskonto |
| Fatura Yuvarlama Farkı, Yuvarlama | Yuvarlama |
| Mal Hizmet Toplam Tutarı | Mal/Hizmet |
| Vergiler Dahil Toplam Tutar, Toplam Fatura Tutarı | Vergiler Dahil |
| Ödenecek Tutar, Ödenecek Toplam | Ödenecek |
| Hesaplanan KDV (%20) | KDV (oran bazında) |
| Hesaplanan KDV Tevkifat (%90) | KDV Tevkifat (oran bazında) |
| KDV Matrahı (%20) | Matrah (oran bazında) — bağıntılar için çıpa |

### 4b. Çift / belirsiz anlamlı etiketler (rolü hesapla çözülür)

Aynı sözcük farklı yazılımlarda farklı şey demektir. En bilinen örnek
**"Toplam Tutar"**: korpusta 13 faturada geçiyor; 10'unda KDV **hariç** (yani
Mal/Hizmet), 3'ünde KDV **dahil**. "Hep Mal/Hizmet say" kuralı %23 yanlış dolu
tutar üretirdi; yanlış dolu tutar boş tutardan kötüdür.

Bu etiketlerin **tutarı aday olarak** alınır, rolü [bağıntılarla](#5-bağıntılar-çift-anlamlı-sayıyı-hesapla-çözmek)
belirlenir: `Toplam Tutar`, `Ara Toplam`, `Vergi Hariç Tutar`, `KDV Matrah Tutarı`,
`Net Tutar`, `Satış Tutarı`, `Genel Toplam`.

## 5. Bağıntılar: çift anlamlı sayıyı hesapla çözmek

Karekod gerekmez; bağıntılar faturanın **kendi basılı sayıları** arasındadır:

```
B1  Matrah          = Mal/Hizmet − İskonto
B2  KDV (oran)      = Matrah × oran        ⇒   Matrah = Σ KDV ÷ oran
B3  Vergiler Dahil  = Matrah + KDV
```

(`Ödenecek = Vergiler Dahil − Tevkifat` burada kullanılmaz: bazı yazılımlar
"Vergiler Dahil"i tevkifat düşülmüş basar, bu yüzden belirsizdir.)

**Yöntem.** Kesin etiketlerden (KDV + oran, basılı matrah, Vergiler Dahil)
*beklenen* değerler türetilir. Bir aday tutar bunlardan biriyle eşleşirse rolünü alır:

| Aday tutar eşitse | Rolü |
|---|---|
| beklenen **matrah** (İskonto yok) | KDV hariç tutar = **Mal/Hizmet** |
| beklenen **matrah** (İskonto var) | Matrah. Mal/Hizmet **tahmin edilmez**, boş kalır |
| beklenen matrah **+ iskonto** | **Mal/Hizmet** (iskonto öncesi brüt) |
| beklenen **Vergiler Dahil** | **Vergiler Dahil** |
| hiçbiri | **rol verilmez, alan boş kalır** |

Kesin etiketle zaten bulunmuş alanın üzerine **yazılmaz**. Tolerans `VALIDATION_EPS`
(0,05 — kuruş yuvarlaması).

### Örnekler (uydurma sayılar, gerçek örneklerin biçimi)

**A. KDV oransız basılmış, Vergiler Dahil var**
```
Toplam Tutar                  7.630,31     ← rolü belirsiz
Hesaplanan KDV                  979,69
Vergiler Dahil Toplam Tutar   8.610,00     ← kesin
```
`8.610,00 − 979,69 = 7.630,31` ⇒ "Toplam Tutar" **KDV hariç = Mal/Hizmet**.

**B. Sadece KDV(%20) kesin, gerisi belirsiz (EUR'lu fatura)**
```
Satış Tutarı                 44.835,55
Net Tutar                    44.835,55
Hesaplanan KDV (%20)          8.967,11     ← kesin
Toplam Tutar                 53.802,66
```
`8.967,11 ÷ 0,20 = 44.835,55` ⇒ "Satış Tutarı" = **Mal/Hizmet**;
`44.835,55 + 8.967,11 = 53.802,66` ⇒ "Toplam Tutar" = **Vergiler Dahil**.
Aynı "Toplam Tutar" sözcüğü A'da KDV hariç, B'de KDV dahil çıktı; bağıntı ikisini de doğru ayırdı.

**C. İskontolu**
```
Toplam Tutar                 13.810,00
Toplam İskonto                  448,83
Hesaplanan KDV (%20)          2.672,23
Vergiler Dahil Toplam Tutar  16.033,40
```
Beklenen matrah = `16.033,40 − 2.672,23 = 13.361,17`; `13.361,17 + 448,83 = 13.810,00`
⇒ "Toplam Tutar" iskonto öncesi brüt = **Mal/Hizmet**.

Hangi satırın hangi bağıntıyla çözüldüğü **👁 Özet kutusunda nereden okundu?**
görselinde "(bağıntıyla)" etiketiyle ve altında açıklamasıyla gösterilir.

## 6. Yabancı para birimli faturalar

Yabancı para birimli faturada özet **iki blok** basar: önce fatura biriminde
(EUR/USD), altında **TL karşılığı**. "Son satır kazanır" kuralı TL bloğunu seçip
tutarları ~50 kat büyütüyordu (1.200 → 61.287,96). Bu yüzden:

1. Belgenin birimi bulunur: TRY dışı en sık görülen birim (yoksa TL/birimsiz belge).
2. Yabancı belgede her alan için **yalnızca o birimdeki** satır alınır; o birimde
   satırı olmayan alan (ör. sadece TL bloğunda basılan iskonto) atlanır — birim karıştırılmaz.
3. Birim, değerin yanındaki `EUR`/`TL` parçasından ya da etiketteki `(TL)` ekinden okunur.

## 7. Satıra uygulama ve doğrulama

- **Karekodsuz (Regex) e-Fatura satırı** (`applySummaryTotalsToRegexRow`): Mal/Hizmet,
  Vergiler Dahil, Ödenecek, `Hesaplanan KDV (%oran)` ve boşsa Para Birimi özetten yazılır.
  Regex farklı değer okuduysa özet esas alınır, `row.summaryOverrides`'a not düşülür
  (`checkOzetKaynagi` sarı ⚠). İşlem idempotenttir. KDV anahtarı büyük/küçük harften
  bağımsız eşleştirilir (regex `HESAPLANAN KDV (%20)` yazmış olabilir; yoksa çift sütun açılıp
  KDV iki kez sayılırdı).
- **Karekodlu satır:** özet sadece *ek bilgi* verir (Toplam İskonto sütunu, iskonto
  kontrolü); karekodun hiçbir değerini ezmez. e-SMM'de özet modülü kapalıdır.
- **Kural 1** (`checkVergiDahilToplam`): karekodlu satırda taban KDV Matrahı'dır
  (iskonto düşülmüş). Karekodsuzda matrah yoktur, taban Mal/Hizmet olur; iskontolu
  faturada bu iskonto öncesi brüt olduğundan fark tam iskonto kadar çıkıp yanlış
  kırmızı üretirdi. Bu yüzden özetten okunan iskonto varsa `Mal/Hizmet − İskonto`
  da denenir.

## 8. Nasıl ölçtük

**Kural: bir yöntemi diğer yöntemin çıktısına değil, GERÇEĞE karşı ölç.**
Karekodsuz satırlarda gerçek değer yok (49 dosya, çoğunda ikisi de boş) ve küçük
örneklem yanıltır. Bunun yerine **karekodlu satırlardan karekodu gizledik**:
her dosyada `tryExtractViaRegex` + `extractSummaryBlock` çalıştırıldı, sonuç kayıtlı
karekod değerleriyle karşılaştırıldı; her alan *doğru / yanlış / boş* sayıldı.
En önemli ölçüt **yanlış dolu tutar sayısı** (boş bırakmak kabul, yanlış doldurmak değil).

280 e-Fatura, karekod gizli:

| | Yalnız regex | Özet + bağıntı |
|---|---|---|
| Mal/Hizmet doğru | 213 | **231** |
| Vergiler Dahil doğru | 214 | **232** |
| Mal/Hizmet yanlış dolu | 0 | **0** |
| Oranlı KDV doğru (312 içinde) | 114 | **212** |
| Yanlış kırmızı ✗ (karekodda kırmızı olmayıp burada kırmızı) | 27 | **1** |

Tuzaklar (yaşanmış): (1) yöntemi zaten hatalı bir tabana (yalnız regex) karşı
ölçmek "yeni hata yok" gösterip asıl sorunu (iskontolu faturada yanlış kırmızı)
gizledi; (2) gerçek korpus tek biçimi kanıtlayamaz — uydurma PDF (büyük harfli
`HESAPLANAN KDV` etiketi) çift KDV sütunu hatasını yakaladı; (3) "sütun sayısı değişti"
regresyon kanıtı değildir, altındaki veriyi karşılaştırın.

## 9. Bilinen sınırlamalar

- **İki belgeli PDF:** bir PDF'te iki ayrı fatura varsa (ör. sayfa 1 e-Fatura yansıması,
  sayfa 2 e-Arşiv) karekod/regex sayfa 1'i, özet "son satır kazanır" ile sayfa 2'yi okur.
  Çelişki sarı ⚠ ile gösterilir. Korpusta 1/280.
- **Vergiler Dahil'i tevkifat düşülmüş basan yazılım:** karekod tam tutarı verir,
  basılı tutar farklıdır; karekodsuzda Ödenecek kontrolü kırmızı verir. Korpusta 1/280.
- **Kalemler birden fazla sayfaya taşarsa** kalem tablosu sadece ilk sayfayı okur
  (kalem kontrolü ⚠ verir; sessiz yanlış ✓ değil).
- **Karekodsuz e-SMM:** özet modülü e-SMM'de kapalı; toplamlar sadece e-SMM regex kurallarından.
- **Tanınmayan etiket + hiçbir bağıntı tutmuyor:** alan boş kalır (bilerek).
- Regex bazen `Ödenecek` tutarını yanlış okur (ör. `1.482,90` → `1.4829`); özet bu alanı
  bulamazsa düzeltilemez. Ayrı bir regex işidir.

## 10. Kodda nerede

Hepsi `FaturaMegaOkuyucu.html` içinde. Ana modül tek blok, başında **haritası** var
(`ÖZET KUTUSU MODÜLÜ`):

| Parça | Yer |
|---|---|
| Okuma yardımcıları (`foldTRKey`, `groupItemsIntoLines`, `splitLabelValue`) | modül, bölüm 1 |
| Etiket kataloğu (`SUMMARY_FIELDS`, `SUMMARY_AMBIGUOUS_LABELS`) | modül, bölüm 2 |
| Okuyucu (`extractSummaryBlock`) | modül, bölüm 3 |
| Bağıntılar (`resolveAmbiguousAmounts`) | modül, bölüm 4 |
| Satıra uygulama (`applySummaryFields`, `applySummaryTotalsToRegexRow`) | `finalizeRows`'un yanı |
| Kaynak notu (`checkOzetKaynagi`), Kural 1 (`checkVergiDahilToplam`) | doğrulayıcılar |
| Görsel doğrulama (`drawSummaryLine`, `openSummaryVisual`) | kalem modalı |

## 11. Yeni etiket ekleme rehberi

1. Etiketin **anahtarını** bulun (`foldTRKey("Toplam Fatura Tutarı")` → `TOPLAMFATURATUTARI`).
2. **Tek anlamlı mı?** Karekodlu birkaç faturada etiketin yanındaki tutarı karekodla karşılaştırın;
   *hep* aynı alana eşitse `SUMMARY_FIELDS`'a ekleyin.
3. Bazen bir alana, bazen başka alana eşitse `SUMMARY_AMBIGUOUS_LABELS`'a ekleyin
   (rolünü bağıntı çözer; yanlış doldurmaz).
4. Ölçün: karekodu gizleyip (bkz. [8](#8-nasıl-ölçtük)) doğru sayısı artıyor mu,
   **yanlış dolu tutar** oluşuyor mu, yeni yanlış kırmızı var mı bakın.
5. Sonucu bu belgedeki ilgili tabloya işleyin.
