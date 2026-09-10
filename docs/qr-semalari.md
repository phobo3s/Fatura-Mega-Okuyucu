# Türk e-Belge Karekod (QR) Şemaları

GİB'in karekod standardı asgari düzeyde tanımlıdır; **yazılım firmasına göre
alan isimleri, sayısı ve içeriği ciddi şekilde değişir.** Bu belge, gerçek
faturalarla test edilerek keşfedilen şema varyantlarını ve tuzakları
belgeler. Yeni bir varyantla karşılaşırsanız buraya ekleyin.

Uygulamada QR payload'ı `parseQrPayload()` ile ayrıştırılır (önce `JSON.parse`,
olmazsa `"anahtar":"değer"` çiftlerini regex ile yakalama, en son `|`/`&`/satır
ayraçlı `key:value`). Anahtarlar `norm()` ile normalize edilir:
boşluk/alt çizgi silinir, küçük harfe çevrilir (`VknTckn` → `vkntckn`).

---

## 1. e-Fatura / e-Arşiv (ticari fatura)

Tipik payload (JSON):

```json
{
  "vkntckn": "1111111111",
  "avkntckn": "2222222222",
  "senaryo": "TEMELFATURA",
  "tip": "SATIS",
  "tarih": "2026-01-15",
  "no": "ABC2026000000123",
  "ettn": "00000000-0000-0000-0000-000000000000",
  "parabirimi": "TRY",
  "malhizmettoplam": "10000.00",
  "vergidahil": "12000.00",
  "odenecek": "12000.00",
  "hesaplanankdv(20)": "2000.00",
  "kdvmatrah(20)": "10000.00"
}
```

### Sabit alanlara eşlenen anahtarlar

