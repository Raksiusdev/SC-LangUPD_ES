@echo off
REM Consola en UTF-8: el archivo esta guardado en UTF-8, evita mojibake si
REM en el futuro se muestra texto con acentos/enye en pantalla o en el log.
chcp 65001 >nul
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

REM === Canales del juego. LIVE y HOTFIX se instalan automaticamente si existen.
REM     PTU y EPTU son versiones de pruebas: solo se instalan si el usuario lo
REM     confirma en el instalador (la decision se guarda en el archivo de estado). ===
set "CHANNELS_AUTO=LIVE HOTFIX"
set "CHANNELS_PREVIEW=PTU EPTU"

REM === Espera de red al iniciar sesion (puede no estar lista todavia) ===
set "NET_MAX_TRIES=6"
set "NET_RETRY_SECS=10"

REM === Auto-actualizacion del propio script (contra releases de este repo,
REM     no commits de main, para no desplegar cambios sin marcar como listos) ===
set "SCRIPT_VERSION=0.4.0"
set "SELF_OWNER=Raksiusdev"
set "SELF_REPO=SC-LangUPD_ES"

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

REM === Esperar a que haya conexion con GitHub (comprobacion TCP al puerto 443:
REM     el ping falla en redes que bloquean ICMP aunque HTTPS funcione) ===
set "NET_TRIES=0"
set /a NET_SLEEP=NET_RETRY_SECS+1

:wait_network
powershell -NoProfile -Command "try { $c = New-Object Net.Sockets.TcpClient; if ($c.ConnectAsync('api.github.com',443).Wait(5000) -and $c.Connected) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if %ERRORLEVEL% equ 0 goto :network_ok
set /a NET_TRIES+=1
if %NET_TRIES% GEQ %NET_MAX_TRIES% goto :network_failed
call :log WARN "Sin conexion con GitHub (intento %NET_TRIES% de %NET_MAX_TRIES%), reintentando en %NET_RETRY_SECS% s..."
ping -n %NET_SLEEP% 127.0.0.1 >nul
goto :wait_network

:network_failed
call :log ERROR "Sin conexion con GitHub tras %NET_MAX_TRIES% intentos, se omite esta ejecucion"
if "%INTERACTIVE%"=="1" echo [ERROR] Sin conexion con GitHub. Comprueba tu red y vuelve a ejecutar el instalador.
echo ======================================== >> "%LOG_FILE%"
exit /b 0

:network_ok

REM === Comprobar si hay una nueva version del propio script publicada ===
set "SELF_UPDATING="
call :selfupdate_check
REM Si se lanzo el helper de auto-actualizacion, ESTE proceso debe terminar ya:
REM un "exit /b" dentro de la subrutina solo vuelve aqui, y seguir ejecutando
REM mientras el helper sobrescribe este archivo corrompe la ejecucion.
if defined SELF_UPDATING exit /b 0

REM === Cargar estado guardado (release instalada, instalacion elegida, hash del zip) ===
set "LOCAL_RELEASE=none"
set "SAVED_PATH="
set "SAVED_HASH="
set "PREVIEW_ON="
if exist "%STATE_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%k in ("%STATE_FILE%") do (
        if /I "%%k"=="RELEASE" set "LOCAL_RELEASE=%%l"
        if /I "%%k"=="INSTALL_PATH" set "SAVED_PATH=%%l"
        if /I "%%k"=="ZIP_SHA256" set "SAVED_HASH=%%l"
        if /I "%%k"=="PREVIEW_ON" set "PREVIEW_ON=%%l"
    )
)

REM === Buscar TODAS las instalaciones de Star Citizen ===
REM La deteccion vive en el bloque PowerShell del final de este archivo y
REM mira, por orden: log del RSI Launcher, rutas conocidas y un escaneo
REM acotado de los discos. Cada linea que devuelve es TAG|ruta.
set "FOUND_COUNT=0"
REM Con una ruta guardada valida no hace falta detectar nada (ejecuciones silenciosas)
if not defined SAVED_PATH goto :detect_installs
call :root_ok "%SAVED_PATH%"
if defined ROOT_OK goto :pick_install

