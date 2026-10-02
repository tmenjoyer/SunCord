@echo off
@chcp 65001 >nul
setlocal EnableDelayedExpansion

set "INPUT_VER=%~1"
set "NOTES=%~2"

if "%INPUT_VER%"=="" (
    echo.
    echo  ========================================================
    echo   SUNCORD - PUBLICATION DE NOUVELLE RELEASE
    echo  ========================================================
    echo.
    set /p INPUT_VER="Entrez la version a publier : "
)

if "%INPUT_VER%"=="" (
    echo  [ERREUR] Aucune version specifiee. Annulation.
    pause
    exit /b 1
)

set "VERSION=%INPUT_VER%"
if "%VERSION:~0,1%"=="v" set "VERSION=%VERSION:~1%"
if "%VERSION:~0,1%"=="V" set "VERSION=%VERSION:~1%"

set "TAG=v%VERSION%"
if "%NOTES%"=="" set "NOTES=%TAG%"

set GITEA_URL=https://source.nightcord.st
set GITEA_REPO=nightcord/nightcord
set DIST_DIR=dist\desktop
set OUT_DIR=release\installer
set DIST_ZIP=%OUT_DIR%\suncord-dist.zip
set INSTALLER_EXE=%OUT_DIR%\Suncord-Installer.exe
set VERSION_JSON=%OUT_DIR%\version.json
set DESKTOP_ASAR=dist\desktop.asar
set CHROME_ZIP=dist\extension-chrome.zip
set FIREFOX_ZIP=dist\extension-firefox.zip

echo.
echo  =======================================================
echo     SUNCORD - Publication release %TAG%
echo  =======================================================
echo.

REM 1. Mise a jour de la version
echo  [1/8] Mise a jour de la version vers %VERSION%...
node -e "const fs = require('fs'); const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); pkg.version = '%VERSION%'; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 4) + '\n', 'utf8');"
echo  [1/8] Version mise a jour : %VERSION%

REM 2. Envoi du code source sur Gitea
echo.
echo  [2/8] Committer et synchroniser le code source...
git add .
git diff --quiet --cached
if errorlevel 1 (
    git commit -m "build: release %TAG%"
) else (
    echo  Aucun changement a committer.
)

set "GITEA_TOK="
if exist ".gitea_token" set /p GITEA_TOK=<.gitea_token
if "!GITEA_TOK!"=="" if exist "%USERPROFILE%\.gitea_token" set /p GITEA_TOK=<%USERPROFILE%\.gitea_token
if "!GITEA_TOK!"=="" set "GITEA_TOK=%GITEA_TOKEN%"

if not "!GITEA_TOK!"=="" (
    echo  [2/8] Push du code source vers Gitea...
    git push "https://oauth2:!GITEA_TOK!@source.nightcord.st/nightcord/nightcord.git" master --quiet
    if errorlevel 1 (
        echo  [AVERTISSEMENT] Le push securise a echoue. La release API prendra le relais pour le tag.
    ) else (
        echo  [2/8] Code source synchronise avec Gitea.
    )
) else (
    set GIT_TERMINAL_PROMPT=0
    git push --set-upstream origin master --quiet 2>nul
    if errorlevel 1 (
        echo  [AVERTISSEMENT] Git non authentifie directement. La release API prendra le relais pour le tag.
    ) else (
        echo  [2/8] Code source synchronise avec Gitea.
    )
)

REM 3. Build Extensions Web et Desktop
echo.
echo  [3/8] Compilation des extensions Chrome et Firefox...
taskkill /F /IM Discord.exe /T >nul 2>&1
taskkill /F /IM DiscordPTB.exe /T >nul 2>&1
taskkill /F /IM DiscordCanary.exe /T >nul 2>&1
taskkill /F /IM Suncord-Installer.exe /T >nul 2>&1
timeout /t 1 /nobreak >nul

call buildextension.bat %VERSION%
if errorlevel 1 (
    echo  [ERREUR] buildextension.bat a echoue.
    pause
    exit /b 1
)

echo.
echo  [3b/8] Compilation du client Desktop...
call pnpm build
if errorlevel 1 (
    echo  [ERREUR] pnpm build a echoue.
    pause
    exit /b 1
)

echo  [3/8] Builds JS et Extensions termines !

REM 4. Assets
echo.
echo  [4/8] Copie des assets vers %DIST_DIR%...
node scripts\build\collect-assets.mjs
echo  [4/8] Assets copies.

REM 5. Suncord-Installer.exe
echo.
echo  [5/8] Compilation de Suncord-Installer.exe...
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "build-installer.ps1"
if errorlevel 1 (
    echo  [ERREUR] Compilation de l'installeur echouee.
    pause
    exit /b 1
)
if not exist "%INSTALLER_EXE%" (
    echo  [ERREUR] Suncord-Installer.exe introuvable apres compilation.
    pause
    exit /b 1
)
echo  [5/8] Suncord-Installer.exe cree avec succes.