| Uygulama alanı | Aranan anahtar örüntüleri (normalize edilmiş) |
|---|---|
| Fatura No | `no`, `faturano` |
| Tarih | `tarih` (ISO `YYYY-MM-DD` → `DD-MM-YYYY`'ye çevrilir) |
| VKN/TCKN (Satıcı) | `vkntckn` |
| VKN/TCKN (Alıcı) | `avkntckn` |
| Senaryo | `senaryo` |
| Fatura Tipi | `tip` |
| Para Birimi | `parabirimi` |
| Mal/Hizmet Tutarı | `malhizmet`, `malhizmettoplam` |
| Vergiler Dahil Toplam | `vergidahil` |
| Ödenecek Tutar | `odenecek` |
| ETTN | `ettn` |

### Dinamik (oranlı) alanlar

Sabit alana eşlenmeyen ve içinde `kdv` / `tutar` / `matrah` geçen her anahtar,
`(%oran)` son ekiyle kendi sütununa dönüşür:

- `hesaplanankdv(20)` → **Hesaplanan KDV (%20)**
- `hesaplanankdvtevkifat(20)` → **Hesaplanan KDV Tevkifat (%20)**
- `kdvmatrah(20)` → **KDV Matrahı (%20)**
- `(20.0)`, `(20.00)`, `(20)` yazımları tek biçime indirgenir → `(%20)`

Özel vergiler de tanınır ama **hiçbir doğrulama formülüne katılmaz**:
`oiv` / `ozeliletisim` → ÖİV, `konaklama` → Konaklama Vergisi,
`damga` → Damga Vergisi, `otv...` → ÖTV.

### ⚠ Tuzak: "Hesaplanan KDV" net mi, tam mı?

Tevkifatlı faturalarda `hesaplanankdv(oran)` alanının değeri **yazılıma göre
değişir**:

- **Kimi yazılım:** tevkifat **sonrası net** KDV yazar
  (`matrah × oran − tevkifat`).
- **Kimi yazılım:** tevkifat **öncesi tam** KDV yazar (`matrah × oran`).

Ayırt edecek güvenilir bir işaret yok. Uygulama bunu şöyle çözer:

- Tevkifat tutarını **`Vergiler Dahil Toplam − Ödenecek Tutar`** üzerinden
  türetir (yazılımdan bağımsız, her koşulda doğru).
- Doğrulama kuralları (Kural 1 ve 3) **iki yorumu da** dener, hangisi
  tutuyorsa onu geçerli sayar.

### ⚠ Tuzak: sayı formatı

Çoğu yazılım İngilizce format gönderir (`"2500.00"`), ama bazıları Türkçe
format kullanır (`"2.500,00"`). `parseFlexibleAmount()` şu kuralı uygular:
**en sonda görülen ayraç (`.` veya `,`) ondalık ayracıdır.**

### ⚠ Tuzak: sızmış boşluk / kontrol karakteri

Bazı yazılımlar QR metnine ham `\t` / `\n` sızdırır
(`"malhizmettoplam":"0\n\t\t"`) veya değer başına boşluk koyar
(`" 15-01-2026"`). `parseQrPayload` kontrol karakterlerini temizler,
alan okuyucular `.trim()` uygular.

### ⚠ Tuzak: karekod ilk sayfada olmayabilir

Çok sayfalı faturalarda QR 2. (hatta sonraki) sayfada olabilir. Uygulama
tüm sayfaları dener (bir sayfa tamamen başarısız olursa sonrakine geçer).

---

## 2. e-SMM (Serbest Meslek Makbuzu)

**e-Fatura'dan tamamen farklı bir belge türü.** Sadece mali müşavirler değil,
avukatlar dahil hizmetini serbest meslek makbuzuyla belgeleyen herkes bu türe
girer. Kavramlar farklı: "Mal/Hizmet" yerine **Brüt Ücret**, "KDV Matrahı"
yerine **G.V. Stopaj** (gelir vergisi kesintisi — KDV'den tamamen ayrı),
ayrıca **Net Ücret**, **KDV Tevkifatı**, **Net Tahsilat**.

Uygulama e-SMM'i şu işaretlerden tanır (`isEsmmPayload`):
- `tur` alanı `"e-SMM"` içeriyor, **veya**
- şu anahtarlardan biri var: `brutucret`, `netucret`, `gvstopaj`,
  `kdvtevkifat`, `tahsilkdv` (e-Fatura QR'ında bunlar hiç geçmez).

e-SMM satırları tabloda **`Serbest Meslek`** rozetiyle işaretlenir ve
e-Fatura doğrulama kuralları (Kural 1/2/3) yerine kendi kuralları uygulanır.

### Varyant 1 — minimal

```json
{
  "tur": "e-SMM",
  "ETTN": "00000000-0000-0000-0000-000000000000",
  "no": "ABC2026000000197",
  "tarih": " 15-01-2026",
  "net": "13.486,03",
  "tahsilat": "16.857,54",
  "VKNTCKN": "1111111111"
}
```

- Sadece **net ücret** (stopaj sonrası) ve **net tahsilat** (KDV dahil toplam
  tahsil edilen) var.
- KDV / stopaj kırılımı **yok**, **alıcı VKN'si yok**.
- Doğrulama yapılamaz — alanlar yalnızca bilgi amaçlı gösterilir.
- `tarih` değerinde baştaki boşluğa dikkat (`" 15-01-2026"`).

### Varyant 2 — detaylı

```json
{
  "no": "ABC2026000000718",
  "avkntckn": "2222222222",
  "ettn": "00000000-0000-0000-0000-000000000000",
  "brutucret": "2500.00",
  "kdvtutari": "500.00",
  "kdvtevkifat": "0.00",
  "tahsilkdv": "500.00",
  "gvstopaj": "500.00",
  "netucret": "2000.00",
  "tahsilat": "2500.00",
  "vkntckn": "1111111111",
  "parabirimi": "TRY",
  "tarih": "2026-01-15"
}
```

- Tam kırılım var; **`tur` alanı yok** — tanıma anahtar isimlerinden yapılır.
- `avkntckn` (alıcı VKN'si) burada var.

| Anahtar | Anlamı |
|---|---|
| `brutucret` | Brüt Ücret Tutarı |
| `kdvtutari` | KDV Tutarı (brüt ücret × KDV oranı) |
| `gvstopaj` | Gelir Vergisi Stopajı (brüt ücret × stopaj oranı, genelde %20) |
| `netucret` | Net Ücret = Brüt Ücret − G.V. Stopaj |
| `kdvtevkifat` | KDV Tevkifatı (kurumsal-serbest meslek ilişkisinde genelde 0) |
| `tahsilkdv` | Tahsil Edilen KDV = KDV Tutarı − KDV Tevkifatı |
| `tahsilat` | Net Tahsilat = Net Ücret + Tahsil Edilen KDV |

### Doğrulama kuralları (yalnızca Varyant 2)

```
KDV Tutarı − KDV Tevkifatı        = Tahsil Edilen KDV
Brüt Ücret − G.V. Stopaj Tutarı   = Net Ücret
Net Ücret  + Tahsil Edilen KDV    = Net Tahsilat
```

### Sabit sütun eşlemesi (e-SMM)

| Uygulama alanı | Kaynak |
|---|---|
| Mal/Hizmet Tutarı | `brutucret` (en yakın kavramsal karşılık) |
| Vergiler Dahil Toplam | `brutucret + kdvtutari` (stopaj/tevkifat öncesi) |
| Ödenecek Tutar | `tahsilat` (yoksa `net`) |
| Fatura Tipi | sabit: `SERBEST MESLEK MAKBUZU` |

### e-SMM metin (regex) katmanı

QR yoksa, metinde "Serbest Meslek Makbuzu" ibaresi varsa
`extractEsmmFields()` devreye girer. e-Fatura'dan farklı etiketler arar
(`build_temp_data.ps1` içindeki kurallardan bağımsız, sol panelde
"Serbest Meslek Makbuzu Kuralları" olarak düzenlenebilir):

| Etiket | Karşılığı |
|---|---|
| `Belge Numarası` | Fatura No (e-Fatura'daki "Fatura No" değil!) |
| `Brüt Ücret Tutarı` | brutucret |
| `KDV Tutarı` | kdvtutari |
| `G.V Stopaj Tutarı` | gvstopaj (dikkat: "G.V" — nokta bir tane) |
| `Net Ücret Tutarı` | netucret |
| `KDV Tevkifatı Tutarı` | kdvtevkifat |
| `Tahsil Edilen KDV Tutarı` | tahsilkdv |
| `Net Tutar` | tahsilat |

---

## Test payload'ları

`ornekler/` klasöründe sentetik (uydurma VKN/isim) örnek payload'lar var.
Bunları herhangi bir QR üreticiye verip PDF'e basarak uygulamayı
deneyebilirsiniz.