:detect_installs
call :log INFO "Buscando instalaciones de Star Citizen (launcher, rutas conocidas y escaneo de discos)..."
for /f "usebackq tokens=1,* delims=|" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$s.IndexOf('#PS_'+'BEGIN'); & ([scriptblock]::Create($s.Substring($i)))"`) do call :add_found "%%a" "%%b"
call :log INFO "Instalaciones encontradas: %FOUND_COUNT%"

:pick_install
REM === Elegir instalación destino ===
set "DEST_DIR="

if not defined SAVED_PATH goto :no_saved_path
call :root_ok "%SAVED_PATH%"
if not defined ROOT_OK goto :saved_invalid
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
call :log WARN "No se encontro Star Citizen automaticamente"
if not "%INTERACTIVE%"=="1" goto :no_install_abort
echo.
echo No se ha encontrado Star Citizen automaticamente.
echo Indica la carpeta de instalacion: la que contiene las carpetas LIVE, PTU...
echo ^(ejemplo: D:\Roberts Space Industries\StarCitizen^)
set "MANUAL_TRIES=0"

:ask_manual_path
set /a MANUAL_TRIES+=1
set "MANUAL_PATH="
call :prompt MANUAL_PATH "Ruta (vacio para cancelar): "
if not defined MANUAL_PATH goto :no_install_abort
set "MANUAL_PATH=%MANUAL_PATH:"=%"
if "%MANUAL_PATH:~-1%"=="\" set "MANUAL_PATH=%MANUAL_PATH:~0,-1%"
REM Si pegan la ruta de un canal (...\StarCitizen\LIVE) se sube un nivel
if /I "%MANUAL_PATH:~-5%"=="\LIVE" set "MANUAL_PATH=%MANUAL_PATH:~0,-5%"
if /I "%MANUAL_PATH:~-4%"=="\PTU" set "MANUAL_PATH=%MANUAL_PATH:~0,-4%"
if /I "%MANUAL_PATH:~-5%"=="\EPTU" set "MANUAL_PATH=%MANUAL_PATH:~0,-5%"
if /I "%MANUAL_PATH:~-7%"=="\HOTFIX" set "MANUAL_PATH=%MANUAL_PATH:~0,-7%"
call :root_ok "%MANUAL_PATH%"
if defined ROOT_OK goto :manual_path_ok
echo No se encuentra ningun canal del juego ^(LIVE, HOTFIX, PTU o EPTU^) en "%MANUAL_PATH%", revisa la ruta.
if %MANUAL_TRIES% LSS 3 goto :ask_manual_path
goto :no_install_abort

:manual_path_ok
set "DEST_DIR=%MANUAL_PATH%"
call :save_state "%LOCAL_RELEASE%" "%DEST_DIR%" "%SAVED_HASH%"
call :log OK "Ruta indicada manualmente por el usuario: %DEST_DIR%"
goto :after_detect

:no_install_abort
call :log ERROR "No se encontro la carpeta de Star Citizen, no se instala nada. Ejecuta InstalarAutoUpdate.bat como administrador para indicar la ruta a mano."
if "%INTERACTIVE%"=="1" echo [ERROR] No se ha configurado ninguna ruta de Star Citizen. No se ha instalado nada.
echo ======================================== >> "%LOG_FILE%"
exit /b 1

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
call :prompt CHOICE "Elige el numero de instalacion a usar (por defecto 1): "
if "%CHOICE%"=="" set "CHOICE=1"
call set "PICKED=%%FOUNDPATH_%CHOICE%%%"
if defined PICKED goto :choice_valid
echo Opcion invalida, se usara la instalacion 1.
set "PICKED=%FOUNDPATH_1%"
:choice_valid
set "DEST_DIR=%PICKED%"
call :save_state "%LOCAL_RELEASE%" "%DEST_DIR%" "%SAVED_HASH%"
echo Instalacion seleccionada: !DEST_DIR!
call :log OK "Instalacion elegida por el usuario: %DEST_DIR%"
goto :after_detect

:multiple_silent
set "DEST_DIR=%FOUNDPATH_1%"
call :log WARN "Multiples instalaciones detectadas (%FOUND_COUNT%), usando la primera: %DEST_DIR%. Ejecuta InstalarAutoUpdate.bat de nuevo para elegir otra."
goto :after_detect

