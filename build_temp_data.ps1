# Fatura Mega Okuyucu - launcher yardimci scripti
# mega_launcher.bat tarafindan cagirilir. Iki isi var:
#   1) mega_config.json'i her zaman temp_config.js'e tazeler (regex kurallari)
#   2) Argumanla dosya gecildiyse (Gonder menusu / surukle-birak disi) her birini
#      base64'e cevirip temp_files.js'e yazar (uygulama bunlari otomatik isler)
#
# NOT (denendi, geri alindi): Path-tabanli fetch()/XHR + msedge
# --allow-file-access-from-files yaklasimini denedik - gercek makinede hem
# fetch() hem XMLHttpRequest ayni "engellendi" hatasini verdi (surec tam
# kapatilip acilsa bile) - muhtemelen kurumsal Edge politikasi bunu
# engelliyor. Base64 gomme, hicbir tarayici bayragina ihtiyac duymadigi icin
# daha guvenilir - bu yuzden buraya geri donduk.

param(
    [Parameter(Mandatory = $true)][string]$AppDir,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Files
)

$ErrorActionPreference = 'Stop'

# --- 1) Config'i tazele ---
$configPath = Join-Path $AppDir 'mega_config.json'
if (Test-Path -LiteralPath $configPath) {
    $configJson = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
} else {
    $configJson = 'null'
}
$configOut = Join-Path $AppDir 'temp_config.js'
Set-Content -LiteralPath $configOut -Value "window.MEGA_CONFIG_DEFAULT = $configJson;" -Encoding UTF8

# --- 2) Dosyalar gecildiyse temp_files.js yaz ---
# PERFORMANS NOTU: cok dosyada ("Gonder" ile 50-300 fatura secilince) eski kod
# gozle gorulur yavasti - olcup iki gercek nedeni bulduk:
#   1) "$items += [PSCustomObject]@{...}" bir dongu icinde: PowerShell dizileri
#      DEGISTIRILEMEZ (immutable), += her seferinde TÜM diziyi yeniden kopyalar
#      -> O(n^2). 304 dosyada bu tek satir 4,5 saniye tutuyordu (List[object]'e
#      gecince 0,5 saniyeye dustu - olculdu).
#   2) ConvertTo-Json, genel amacli/yansimali (reflection) bir serilestirici -
#      onlarca MB'lik base64 metnini elle string kurmaktan belirgin yavas
#      isliyor. Burada JSON seklimiz sabit ve basit oldugu icin elle kuruyoruz.
#      base64 metni zaten SADECE [A-Za-z0-9+/=] icerir - JSON'da kacis
#      (escape) gerektiren hicbir karakter YOK, sadece dosya adini kaciyoruz.
function Escape-JsonString {
    param([string]$s)
    $s = $s -replace '\\', '\\'
    $s = $s -replace '"', '\"'
    $s = $s -replace "`r", '\r'
    $s = $s -replace "`n", '\n'
    $s = $s -replace "`t", '\t'
    return $s
}

if ($Files -and $Files.Count -gt 0) {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $Files) {
        if (Test-Path -LiteralPath $f -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($f)
            $b64 = [Convert]::ToBase64String($bytes)
            $fn = [System.IO.Path]::GetFileName($f)
            $items.Add(@{ fileName = $fn; b64 = $b64 })
        }
    }

    if ($items.Count -gt 0) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('[')
        for ($i = 0; $i -lt $items.Count; $i++) {
            if ($i -gt 0) { [void]$sb.Append(',') }
            [void]$sb.Append('{"fileName":"')
            [void]$sb.Append((Escape-JsonString $items[$i].fileName))
            [void]$sb.Append('","b64":"')
            [void]$sb.Append($items[$i].b64)
            [void]$sb.Append('"}')
        }
        [void]$sb.Append(']')
        $json = $sb.ToString()

        $filesOut = Join-Path $AppDir 'temp_files.js'
        Set-Content -LiteralPath $filesOut -Value "window.MEGA_FILES = $json;" -Encoding UTF8
    }
}
