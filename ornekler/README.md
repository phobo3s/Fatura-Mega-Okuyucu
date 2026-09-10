# Örnek karekod payload'ları

Bu klasördeki `.json` dosyaları **tamamen sentetiktir** — uydurma VKN
(`1111111111`), uydurma ETTN, uydurma tutarlar. Uygulamayı gerçek fatura
kullanmadan denemek için.

| Dosya | Tür |
|---|---|
| `e-fatura-satis.json` | e-Fatura, normal satış (tevkifatsız) |
| `e-fatura-tevkifatli.json` | e-Fatura, %90 (9/10) KDV tevkifatlı |
| `e-smm-minimal.json` | e-SMM Varyant 1 (sadece net + tahsilat) |
| `e-smm-detayli.json` | e-SMM Varyant 2 (tam kırılım) |

Matematiği doğru kurgulandı — dördü de uygulamada yeşil ✓ vermeli.

## Test PDF'ine dönüştürme

Uygulama PDF beklediği için payload'ı bir karekoda çevirip PDF'e basmanız
gerekir. Birkaç yol:

**Çevrimiçi (en kolay):** Payload metnini herhangi bir "text to QR"
üreticiye yapıştırın, QR görselini bir Word/Docs sayfasına koyup PDF olarak
kaydedin.

**qrencode (Linux/macOS/WSL):**
```bash
qrencode -o e-fatura-satis.png -r ornekler/e-fatura-satis.json
# sonra PNG'yi bir PDF'e gömün (ör. img2pdf e-fatura-satis.png -o test.pdf)
```

**Python:**
```python
import qrcode
qrcode.make(open("ornekler/e-fatura-satis.json").read().strip()).save("qr.png")
```

**Not:** Uygulama karekodu sayfanın herhangi bir yerinde bulur ama önce
üst köşeleri tarar — QR'ı sayfanın üst kısmına koyarsanız en hızlı sonucu
alırsınız.