:after_detect
call :log INFO "Destino: %DEST_DIR%"

REM === Canales donde instalar: LIVE/HOTFIX si existen; PTU/EPTU solo confirmados ===
call :resolve_channels
if not defined TARGETS (
    call :log WARN "No hay canales donde instalar en %DEST_DIR% (LIVE/HOTFIX no encontrados y PTU/EPTU sin confirmar)"
    if "%INTERACTIVE%"=="1" echo [AVISO] No hay ningun canal seleccionado donde instalar la traduccion.
    echo ======================================== >> "%LOG_FILE%"
    exit /b 0
)
call :log INFO "Canales de destino:%TARGETS%"

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

REM === Traduccion puente: mientras Thord no publique nada posterior al parche del
REM     juego, este repo publica (pre-release "bridge-*") su traduccion + los textos
REM     nuevos. Solo se usa si su BASE coincide con la ultima release de Thord; en
REM     cuanto Thord publica otra, el puente deja de aplicarse solo. ===
set "BRIDGE_TAG="
set "BRIDGE_URL="
set "BRIDGE_SHA="
set "SC_THORD_TAG=%LAST_RELEASE%"
set "SC_SELF_OWNER=%SELF_OWNER%"
set "SC_SELF_REPO=%SELF_REPO%"
for /f "usebackq tokens=1,2,3 delims=|" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$s.IndexOf('#PS_'+'BRIDGE'); $j=$s.IndexOf('#PS_'+'BEGIN'); & ([scriptblock]::Create($s.Substring($i,$j-$i)))"`) do (
    set "BRIDGE_TAG=%%a"
    set "BRIDGE_URL=%%b"
    set "BRIDGE_SHA=%%c"
)
if defined BRIDGE_TAG (
    call :log INFO "Traduccion puente disponible: !BRIDGE_TAG! (base: Thord %LAST_RELEASE%)"
    set "THORD_RELEASE=%LAST_RELEASE%"
    set "LAST_RELEASE=!BRIDGE_TAG!"
    call :log INFO "Version a instalar: !LAST_RELEASE!"
)

REM === Verificar si existen archivos de traducción en cada canal de destino ===
set "MISSING="
for %%c in (%TARGETS%) do if not exist "%DEST_DIR%\%%c\data\Localization\spanish_(spain)\global.ini" set "MISSING=!MISSING! %%c"
if defined MISSING (
    call :log WARN "Archivos de traduccion NO encontrados en:!MISSING!"
) else (
    call :log OK "Archivos de traduccion encontrados en todos los canales de destino"
)

call :log INFO "Release local guardada: %LOCAL_RELEASE%"

REM === Decidir si actualizar ===
REM Caso 1: faltan archivos en algun canal (reinstalación del juego o canal recien confirmado)
if defined MISSING (
    call :log INFO "RAZON: faltan archivos de traduccion en:!MISSING!, descargando..."
    goto :do_update
)

