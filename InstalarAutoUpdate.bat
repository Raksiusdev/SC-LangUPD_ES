@echo off
setlocal enabledelayedexpansion
echo ================================================
echo   INSTALADOR - Star Citizen ES Auto-Update
echo ================================================
echo.

REM Verificar privilegios de administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Este script necesita ejecutarse como Administrador.
    echo.
    echo Por favor:
    echo   1. Haz clic derecho sobre este archivo
    echo   2. Selecciona "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

echo [OK] Ejecutando con privilegios de administrador
echo.

REM === CONFIGURACION ===
set "GITHUB_OWNER=Raksiusdev"
set "GITHUB_REPO=SC-LangUPD_ES"
set "SCRIPT_NAME=UpdateStarCitizenES.bat"
set "SCRIPT_LAUNCHER=SC_Lang_updater.vbs"
set "SCRIPT_DIR=C:\Scripts"
set "SCRIPT_PATH1=%SCRIPT_DIR%\%SCRIPT_NAME%"
set "SCRIPT_PATH2=%SCRIPT_DIR%\%SCRIPT_LAUNCHER%"
set "GITHUB_URL1=https://raw.githubusercontent.com/%GITHUB_OWNER%/%GITHUB_REPO%/main/%SCRIPT_NAME%"
set "GITHUB_URL2=https://raw.githubusercontent.com/%GITHUB_OWNER%/%GITHUB_REPO%/main/%SCRIPT_LAUNCHER%"

REM === Verificar conexión a internet ===
echo [1/4] Verificando conexión a internet...
ping -n 1 github.com >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] No hay conexión a internet
    pause
    exit /b 1
)
echo [OK] Conexión verificada
echo.

REM === Crear carpeta de scripts ===
echo [2/4] Creando carpeta de scripts...
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"
echo [OK] Carpeta: %SCRIPT_DIR%
echo.

REM === Descargar script desde GitHub ===
echo [3/4] Descargando script desde GitHub...
echo      %GITHUB_URL1%
echo      %GITHUB_URL2%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { " ^
    "    (New-Object Net.WebClient).DownloadFile('%GITHUB_URL1%', '%SCRIPT_PATH1%'); " ^
    "    (New-Object Net.WebClient).DownloadFile('%GITHUB_URL2%', '%SCRIPT_PATH2%'); " ^
    "    Write-Host '[OK] Descarga completada' -ForegroundColor Green; " ^
    "    exit 0; " ^
    "} catch { " ^
    "    Write-Host '[ERROR] ' $_.Exception.Message -ForegroundColor Red; " ^
    "    exit 1; " ^
    "}"

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] No se pudo descargar el script
    echo         Verifica que el repositorio es público y el archivo existe:
    echo         %GITHUB_URL1%
    echo         %GITHUB_URL2%
    pause
    exit /b 1
)

if not exist "%SCRIPT_PATH1%" (
    echo [ERROR] El script no existe después de descargar
    echo         %SCRIPT_PATH1%
    pause
    exit /b 1
)
if not exist "%SCRIPT_PATH2%" (
    echo [ERROR] El siguiente script no existe después de descargar
    echo         %SCRIPT_PATH2%
    pause
    exit /b 1
)

echo.

REM === Crear tarea programada ===
echo [4/4] Configurando tarea programada...

schtasks /query /tn "UpdateStarCitizenES" >nul 2>&1
if %errorLevel% equ 0 (
    schtasks /delete /tn "UpdateStarCitizenES" /f >nul 2>&1
)

schtasks /create /tn "UpdateStarCitizenES" /tr "wscript.exe \"%SCRIPT_PATH2%\"" /sc onlogon /ru "%USERNAME%" /rl highest /f >nul 2>&1

if %errorLevel% equ 0 (
    echo [OK] Tarea programada creada
) else (
    echo [WARN] Error al crear tarea (código: %errorLevel%^)
)

REM Ejecutar comando para establecer los scrips como confiables
Get-ChildItem "C:\Scripts" -Recurse | Unblock-File

echo.
echo ================================================
echo             INSTALACIÓN COMPLETADA
echo ================================================
echo.
echo   Script: %SCRIPT_PATH1%
echo   Launcher: %SCRIPT_PATH2%
echo   Tarea: UpdateStarCitizenES
echo   Log: %USERPROFILE%\Star_citizen_ES_update_log.txt
echo.
echo ================================================
echo PULSA ENTER PARA EJECUTAR PRIMERA ACTUALIZACIÓN
echo ================================================
echo.

pause

REM Ejecutar la tarea
schtasks /run /tn "UpdateStarCitizenES"

echo.
echo ==================================================
echo                     COMPLETADO
echo ==================================================
echo.
echo La traducción se actualizará automáticamente al iniciar Windows
echo.
echo Comandos útiles:
echo   - Ejecutar ahora:  schtasks /run /tn "UpdateStarCitizenES"
echo   - Ver log:         notepad %USERPROFILE%\Star_citizen_ES_update_log.txt
echo   - Desinstalar:     schtasks /delete /tn "UpdateStarCitizenES" /f
echo.
pause
