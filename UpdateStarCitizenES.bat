@echo off
setlocal enabledelayedexpansion
REM ========================================
REM Script de Actualización Star Citizen ES
REM ========================================
REM === CONFIGURACIÓN ===
set "GITHUB_OWNER=Thord82"
set "GITHUB_REPO=Star_citizen_ES"
set "ZIP_NAME=Star_citizen_ES.zip"
set "RELEASE_FILE=%USERPROFILE%\%GITHUB_REPO%_last_release.txt"
set "LOG_FILE=%USERPROFILE%\%GITHUB_REPO%_update_log.txt"
set "LOG_MAX_LINES=500"

REM === Purgar log si supera el máximo de líneas (un único archivo, sin rotación) ===
if exist "%LOG_FILE%" (
    powershell -NoProfile -Command "$p='%LOG_FILE%'; $max=%LOG_MAX_LINES%; $c=Get-Content $p -ErrorAction SilentlyContinue; if ($c.Count -gt $max) { $c | Select-Object -Last $max | Set-Content $p }" >nul 2>&1
)

REM === Escribir en log ===
echo ========================================>> "%LOG_FILE%"
echo Inicio: %DATE% %TIME% >> "%LOG_FILE%"
echo ========================================>> "%LOG_FILE%"

REM === Buscar ruta de instalación de Star Citizen en TODOS los discos ===
set "DEST_DIR="
call :log INFO "Buscando Star Citizen en todos los discos..."
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\" (
        call :log INFO "Comprobando disco %%d:"
        if exist "%%d:\Program Files\Roberts Space Industries\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Program Files\Roberts Space Industries\StarCitizen"
            call :log OK "Encontrado en %%d:\Program Files"
            goto :found
        )
        if exist "%%d:\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\StarCitizen"
            call :log OK "Encontrado en %%d:\StarCitizen"
            goto :found
        )
        if exist "%%d:\Roberts Space Industries\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Roberts Space Industries\StarCitizen"
            call :log OK "Encontrado en %%d:\Roberts Space Industries"
            goto :found
        )
        if exist "%%d:\Games\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Games\StarCitizen"
            call :log OK "Encontrado en %%d:\Games"
            goto :found
        )
    )
)
:found
if not defined DEST_DIR (
    set "DEST_DIR=C:\StarCitizen"
    call :log WARN "No se encontro Star Citizen, usando ruta por defecto"
) else (
    call :log OK "Ruta detectada correctamente"
)
call :log INFO "Destino: %DEST_DIR%"

REM === Verificar conexión a internet ===
ping -n 1 github.com >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :log ERROR "Sin conexion a internet"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 0
)

REM === Obtener última release (versión) desde GitHub ===
call :log INFO "Consultando ultima release en GitHub..."
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$owner = '%GITHUB_OWNER%'; $repo = '%GITHUB_REPO%'; " ^
    "$uri = 'https://api.github.com/repos/' + $owner + '/' + $repo + '/releases/latest'; " ^
    "$headers = @{'User-Agent' = 'StarCitizenES-Updater'; 'Accept' = 'application/vnd.github.v3+json'}; " ^
    "try { " ^
    "    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop; " ^
    "    $tag = $resp.tag_name; " ^
    "    $tag = $tag -replace '^v\.?', ''; " ^
    "    $tag " ^
    "} catch { " ^
    "    'no-release-yet' " ^
    "}"`) do set "LAST_RELEASE=%%a"

if not defined LAST_RELEASE (
    call :log ERROR "No se pudo obtener la version de GitHub"
    set "LAST_RELEASE=no-release-yet"
)

call :log INFO "Ultima release remota: %LAST_RELEASE%"

REM === Verificar si existen archivos de traducción en el juego ===
set "FILES_EXIST=0"
if exist "%DEST_DIR%\LIVE\data\Localization\spanish_(spain)\global.ini" (
    set "FILES_EXIST=1"
    call :log OK "Archivos de traduccion encontrados en el juego"
) else (
    call :log WARN "Archivos de traduccion NO encontrados en el juego"
)

REM === Leer release local ===
set "LOCAL_RELEASE=none"
if exist "%RELEASE_FILE%" (
    for /f "usebackq tokens=*" %%b in ("%RELEASE_FILE%") do set "LOCAL_RELEASE=%%b"
    call :log INFO "Release local guardada: !LOCAL_RELEASE!"
) else (
    call :log INFO "No hay registro de version instalada"
)

REM === Decidir si actualizar ===
set "NEED_UPDATE=0"

REM Caso 1: No hay archivos de traducción (reinstalación del juego)
if "!FILES_EXIST!"=="0" (
    call :log INFO "RAZON: Archivos de traduccion no encontrados, descargando..."
    set "NEED_UPDATE=1"
    goto :do_update
)

REM Caso 2: Versión diferente
if /I not "%LAST_RELEASE%"=="!LOCAL_RELEASE!" (
    call :log INFO "RAZON: Nueva version disponible (%LAST_RELEASE%)"
    set "NEED_UPDATE=1"
    goto :do_update
)

REM Caso 3: Todo está actualizado
call :log OK "Ya actualizado (version %LAST_RELEASE%)"
echo ======================================== >> "%LOG_FILE%"
exit /b 0

:do_update
if "%LAST_RELEASE%"=="no-release-yet" (
    call :log WARN "No hay releases disponibles para descargar"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 0
)

call :log INFO "Iniciando descarga e instalacion..."

REM === Crear carpeta temporal ===
set "TEMP_DIR=%USERPROFILE%\Downloads\%GITHUB_REPO%_temp"
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%" >nul 2>&1

REM === Descargar ZIP ===
set "ZIP_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/latest/download/%ZIP_NAME%"
set "ZIP_FILE=%TEMP_DIR%\%ZIP_NAME%"
call :log INFO "Descargando %ZIP_NAME%..."
powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadFile('%ZIP_URL%', '%ZIP_FILE%'); exit 0 } catch { exit 1 }"
if %ERRORLEVEL% neq 0 (
    call :log ERROR "Fallo la descarga"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

REM === Expandir ZIP ===
call :log INFO "Extrayendo archivos..."
powershell -NoProfile -Command "try { Expand-Archive -Force '%ZIP_FILE%' '%TEMP_DIR%\extracted' } catch { exit 1 }"
if %ERRORLEVEL% neq 0 (
    call :log ERROR "Fallo al expandir el archivo"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

REM === Crear directorio destino si no existe ===
if not exist "%DEST_DIR%\LIVE\data\Localization\spanish_(spain)" (
    call :log INFO "Creando carpeta de traduccion..."
    mkdir "%DEST_DIR%\LIVE\data\Localization\spanish_(spain)" >nul 2>&1
)

REM === Copiar archivos ===
call :log INFO "Instalando traduccion en el juego..."
xcopy "%TEMP_DIR%\extracted\*" "%DEST_DIR%\" /E /Y /I /Q >nul

REM === Guardar nueva release ===
echo %LAST_RELEASE%> "%RELEASE_FILE%"
call :log OK "Version instalada: %LAST_RELEASE%"

REM === Limpieza ===
rd /s /q "%TEMP_DIR%" >nul 2>&1
call :log OK "Actualizacion completada exitosamente"
echo ======================================== >> "%LOG_FILE%"
exit /b 0

REM ========================================
REM Subrutinas
REM ========================================
:log
echo [%TIME%] [%~1] %~2>> "%LOG_FILE%"
goto :eof
