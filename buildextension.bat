@echo off
setlocal EnableDelayedExpansion

echo ========================================================
echo BUILDER EXTENSIONS CHROME / FIREFOX SUNCORD
echo ========================================================
echo.

set "NEW_VERSION=%~1"

if "%NEW_VERSION%"=="" set /p NEW_VERSION="Entrez la version : "

if "%NEW_VERSION%"=="" (
    echo [ERREUR] Version invalide, annulation.
    if "%~1"=="" pause
    exit /b 1
)

REM Nettoyer le v initial si present
if "%NEW_VERSION:~0,1%"=="v" set "NEW_VERSION=%NEW_VERSION:~1%"
if "%NEW_VERSION:~0,1%"=="V" set "NEW_VERSION=%NEW_VERSION:~1%"

echo.
echo Mise a jour de package.json vers la version %NEW_VERSION%...
node -e "const fs = require('fs'); const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); pkg.version = '%NEW_VERSION%'; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 4) + '\n', 'utf8');"

echo.
echo Construction des extensions Chrome et Firefox en cours...
call pnpm buildWeb
if errorlevel 1 (
    echo [ERREUR] Echec de la compilation des extensions web.
    if "%~1"=="" pause
    exit /b 1
)

echo.
echo ========================================================
echo TERMINE ! Extensions pretes dans :
echo   dist\extension-chrome.zip   (Extension Chromium / Chrome)
echo   dist\extension-firefox.zip  (Extension Firefox)
echo ========================================================
if "%~1"=="" pause
