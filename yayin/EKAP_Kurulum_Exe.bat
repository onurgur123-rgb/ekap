@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ==========================================================================
rem  EKAP Izleyici - Kurulum (derlenmis .exe surumu)
rem
rem  Tek dosya kurulum: karsi tarafa yalnizca bu dosya gonderilir.
rem  Python GEREKMEZ. Paket GitHub Releases'tan indirilir, surum.json'daki
rem  sha256 ile karsilastirilir, C:\EKAP Izleyici klasorune acilir.
rem  Ayni klasorde eski (.py) kurulum varsa kayitlar ve ayarlar KORUNUR,
rem  yalnizca eski program dosyalari kaldirilir.
rem
rem  Yonetici izni: C:\ altina yazmak ve Tesseract/7-Zip kurmak icin.
rem ==========================================================================

set "PAKET_ADRESI=https://github.com/onurgur123-rgb/ekap/releases/latest/download/EKAP_Izleyici_Exe.zip"
set "SURUM_ADRESI=https://raw.githubusercontent.com/onurgur123-rgb/ekap/main/yayin/surum.json"
set "HEDEF=C:\EKAP Izleyici"

rem Parametreler (hepsi istege bagli):
rem   /hedef "klasor"  kurulum klasoru (eski kurulumun yerinde gecis icin)
rem   /sessiz          sonda programi acma, tusa basmayi bekleme
rem   /yukseltildi     yonetici olarak yeniden acildi (ic kullanim)
rem   /yetkisiz        yonetici izni isteme (test; yazilabilir klasore kurar)
rem   /kisayolsuz      masaustu kisayolu olusturma (test)
set "YUKSELTILDI=0"
set "SESSIZ=0"
set "YETKISIZ=0"
set "KISAYOLSUZ=0"
:arg
if "%~1"=="" goto argbitti
if /i "%~1"=="/yukseltildi" set "YUKSELTILDI=1"
if /i "%~1"=="/sessiz" set "SESSIZ=1"
if /i "%~1"=="/yetkisiz" set "YETKISIZ=1"
if /i "%~1"=="/kisayolsuz" set "KISAYOLSUZ=1"
if /i "%~1"=="/hedef" (
    set "HEDEF=%~f2"
    shift
)
shift
goto arg
:argbitti

echo.
echo ==========================================================
echo    EKAP Izleyici - Kurulum
echo    (c) 2026 Onur Gur. Tum haklari saklidir.
echo ==========================================================
echo.

if "%YETKISIZ%"=="1" goto yetki_tamam
net session >nul 2>&1
if errorlevel 1 (
    if "%YUKSELTILDI%"=="1" (
        echo  [HATA] Yonetici yetkisi alinamadi.
        echo  Dosyaya sag tiklayip "Yonetici olarak calistir" deneyin.
        echo.
        pause
        exit /b 1
    )
    echo  Yonetici izni isteniyor...
    powershell -NoProfile -Command ^
      "try { Start-Process -FilePath '%~f0' -ArgumentList '/yukseltildi','/hedef','\"%HEDEF%\"' -Verb RunAs; exit 0 } catch { exit 1 }"
    if errorlevel 1 (
        echo  [HATA] Izin verilmedi; kurulum yapilamaz.
        echo.
        pause
    )
    exit /b 0
)
:yetki_tamam

echo  Kurulum klasoru : %HEDEF%
echo.

rem ---------- Calisan program kapatilsin (dosyalar kilitli olur) ----------
tasklist /fi "imagename eq EKAP_Izleyici.exe" 2>nul | find /i "EKAP_Izleyici.exe" >nul
if not errorlevel 1 (
    echo  EKAP Izleyici su an acik; kapatiliyor...
    taskkill /im EKAP_Izleyici.exe /f >nul 2>&1
    timeout /t 2 /nobreak >nul
)

if not exist "%HEDEF%" mkdir "%HEDEF%" 2>nul
if not exist "%HEDEF%" (
    echo  [HATA] Klasor olusturulamadi: %HEDEF%
    pause
    exit /b 1
)
icacls "%HEDEF%" /grant "%USERNAME%":(OI)(CI)F /T >nul 2>&1

set "GECICI=%TEMP%\ekap_exe_%RANDOM%.zip"

echo  [1/5] Paket indiriliyor (buyuk dosya, birkac dakika surebilir)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "try {" ^
  "  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "  $ProgressPreference='SilentlyContinue';" ^
  "  Invoke-WebRequest -Uri '%PAKET_ADRESI%' -OutFile '%GECICI%' -UseBasicParsing;" ^
  "  $s=(Invoke-WebRequest -Uri '%SURUM_ADRESI%' -UseBasicParsing).Content | ConvertFrom-Json;" ^
  "  $h=(Get-FileHash -Algorithm SHA256 '%GECICI%').Hash.ToLower();" ^
  "  if (-not $s.exe -or $h -ne $s.exe.sha256) { throw 'Paket dogrulanamadi (sha256 eslesmiyor).' }" ^
  "  exit 0" ^
  "} catch { Write-Host ('  ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
    echo.
    echo  [HATA] Paket indirilemedi veya dogrulanamadi. Kurulum yapilmadi.
    echo  Internet baglantinizi kontrol edip tekrar deneyin.
    del "%GECICI%" >nul 2>&1
    echo.
    pause
    exit /b 1
)

