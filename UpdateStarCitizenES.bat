@echo off
setlocal enabledelayedexpansion
REM ========================================
REM Script de Actualización Star Citizen ES
REM ========================================

REM === CONFIGURACIÓN ===
set "GITHUB_OWNER=Thord82"
set "GITHUB_REPO=Star_citizen_ES"
set "ZIP_NAME=Star_citizen_ES.zip"
set "COMMIT_FILE=%USERPROFILE%\%GITHUB_REPO%_last_commit.txt"
set "LOG_FILE=%USERPROFILE%\%GITHUB_REPO%_update_log.txt"

REM === Escribir en log ===
echo ========================================>> "%LOG_FILE%"
echo Inicio: %DATE% %TIME% >> "%LOG_FILE%"
echo ========================================>> "%LOG_FILE%"

REM === Buscar ruta de instalación de Star Citizen en TODOS los discos ===
set "DEST_DIR="
echo Buscando Star Citizen en todos los discos... >> "%LOG_FILE%"

REM Buscar en todas las unidades (C: hasta Z:)
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\" (
        echo Comprobando disco %%d: >> "%LOG_FILE%"
        
        REM Buscar en Program Files
        if exist "%%d:\Program Files\Roberts Space Industries\StarCitizen\LIVE\data" (
            set "DEST_DIR=%%d:\Program Files\Roberts Space Industries\StarCitizen\LIVE\data\Localization\spanish_(spain)"
            echo ENCONTRADO en %%d:\Program Files >> "%LOG_FILE%"
            goto :found
        )
        
        REM Buscar en carpeta directa
        if exist "%%d:\StarCitizen\LIVE\data" (
            set "DEST_DIR=%%d:\StarCitizen\LIVE\data\Localization\spanish_(spain)"
            echo ENCONTRADO en %%d:\StarCitizen >> "%LOG_FILE%"
            goto :found
        )
        
        REM Buscar en RSI Launcher
        if exist "%%d:\Roberts Space Industries\StarCitizen\LIVE\data" (
            set "DEST_DIR=%%d:\Roberts Space Industries\StarCitizen\LIVE\data\Localization\spanish_(spain)"
            echo ENCONTRADO en %%d:\Roberts Space Industries >> "%LOG_FILE%"
            goto :found
        )
        
        REM Buscar en Games
        if exist "%%d:\Games\StarCitizen\LIVE\data" (
            set "DEST_DIR=%%d:\Games\StarCitizen\LIVE\data\Localization\spanish_(spain)"
            echo ENCONTRADO en %%d:\Games >> "%LOG_FILE%"
            goto :found
        )
    )
)

:found
REM Si no se encuentra, usar ruta por defecto
if not defined DEST_DIR (
    set "DEST_DIR=C:\StarCitizen"
    echo AVISO: No se encontró Star Citizen, usando ruta por defecto >> "%LOG_FILE%"
) else (
    echo Ruta detectada correctamente >> "%LOG_FILE%"
)

echo Destino: "%DEST_DIR%" >> "%LOG_FILE%"

REM === Verificar conexión a internet ===
ping -n 1 github.com >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Sin conexión a internet >> "%LOG_FILE%"
    exit /b 0
)

REM === Obtener último commit desde GitHub ===
powershell -NoProfile -Command ^
  "try { $json = Invoke-WebRequest -UseBasicParsing 'https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/commits' | ConvertFrom-Json; $c = $json[0].sha; Write-Output $c } catch { exit 1 }" > "%USERPROFILE%\%GITHUB_REPO%_last_commit_tmp.txt" 2>nul

if %ERRORLEVEL% neq 0 (
    echo ERROR: No se pudo obtener info de GitHub >> "%LOG_FILE%"
    del "%USERPROFILE%\%GITHUB_REPO%_last_commit_tmp.txt" 2>nul
    exit /b 0
)

for /f "delims=" %%a in ("%USERPROFILE%\%GITHUB_REPO%_last_commit_tmp.txt") do set "LAST_COMMIT=%%a"
del "%USERPROFILE%\%GITHUB_REPO%_last_commit_tmp.txt" 2>nul
echo Último commit remoto: %LAST_COMMIT% >> "%LOG_FILE%"

REM === Leer commit local ===
if exist "%COMMIT_FILE%" (
    set /p "LOCAL_COMMIT="<"%COMMIT_FILE%"
    echo Commit local: %LOCAL_COMMIT% >> "%LOG_FILE%"
) else (
    echo Primera instalación >> "%LOG_FILE%"
    set "LOCAL_COMMIT=none"
)

REM === Comparar commits ===
if "%LAST_COMMIT%"=="%LOCAL_COMMIT%" (
    echo Ya actualizado >> "%LOG_FILE%"
    exit /b 0
)

echo Nueva actualización detectada >> "%LOG_FILE%"

REM === Crear backup si existe instalación previa ===
if exist "%DEST_DIR%" (
    set "BACKUP_DIR=%DEST_DIR%_backup_%date:~-4%%date:~3,2%%date:~0,2%"
    echo Creando backup en: !BACKUP_DIR! >> "%LOG_FILE%"
    xcopy "%DEST_DIR%\*" "!BACKUP_DIR!\" /E /Y /I >nul 2>&1
)

REM === Crear carpeta temporal ===
set "TEMP_DIR=%USERPROFILE%\Downloads\%GITHUB_REPO%_temp"
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%" >nul 2>&1

REM === Descargar ZIP ===
set "ZIP_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/latest/download/%ZIP_NAME%"
set "ZIP_FILE=%TEMP_DIR%\%ZIP_NAME%"
echo Descargando actualización... >> "%LOG_FILE%"

powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadFile('%ZIP_URL%', '%ZIP_FILE%'); exit 0 } catch { exit 1 }"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Falló la descarga >> "%LOG_FILE%"
    rd /s /q "%TEMP_DIR%"
    exit /b 1
)

REM === Expandir ZIP ===
echo Extrayendo archivos... >> "%LOG_FILE%"
powershell -NoProfile -Command "try { Expand-Archive -Force '%ZIP_FILE%' '%TEMP_DIR%\extracted' } catch { exit 1 }"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Falló al expandir >> "%LOG_FILE%"
    rd /s /q "%TEMP_DIR%"
    exit /b 1
)

REM === Crear directorio destino si no existe ===
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"

REM === Copiar archivos ===
echo Instalando traducción... >> "%LOG_FILE%"
xcopy "%TEMP_DIR%\extracted\*" "%DEST_DIR%\" /E /Y /I

REM === Guardar nuevo commit ===
echo %LAST_COMMIT% > "%COMMIT_FILE%"

REM === Limpieza ===
rd /s /q "%TEMP_DIR%" >nul 2>&1

echo Actualización completada: %LAST_COMMIT% >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"

exit /b 0