REM Caso 2: Versión diferente
if /I not "%LAST_RELEASE%"=="%LOCAL_RELEASE%" (
    call :log INFO "RAZON: Nueva version disponible (%LAST_RELEASE%)"
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
if defined BRIDGE_URL set "ZIP_URL=%BRIDGE_URL%"
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
if defined BRIDGE_SHA if /I not "%BRIDGE_SHA%"=="%ZIP_SHA256%" (
    call :log ERROR "El hash del zip puente no coincide con el publicado por GitHub, se aborta sin tocar la instalacion"
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

REM === Verificar que el ZIP realmente contiene la traducción antes de instalarla ===
if not exist "%TEMP_DIR%\extracted\LIVE\data\Localization\spanish_(spain)\global.ini" (
    call :log ERROR "El ZIP extraido no contiene global.ini, se aborta sin tocar la instalacion"
    rd /s /q "%TEMP_DIR%"
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

REM === Copiar archivos solo a los canales de destino (antes se copiaba todo el
REM     ZIP y se creaba una carpeta PTU aunque el usuario no la tuviera) ===
call :log INFO "Instalando traduccion en el juego..."
set "COPY_FAIL="
for %%c in (%TARGETS%) do call :install_channel %%c
if defined COPY_FAIL (
    call :log ERROR "No se pudo instalar la traduccion en todos los canales, se reintentara en la proxima ejecucion"
    rd /s /q "%TEMP_DIR%" >nul 2>&1
    echo ======================================== >> "%LOG_FILE%"
    exit /b 1
)

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

REM Comprueba si hay una release nueva del propio script y, si la hay, la
REM descarga y aplica desde un proceso auxiliar separado. IMPORTANTE: nunca
REM sobrescribir %~f0 y seguir ejecutando lineas de ESTE MISMO proceso -
REM cmd.exe sigue leyendo el archivo por offset de bytes y si el contenido
REM cambia bajo sus pies el resto de la ejecucion se corrompe (verificado).
:selfupdate_check
REM Proteccion anti-bucle: el helper relanza el script ya actualizado con esta
REM variable puesta. Si la release publicada conservara SCRIPT_VERSION=dev (o
REM cualquier valor distinto de su tag), sin esto se actualizaria sin fin.
if defined SC_SELFUPDATED (
    call :log INFO "Script recien auto-actualizado, se omite una segunda comprobacion"
    goto :eof
)
set "SELF_LATEST="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$uri = 'https://api.github.com/repos/%SELF_OWNER%/%SELF_REPO%/releases/latest'; " ^
    "$headers = @{'User-Agent' = 'StarCitizenES-Updater'; 'Accept' = 'application/vnd.github.v3+json'}; " ^
    "try { " ^
    "    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop; " ^
    "    $tag = $resp.tag_name -replace '^v\.?', ''; " ^
    "    $tag " ^
    "} catch { " ^
    "    'no-release-yet' " ^
    "}"`) do set "SELF_LATEST=%%a"

if not defined SELF_LATEST (
    call :log WARN "No se pudo comprobar si hay una nueva version del script"
    goto :eof
)
if "%SELF_LATEST%"=="no-release-yet" (
    call :log INFO "No hay releases publicadas del script todavia, se omite auto-actualizacion"
    goto :eof
)
if /I "%SELF_LATEST%"=="%SCRIPT_VERSION%" (
    call :log INFO "El script ya esta actualizado (version %SCRIPT_VERSION%)"
    goto :eof
)

REM No retroceder: si la release publicada es MENOR que la instalada (release
REM retirada o borrada) no se actualiza. Si alguna version no se puede interpretar
REM (p. ej. "dev") se mantiene el comportamiento anterior y se actualiza.
powershell -NoProfile -Command "try { if ([version]'%SELF_LATEST%' -gt [version]'%SCRIPT_VERSION%') { exit 0 } else { exit 1 } } catch { exit 0 }" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :log INFO "La release publicada del script (%SELF_LATEST%) no es posterior a la actual (%SCRIPT_VERSION%), no se actualiza"
    goto :eof
)

call :log INFO "Nueva version del script disponible: %SELF_LATEST% (actual: %SCRIPT_VERSION%), descargando..."

set "SELF_TEMP=%TEMP%\%SELF_REPO%_selfupdate"
if exist "%SELF_TEMP%" rd /s /q "%SELF_TEMP%" >nul 2>&1
mkdir "%SELF_TEMP%" >nul 2>&1

set "SELF_URL_BAT=https://raw.githubusercontent.com/%SELF_OWNER%/%SELF_REPO%/v%SELF_LATEST%/UpdateStarCitizenES.bat"
set "SELF_URL_VBS=https://raw.githubusercontent.com/%SELF_OWNER%/%SELF_REPO%/v%SELF_LATEST%/SC_Lang_updater.vbs"
set "SELF_URL_SUMS=https://github.com/%SELF_OWNER%/%SELF_REPO%/releases/download/v%SELF_LATEST%/SHA256SUMS.txt"

powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadFile('%SELF_URL_BAT%', '%SELF_TEMP%\UpdateStarCitizenES.bat'); exit 0 } catch { exit 1 }"
if %ERRORLEVEL% neq 0 (
    call :log WARN "No se pudo descargar la nueva version del script, se continua con la actual"
    rd /s /q "%SELF_TEMP%" >nul 2>&1
    goto :eof
)

REM Sanidad minima antes de aplicar la nueva version
findstr /B /C:"@echo off" "%SELF_TEMP%\UpdateStarCitizenES.bat" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :log WARN "La nueva version descargada no parece un .bat valido, se descarta"
    rd /s /q "%SELF_TEMP%" >nul 2>&1
    goto :eof
)

powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadFile('%SELF_URL_VBS%', '%SELF_TEMP%\SC_Lang_updater.vbs') } catch {}" >nul 2>&1

REM Integridad: la release publica un SHA256SUMS.txt (lo genera una GitHub Action).
REM Si los hashes no coinciden, o no se puede verificar (el archivo aun no esta
REM publicado, falla la descarga o falta la entrada), se descarta la actualizacion
REM y se reintenta en la siguiente ejecucion.
REM Protege de descargas corruptas o truncadas; no protege frente a un
REM repositorio comprometido, porque los hashes salen del mismo repositorio.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $c = (New-Object Net.WebClient).DownloadString('%SELF_URL_SUMS%') } catch { exit 3 }; foreach ($f in 'UpdateStarCitizenES.bat','SC_Lang_updater.vbs') { $p = Join-Path '%SELF_TEMP%' $f; if (-not (Test-Path $p)) { continue }; $m = [regex]::Match($c, '(?im)^([0-9a-f]{64})\s+\*?' + [regex]::Escape($f) + '\s*$'); if (-not $m.Success) { exit 3 }; if ((Get-FileHash $p -Algorithm SHA256).Hash -ne $m.Groups[1].Value) { exit 2 } }; exit 0" >nul 2>&1
set "SUMS_RC=%ERRORLEVEL%"
if "%SUMS_RC%"=="2" (
    call :log WARN "El hash de la nueva version NO coincide con SHA256SUMS.txt, se descarta la actualizacion"
    rd /s /q "%SELF_TEMP%" >nul 2>&1
    goto :eof
)
if "%SUMS_RC%"=="0" call :log OK "Integridad de la nueva version verificada (SHA256)"
if not "%SUMS_RC%"=="0" (
    call :log WARN "No se pudo verificar la integridad de la nueva version ^(falta SHA256SUMS.txt o la entrada del archivo^), se descarta y se reintentara en la proxima ejecucion"
    rd /s /q "%SELF_TEMP%" >nul 2>&1
    goto :eof
)

set "RELAUNCH_ARGS="
if "%INTERACTIVE%"=="1" set "RELAUNCH_ARGS=/interactive"

call :log OK "Nueva version %SELF_LATEST% descargada y validada, se aplicara en unos segundos desde un proceso independiente"

REM El helper espera a que ESTE proceso termine, copia los archivos nuevos,
REM deja constancia en el log y relanza el script ya actualizado.
set "APPLY_HELPER=%SELF_TEMP%\_apply_update.bat"
(
    echo @echo off
    echo timeout /t 1 /nobreak ^>nul
    echo copy /y "%SELF_TEMP%\UpdateStarCitizenES.bat" "%~f0" ^>nul
    echo if exist "%SELF_TEMP%\SC_Lang_updater.vbs" copy /y "%SELF_TEMP%\SC_Lang_updater.vbs" "%~dp0SC_Lang_updater.vbs" ^>nul
    echo echo [%%TIME%%] [OK] Script actualizado a la version %SELF_LATEST%, relanzando...^>^>"%LOG_FILE%"
    echo set "SC_SELFUPDATED=1"
    echo call "%~f0" %RELAUNCH_ARGS%
    echo rd /s /q "%SELF_TEMP%" ^>nul 2^>^&1
    echo del "%%~f0"
) > "%APPLY_HELPER%"

start "" /min cmd /c "%APPLY_HELPER%"
set "SELF_UPDATING=1"
goto :eof

REM Registra una instalación encontrada como FOUNDPATH_<n>
REM %1=etiqueta (OK) %2=ruta de la instalacion
:add_found
set /a FOUND_COUNT+=1
set "FOUNDPATH_%FOUND_COUNT%=%~2"
call :log OK "Instalacion %FOUND_COUNT% encontrada: %~2"
goto :eof

REM Imprime "  N) ruta" para el menú interactivo
:print_option
call set "VAL=%%FOUNDPATH_%~1%%"
echo   %~1^) !VAL!
goto :eof

REM Guarda el estado: %1=release instalada %2=ruta elegida %3=hash del zip
REM (PREVIEW_ON = canales de prueba para los que el usuario acepto instalar)
:save_state
(
    echo RELEASE=%~1
    echo INSTALL_PATH=%~2
    echo ZIP_SHA256=%~3
    echo PREVIEW_ON=%PREVIEW_ON%
) > "%STATE_FILE%"
goto :eof

REM Pregunta al usuario: %1=variable donde se guarda la respuesta %2=texto.
REM Unico punto de entrada de teclado del script (los tests lo sustituyen).
:prompt
set /p "%~1=%~2"
goto :eof

REM Marca ROOT_OK si %1 tiene alguna carpeta de canal conocido (para rutas guardadas o manuales)
:root_ok
set "ROOT_OK="
for %%c in (LIVE HOTFIX PTU EPTU) do if exist "%~1\%%c\" set "ROOT_OK=1"
goto :eof

REM Marca CH_OK si el canal %2 esta realmente instalado en la instalacion %1.
REM Exige Data.p4k o StarCitizen.exe: asi se ignoran carpetas sueltas, como la
REM PTU vacia que creaban versiones antiguas del script al copiar todo el ZIP.
:channel_exists
set "CH_OK="
if exist "%~1\%~2\Data.p4k" set "CH_OK=1"
if exist "%~1\%~2\Bin64\StarCitizen.exe" set "CH_OK=1"
goto :eof

REM Calcula TARGETS (canales donde instalar) y, en modo interactivo, pregunta por PTU/EPTU
:resolve_channels
set "TARGETS="
set "NEW_ON="
for %%c in (%CHANNELS_AUTO%) do (
    call :channel_exists "%DEST_DIR%" %%c
    if defined CH_OK set "TARGETS=!TARGETS! %%c"
)
for %%c in (%CHANNELS_PREVIEW%) do call :resolve_preview %%c
if "%INTERACTIVE%"=="1" (
    set "PREVIEW_ON=!NEW_ON!"
    call :save_state "%LOCAL_RELEASE%" "%DEST_DIR%" "%SAVED_HASH%"
)
goto :eof

REM %1=canal de pruebas (PTU/EPTU). Solo se instala si el usuario lo confirmo
:resolve_preview
call :channel_exists "%DEST_DIR%" %~1
set "WAS_ON="
set "MEM=,!PREVIEW_ON!,"
if not "!MEM:,%~1,=!"=="!MEM!" set "WAS_ON=1"
if not defined CH_OK (
    REM Canal no instalado: se conserva la decision por si vuelve a instalarse
    if defined WAS_ON call :append_new_on %~1
    goto :eof
)
if "%INTERACTIVE%"=="1" goto :ask_preview
if defined WAS_ON (
    set "TARGETS=!TARGETS! %~1"
    call :append_new_on %~1
    goto :eof
)
call :log INFO "Canal %~1 detectado pero sin confirmar, se omite. Ejecuta InstalarAutoUpdate.bat para decidir."
goto :eof

:ask_preview
echo.
echo ================================================================
echo   Canal %~1 detectado en esta instalacion
echo ================================================================
echo   AVISO: PTU y EPTU son versiones de pruebas con contenido nuevo
echo   en desarrollo. La traduccion puede no incluir todavia los textos
echo   nuevos, y es posible que veas claves sin traducir o textos en
echo   ingles en ese canal. LIVE y HOTFIX no tienen este problema.
echo   Si respondes N no se instalara ni se actualizara en este canal.
echo.
set "ANS="
if defined WAS_ON (set "DEF=S") else set "DEF=N"
call :prompt ANS "Instalar la traduccion tambien en %~1? (S/N) [!DEF!]: "
if not defined ANS set "ANS=!DEF!"
set "ANS1=!ANS:~0,1!"
if /I "!ANS1!"=="S" goto :preview_yes
if /I "!ANS1!"=="Y" goto :preview_yes
call :log INFO "Canal %~1: el usuario decidio no instalar la traduccion"
goto :eof

:preview_yes
set "TARGETS=!TARGETS! %~1"
call :append_new_on %~1
call :log OK "Canal %~1: el usuario acepto instalar la traduccion"
goto :eof

REM Añade el canal %1 a la lista NEW_ON (canales de prueba aceptados)
:append_new_on
if defined NEW_ON (
    set "NEW_ON=!NEW_ON!,%~1"
) else (
    set "NEW_ON=%~1"
)
goto :eof

REM Copia la traduccion al canal %1. Origen: LIVE y HOTFIX usan los textos de
REM LIVE; PTU y EPTU usan los de PTU (el ZIP trae un global.ini distinto).
:install_channel
set "SRC=LIVE"
if /I "%~1"=="PTU" set "SRC=PTU"
if /I "%~1"=="EPTU" set "SRC=PTU"
if not exist "%TEMP_DIR%\extracted\%SRC%\data\Localization\spanish_(spain)\global.ini" (
    call :log WARN "El ZIP no trae traduccion especifica de %SRC% para %~1, se usa la de LIVE"
    set "SRC=LIVE"
)
if not exist "%DEST_DIR%\%~1\data\Localization\spanish_(spain)" mkdir "%DEST_DIR%\%~1\data\Localization\spanish_(spain)" >nul 2>&1
xcopy "%TEMP_DIR%\extracted\%SRC%\*" "%DEST_DIR%\%~1\" /E /Y /I /Q >nul
if errorlevel 1 (
    call :log ERROR "Fallo al copiar la traduccion en el canal %~1"
    set "COPY_FAIL=1"
) else (
    call :log OK "Traduccion instalada en el canal %~1 (origen: %SRC%)"
)
goto :eof

:log
REM La redireccion va ANTES del echo: si el mensaje acaba en un digito, "2>>" se
REM interpretaria como redireccion del handle 2 y la linea no llegaria al log.
>> "%LOG_FILE%" echo [%TIME%] [%~1] %~2
goto :eof

REM Seguridad: cmd nunca debe leer el bloque PowerShell de abajo como comandos.
exit /b 0

#PS_BRIDGE
# Busca la pre-release "bridge-*" de este repo cuya BASE (linea "BASE=<tag de Thord>"
# en la descripcion) sea la ultima release de Thord. Imprime TAG|URL|SHA256 o nada.
# SC_BRIDGE_JSON (solo tests) sustituye a la llamada a la API de GitHub.
$ErrorActionPreference = 'Stop'
try {
    if ($env:SC_BRIDGE_JSON) {
        $rels = @(Get-Content -Raw -LiteralPath $env:SC_BRIDGE_JSON | ConvertFrom-Json)
    } else {
        $h = @{'User-Agent' = 'StarCitizenES-Updater'; 'Accept' = 'application/vnd.github.v3+json'}
        $rels = @(Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $env:SC_SELF_OWNER + '/' + $env:SC_SELF_REPO + '/releases?per_page=20') -Headers $h)
    }
    # Windows PowerShell 5.1 entrega un array JSON como un unico objeto: se aplana
    $rels = @($rels | ForEach-Object { $_ })
    foreach ($r in $rels) {
        if ($r.draft -or -not $r.prerelease -or $r.tag_name -notlike 'bridge-*') { continue }
        $m = [regex]::Match([string]$r.body, '(?im)^\s*BASE\s*=\s*(\S+)\s*$')
        if (-not $m.Success) { continue }
        if (($m.Groups[1].Value -replace '^v\.?', '') -ne $env:SC_THORD_TAG) { continue }
        $a = @($r.assets | Where-Object { $_.name -eq 'Star_citizen_ES.zip' })[0]
        if (-not $a) { continue }
        $sha = ''
        if ([string]$a.digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha = $Matches[1] }
        $r.tag_name + '|' + $a.browser_download_url + '|' + $sha
        break
    }
} catch { }
#PS_BEGIN
# Deteccion de instalaciones de Star Citizen. Imprime una linea OK|ruta por
# instalacion. Una instalacion es valida si tiene al menos un canal LIVE, HOTFIX,
# PTU o EPTU; en cuales se instala la traduccion lo decide el .bat.
# SC_TEST_ROOTS (rutas separadas por ;) solo existe para los tests: sustituye a
# los discos reales.
$ErrorActionPreference = 'SilentlyContinue'
$channels = 'LIVE','HOTFIX','PTU','EPTU'
$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$state = @{ ok = 0 }

function Test-Marker([string]$dir) {
    (Test-Path -LiteralPath "$dir\Data.p4k") -or (Test-Path -LiteralPath "$dir\Bin64\StarCitizen.exe")
}

# $strict: exige Data.p4k o StarCitizen.exe en algun canal (evita carpetas vacias
# o restos, como el C:\StarCitizen\LIVE o la PTU vacia que creaban versiones antiguas).
function Add-Root([string]$p, [bool]$strict) {
    if (-not $p) { return }
    $p = ($p -replace '\\{2,}', '\').Trim().TrimEnd('\')
    if ($seen.Contains($p.ToLower())) { return }
    $ch = @($channels | Where-Object { Test-Path -LiteralPath "$p\$_" -PathType Container })
    if ($ch.Count -eq 0) { return }
    if ($strict -and -not ($ch | Where-Object { Test-Marker "$p\$_" })) { return }
    [void]$seen.Add($p.ToLower())
    $state.ok++
    "OK|$p"
}

# 1) Log del RSI Launcher: registra la ruta real con la que lanza el juego
#    (p.ej. "Launching Star Citizen PTU from (D:\\Juegos\\StarCitizen\\PTU)").
#    Se lee de lo mas reciente a lo mas antiguo.
$rx = '([A-Za-z]:\\{1,2}[^"<>|?*]+?)\\{1,2}(?:LIVE|PTU|EPTU|HOTFIX|TECH-PREVIEW)(?=["\\/)\s,]|$)'
foreach ($f in 'log.log','log.old.log') {
    $file = Join-Path $env:APPDATA "rsilauncher\logs\$f"
    if (-not (Test-Path -LiteralPath $file)) { continue }
    $lines = @(Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)
    [array]::Reverse($lines)
    foreach ($line in $lines) {
        if ($line -notmatch 'StarCitizen') { continue }
        foreach ($m in [regex]::Matches($line, $rx)) { Add-Root $m.Groups[1].Value $false }
    }
}

if ($env:SC_TEST_ROOTS) {
    $knownRoots = @($env:SC_TEST_ROOTS -split ';' | Where-Object { $_ })
    $scanRoots = $knownRoots
} else {
    $drives = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -in 'Fixed','Removable','Network' })
    $knownRoots = @($drives | ForEach-Object { $_.RootDirectory.FullName })
    $scanRoots = @($drives | Where-Object { $_.DriveType -ne 'Network' } | ForEach-Object { $_.RootDirectory.FullName })
}

# 2) Rutas conocidas en todos los discos
$known = 'Program Files\Roberts Space Industries\StarCitizen',
         'Program Files (x86)\Roberts Space Industries\StarCitizen',
         'StarCitizen', 'Roberts Space Industries\StarCitizen',
         'Games\StarCitizen', 'Games\Roberts Space Industries\StarCitizen'
foreach ($root in $knownRoots) {
    foreach ($k in $known) { Add-Root (Join-Path $root $k) $true }
}

# 3) Escaneo acotado (cuatro niveles) buscando carpetas llamadas StarCitizen.
#    Cubre bibliotecas personalizadas del launcher (D:\Juegos\RSI\StarCitizen...).
#    Solo si lo anterior no encontro ninguna: es la parte lenta (~15 s en C:).
if ($state.ok -eq 0) {
    $skip = '^(Windows|\$Recycle\.Bin|System Volume Information|ProgramData|AppData|Recovery|PerfLogs|WinSxS|node_modules|\..*)$'
    foreach ($root in $scanRoots) {
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@($root, 0))
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            try { $subs = [IO.Directory]::EnumerateDirectories($item[0]) } catch { continue }
            try {
                foreach ($sub in $subs) {
                    $name = [IO.Path]::GetFileName($sub)
                    if ($name -match '^Star ?Citizen$') { Add-Root $sub $true; continue }
                    if ($item[1] -lt 3 -and $name -notmatch $skip) { $queue.Enqueue(@($sub, ($item[1] + 1))) }
                }
            } catch { }
        }
    }
}
