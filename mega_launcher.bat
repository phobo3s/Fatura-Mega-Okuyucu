@echo off
setlocal enabledelayedexpansion

set "DIR_PATH=%~dp0"
set "HTML_PATH=%DIR_PATH%FaturaMegaOkuyucu.html"
set "LOG_PATH=%DIR_PATH%launcher_error.log"

:: ONEMLI: DIR_PATH sonu "\" ile bitiyor. Bunu dogrudan "%DIR_PATH%" seklinde
:: tirnaklayip PowerShell'e argüman olarak gecersek, sondaki \" ikilisi Windows'un
:: komut satiri ayristiricisi tarafindan "kacisli tirnak" sanilir ve tirnak hic
:: kapanmaz (klasik Win32 argv tuzagi). Bu yuzden tirnaklanacak her yerde sondaki
:: ters slash'i once temizliyoruz.
set "APP_DIR_NOSLASH=%DIR_PATH:~0,-1%"

:: Config'i her acilista tazele (dosya gecilsin gecilmesin); dosya varsa
:: temp_files.js de bu ayni cagriyla uretiliyor.
del "%LOG_PATH%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR_NOSLASH%\build_temp_data.ps1" -AppDir "%APP_DIR_NOSLASH%" %* 2>"%LOG_PATH%"

if errorlevel 1 (
    echo.
    echo [HATA] build_temp_data.ps1 calisirken bir sorun olustu:
    echo ------------------------------------------------------------
    type "%LOG_PATH%"
    echo ------------------------------------------------------------
    echo Bu pencereyi kapatmak icin bir tusa basin.
    pause >nul
    exit /b 1
)

:: NOT (denendi, geri alindi): --allow-file-access-from-files ile PDF'leri
:: fetch()/XHR'la dogrudan yol uzerinden okumayi denedik - gercek makinede
:: (kurumsal Edge politikasi olasi) her ikisi de engellendi. base64 gomme
:: hicbir tarayici bayragina ihtiyac duymadigi icin daha guvenilir.
if "%~1"=="" (
    start "" msedge --app="file:///%HTML_PATH%"
) else (
    start "" msedge --app="file:///%HTML_PATH%?auto=1"
)