echo  [2/5] Paket aciliyor...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "try { Expand-Archive -LiteralPath '%GECICI%' -DestinationPath '%HEDEF%' -Force; exit 0 }" ^
  "catch { Write-Host ('  ' + $_.Exception.Message); exit 1 }"
set "ACMA_HATASI=%errorlevel%"
del "%GECICI%" >nul 2>&1
if not "%ACMA_HATASI%"=="0" (
    echo  [HATA] Paket acilamadi.
    pause
    exit /b 1
)
if not exist "%HEDEF%\EKAP_Izleyici.exe" (
    echo  [HATA] EKAP_Izleyici.exe bulunamadi; paket eksik.
    pause
    exit /b 1
)

echo  [3/5] Eski surumun program dosyalari kaldiriliyor (kayitlar korunur)...
rem kurulum.bat burada SILINMEZ: eski tek dosya kurulum bu betigi onun
rem icinden cagirir; calisan betigi silmek cmd'yi bozar.
del /q "%HEDEF%\*.py" >nul 2>&1
if exist "%HEDEF%\requirements.txt" del /q "%HEDEF%\requirements.txt" >nul 2>&1
(
echo @echo off
echo start "" "%%~dp0EKAP_Izleyici.exe"
) > "%HEDEF%\EKAP_Baslat.bat"
if exist "%HEDEF%\sartname\__init__.py" rmdir /s /q "%HEDEF%\sartname" >nul 2>&1
if exist "%HEDEF%\firma\__init__.py" rmdir /s /q "%HEDEF%\firma" >nul 2>&1
if exist "%HEDEF%\.venv" rmdir /s /q "%HEDEF%\.venv" >nul 2>&1
if exist "%HEDEF%\yedek" rmdir /s /q "%HEDEF%\yedek" >nul 2>&1
if exist "%HEDEF%\__pycache__" rmdir /s /q "%HEDEF%\__pycache__" >nul 2>&1

echo  [4/5] Yardimci programlar (belge okuma icin)...
set "WG=1"
where winget >nul 2>&1 || set "WG=0"
if "%YETKISIZ%"=="1" set "WG=0"
if exist "%ProgramFiles%\Tesseract-OCR\tesseract.exe" (
    echo    [VAR] Tesseract OCR
) else if "%WG%"=="1" (
    echo    Tesseract OCR kuruluyor...
    winget install -e --id UB-Mannheim.TesseractOCR --accept-source-agreements --accept-package-agreements --silent >nul 2>&1
) else (
    echo    [ATLANDI] winget yok - Tesseract kurulamadi
)
set "TURDATA=%ProgramFiles%\Tesseract-OCR\tessdata\tur.traineddata"
if not exist "%TURDATA%" if exist "%ProgramFiles%\Tesseract-OCR\tessdata\" (
    echo    Turkce dil paketi indiriliyor...
    curl -L -s -o "%TURDATA%" "https://github.com/tesseract-ocr/tessdata/raw/main/tur.traineddata"
)
if exist "%ProgramFiles%\WinRAR\UnRAR.exe" (
    echo    [VAR] WinRAR
) else if exist "%ProgramFiles%\7-Zip\7z.exe" (
    echo    [VAR] 7-Zip
) else if "%WG%"=="1" (
    echo    7-Zip kuruluyor...
    winget install -e --id 7zip.7zip --accept-source-agreements --accept-package-agreements --silent >nul 2>&1
)

echo  [5/5] Masaustu kisayolu...
if "%KISAYOLSUZ%"=="0" powershell -NoProfile -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\EKAP Izleyici.lnk');" ^
  "$s.TargetPath='%HEDEF%\EKAP_Izleyici.exe'; $s.WorkingDirectory='%HEDEF%';" ^
  "$s.Description='EKAP Ihale Izleyici'; $s.Save()" >nul 2>&1

echo.
echo ==========================================================
echo    KURULUM TAMAM
echo    Ilk acilista lisans anahtariniz sorulacak ve tarayici
echo    bileseni (~150 MB) bir kez indirilecek.
echo ==========================================================
echo.
if "%SESSIZ%"=="1" exit /b 0
rem Program yonetici olarak DEGIL, normal kullanici olarak acilsin.
explorer.exe "%HEDEF%\EKAP_Izleyici.exe"
pause