REM 6. suncord-dist.zip
echo.
echo  [6/8] Creation de suncord-dist.zip...
if not exist "%DIST_DIR%\patcher.js" (
    echo  [ERREUR] dist\desktop\patcher.js introuvable.
    pause
    exit /b 1
)
if exist "%DIST_ZIP%" del /F /Q "%DIST_ZIP%"
del /s /q "%DIST_DIR%\*.map" >nul 2>&1
del /s /q "%DIST_DIR%\*.LEGAL.txt" >nul 2>&1
node scripts\build\verify-dist.mjs
if errorlevel 1 (
    echo  [ERREUR] Verification du dist echouee.
    pause
    exit /b 1
)
powershell -NoProfile -Command "Add-Type -Assembly System.IO.Compression.FileSystem; $src = (Resolve-Path '%DIST_DIR%').Path; $dst = (Join-Path (Resolve-Path 'release\installer').Path 'suncord-dist.zip'); [System.IO.Compression.ZipFile]::CreateFromDirectory($src, $dst, [System.IO.Compression.CompressionLevel]::Optimal, $false)"
if not exist "%DIST_ZIP%" (
    echo  [ERREUR] Impossible de creer suncord-dist.zip
    pause
    exit /b 1
)
echo  [6/8] suncord-dist.zip cree avec succes.

REM 7. version.json
echo.
echo  [7/8] Mise a jour de version.json...
for /f "usebackq" %%d in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd'"`) do set ISO_DATE=%%d
(
    echo {
    echo   "version": "%VERSION%",
    echo   "releaseDate": "%ISO_DATE%",
    echo   "installerUrl": "%GITEA_URL%/%GITEA_REPO%/releases/download/%TAG%/Suncord-Installer.exe",
    echo   "distUrl": "%GITEA_URL%/%GITEA_REPO%/releases/download/%TAG%/suncord-dist.zip",
    echo   "downloadUrl": "%GITEA_URL%/%GITEA_REPO%/releases/download/%TAG%/desktop.asar",
    echo   "installScriptUrl": "%GITEA_URL%/%GITEA_REPO%/releases/download/%TAG%/install.sh",
    echo   "changelog": "%TAG%"
    echo }
) > "%VERSION_JSON%"
echo  [7/8] version.json mis a jour.

REM 8. Publication Gitea via tunnel SSH
echo.
echo  [8/8] Publication des assets Multi-OS sur Gitea...

powershell -NoProfile -Command "$test = try { (Invoke-WebRequest -Uri 'http://127.0.0.1:3000/api/v1/version' -TimeoutSec 2 -UseBasicParsing).StatusCode } catch { 0 }; if ($test -ne 200) { Write-Host '  Demarrage du tunnel SSH vers Gitea (port 3000)...' -ForegroundColor Cyan; Start-Process -WindowStyle Hidden ssh -ArgumentList '-N -L 3000:127.0.0.1:3000 nc'; Start-Sleep -Seconds 2; }"

node scripts\build\publish-gitea-release.mjs "%VERSION%" "%TAG%" "%NOTES%"
if errorlevel 1 (
    echo  [ERREUR] Publication des assets echouee.
    pause
    exit /b 1
)

echo.
echo  =======================================================================
echo    Suncord %TAG% publie avec succes sur Gitea !
echo.
echo    URL : %GITEA_URL%/%GITEA_REPO%/releases/tag/%TAG%
echo.
echo    Fichiers publies (Windows + Linux + macOS + NixOS) :
echo      - Suncord-Installer.exe    - installeur Windows avec GUI
echo      - Suncord-Linux            - installeur Linux GUI (Both X11 & Wayland)
echo      - Suncord-Linux-x11        - installeur Linux GUI (X11 only)
echo      - Suncord-Linux-wayland    - installeur Linux GUI (Wayland only)
echo      - Suncord-darwin-arm64.zip - installeur macOS GUI (Apple Silicon)
echo      - Suncord-darwin-x64.zip   - installeur macOS GUI (Intel x64)
echo      - install.sh                 - installeur universel interactif Linux & macOS
echo      - install.ps1                - installeur CLI Windows
echo      - desktop.asar               - asar Discord patcher
echo      - suncordDesktop.asar      - bundle asar complet
echo      - extension-chrome.zip       - extension Chrome/Chromium
echo      - extension-firefox.zip      - extension Firefox
echo      - suncord-dist.zip         - JS obfusques (auto-update & injection)
echo      - version.json               - metadonnees de version
echo.
echo    Commandes d'installation pour les utilisateurs :
echo      * Linux / macOS : curl -sS %GITEA_URL%/%GITEA_REPO%/raw/branch/master/install.sh ^| bash
echo      * NixOS Flake   : inputs.suncord.url = "git+%GITEA_URL%/%GITEA_REPO%.git";
echo  =======================================================================
echo.
pause
