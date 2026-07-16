@echo off
setlocal enabledelayedexpansion
REM ========================================
REM Script de Actualización Star Citizen ES
REM ========================================
REM === CONFIGURACIÓN ===
set "GITHUB_OWNER=Thord82"
set "GITHUB_REPO=Star_citizen_ES"
set "ZIP_NAME=Star_citizen_ES.zip"
set "STATE_FILE=%USERPROFILE%\%GITHUB_REPO%_state.txt"
set "LOG_FILE=%USERPROFILE%\%GITHUB_REPO%_update_log.txt"
set "LOG_MAX_LINES=500"

REM === Modo interactivo: solo lo pasa el instalador en su primera ejecución ===
set "INTERACTIVE=0"
if /I "%~1"=="/interactive" set "INTERACTIVE=1"

REM === Purgar log si supera el máximo de líneas (un único archivo, sin rotación) ===
if exist "%LOG_FILE%" (
    powershell -NoProfile -Command "$p='%LOG_FILE%'; $max=%LOG_MAX_LINES%; $c=Get-Content $p -ErrorAction SilentlyContinue; if ($c.Count -gt $max) { $c | Select-Object -Last $max | Set-Content $p }" >nul 2>&1
)

REM === Escribir en log ===
echo ========================================>> "%LOG_FILE%"
echo Inicio: %DATE% %TIME% >> "%LOG_FILE%"
echo ========================================>> "%LOG_FILE%"

REM === Cargar estado guardado (release instalada, instalacion elegida, hash del zip) ===
set "LOCAL_RELEASE=none"
set "SAVED_PATH="
set "SAVED_HASH="
if exist "%STATE_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%k in ("%STATE_FILE%") do (
        if /I "%%k"=="RELEASE" set "LOCAL_RELEASE=%%l"
        if /I "%%k"=="INSTALL_PATH" set "SAVED_PATH=%%l"
        if /I "%%k"=="ZIP_SHA256" set "SAVED_HASH=%%l"
    )
)

REM === Buscar TODAS las instalaciones de Star Citizen en TODOS los discos ===
set "FOUND_COUNT=0"
call :log INFO "Buscando instalaciones de Star Citizen en todos los discos..."
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do call :check_drive %%d
call :log INFO "Instalaciones encontradas: %FOUND_COUNT%"

REM === Elegir instalación destino ===
set "DEST_DIR="

if not defined SAVED_PATH goto :no_saved_path
if not exist "%SAVED_PATH%\LIVE" goto :saved_invalid
set "DEST_DIR=%SAVED_PATH%"
call :log INFO "Usando instalacion guardada: %DEST_DIR%"
goto :after_detect

:saved_invalid
call :log WARN "La instalacion guardada ya no existe, se repite la deteccion"

:no_saved_path
if %FOUND_COUNT% EQU 0 goto :no_installs_found
if %FOUND_COUNT% EQU 1 goto :single_install_found
goto :multiple_installs_found

:no_installs_found
set "DEST_DIR=C:\StarCitizen"
call :log WARN "No se encontro Star Citizen, usando ruta por defecto"
goto :after_detect

:single_install_found
set "DEST_DIR=%FOUNDPATH_1%"
call :log OK "Instalacion unica encontrada, seleccionada automaticamente: %DEST_DIR%"
call :save_state "%LOCAL_RELEASE%" "%DEST_DIR%" "%SAVED_HASH%"
goto :after_detect

:multiple_installs_found
if not "%INTERACTIVE%"=="1" goto :multiple_silent
echo.
echo Se han detectado %FOUND_COUNT% instalaciones de Star Citizen:
for /l %%i in (1,1,%FOUND_COUNT%) do call :print_option %%i
echo.
set "CHOICE="
set /p "CHOICE=Elige el numero de instalacion a usar (por defecto 1): "
if "%CHOICE%"=="" set "CHOICE=1"
call set "PICKED=%%FOUNDPATH_%CHOICE%%%"
if defined PICKED goto :choice_valid
echo Opcion invalida, se usara la instalacion 1.
set "PICKED=%FOUNDPATH_1%"
:choice_valid
set "DEST_DIR=%PICKED%"
call :save_state "%LOCAL_RELEASE%" "%DEST_DIR%" "%SAVED_HASH%"
echo Instalacion seleccionada: %DEST_DIR%
call :log OK "Instalacion elegida por el usuario: %DEST_DIR%"
goto :after_detect

:multiple_silent
set "DEST_DIR=%FOUNDPATH_1%"
call :log WARN "Multiples instalaciones detectadas (%FOUND_COUNT%), usando la primera: %DEST_DIR%. Ejecuta InstalarAutoUpdate.bat de nuevo para elegir otra."
goto :after_detect

:after_detect
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

call :log INFO "Release local guardada: %LOCAL_RELEASE%"

REM === Decidir si actualizar ===
set "NEED_UPDATE=0"

REM Caso 1: No hay archivos de traducción (reinstalación del juego)
if "!FILES_EXIST!"=="0" (
    call :log INFO "RAZON: Archivos de traduccion no encontrados, descargando..."
    set "NEED_UPDATE=1"
    goto :do_update
)

REM Caso 2: Versión diferente
if /I not "%LAST_RELEASE%"=="%LOCAL_RELEASE%" (
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

REM === Verificar que el ZIP no este vacio o incompleto ===
set "ZIP_SIZE=0"
for %%s in ("%ZIP_FILE%") do set "ZIP_SIZE=%%~zs"
if %ZIP_SIZE% LSS 1024 (
    call :log ERROR "El ZIP descargado parece vacio o incompleto (%ZIP_SIZE% bytes)"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

REM === Calcular hash del ZIP (Thord82 no publica checksum oficial, se usa
REM     para detectar descargas corruptas y para trazabilidad en soporte) ===
set "ZIP_SHA256="
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "[BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes('%ZIP_FILE%'))) -replace '-',''"`) do set "ZIP_SHA256=%%h"
if not defined ZIP_SHA256 (
    call :log ERROR "No se pudo calcular el hash del ZIP descargado"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)
call :log INFO "SHA256 del ZIP: %ZIP_SHA256%"

REM === Expandir ZIP ===
call :log INFO "Extrayendo archivos..."
powershell -NoProfile -Command "try { Expand-Archive -Force '%ZIP_FILE%' '%TEMP_DIR%\extracted' } catch { exit 1 }"
if %ERRORLEVEL% neq 0 (
    call :log ERROR "Fallo al expandir el archivo"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

REM === Verificar que el ZIP realmente contiene la traducción antes de instalarla ===
if not exist "%TEMP_DIR%\extracted\LIVE\data\Localization\spanish_(spain)\global.ini" (
    call :log ERROR "El ZIP extraido no contiene global.ini, se aborta sin tocar la instalacion"
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

REM === Guardar nuevo estado ===
call :save_state "%LAST_RELEASE%" "%DEST_DIR%" "%ZIP_SHA256%"
call :log OK "Version instalada: %LAST_RELEASE%"

REM === Limpieza ===
rd /s /q "%TEMP_DIR%" >nul 2>&1
call :log OK "Actualizacion completada exitosamente"
echo ======================================== >> "%LOG_FILE%"
exit /b 0

REM ========================================
REM Subrutinas
REM ========================================

REM Comprueba las rutas conocidas de Star Citizen en el disco %1
:check_drive
if not exist "%~1:\" goto :eof
if exist "%~1:\Program Files\Roberts Space Industries\StarCitizen\LIVE" call :add_found "%~1:\Program Files\Roberts Space Industries\StarCitizen"
if exist "%~1:\StarCitizen\LIVE" call :add_found "%~1:\StarCitizen"
if exist "%~1:\Roberts Space Industries\StarCitizen\LIVE" call :add_found "%~1:\Roberts Space Industries\StarCitizen"
if exist "%~1:\Games\StarCitizen\LIVE" call :add_found "%~1:\Games\StarCitizen"
goto :eof

REM Registra una instalación encontrada como FOUNDPATH_<n>
:add_found
set /a FOUND_COUNT+=1
set "FOUNDPATH_%FOUND_COUNT%=%~1"
call :log OK "Instalacion %FOUND_COUNT% encontrada: %~1"
goto :eof

REM Imprime "  N) ruta" para el menú interactivo
:print_option
call set "VAL=%%FOUNDPATH_%~1%%"
echo   %~1^) %VAL%
goto :eof

REM Guarda el estado: %1=release instalada %2=ruta elegida %3=hash del zip
:save_state
(
    echo RELEASE=%~1
    echo INSTALL_PATH=%~2
    echo ZIP_SHA256=%~3
) > "%STATE_FILE%"
goto :eof

:log
echo [%TIME%] [%~1] %~2>> "%LOG_FILE%"
goto :eof
