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

REM === Auto-actualizacion del propio script (contra releases de este repo,
REM     no commits de main, para no desplegar cambios sin marcar como listos) ===
set "SCRIPT_VERSION=0.3.0"
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
if exist "%STATE_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%k in ("%STATE_FILE%") do (
        if /I "%%k"=="RELEASE" set "LOCAL_RELEASE=%%l"
        if /I "%%k"=="INSTALL_PATH" set "SAVED_PATH=%%l"
        if /I "%%k"=="ZIP_SHA256" set "SAVED_HASH=%%l"
    )
)

REM === Buscar TODAS las instalaciones de Star Citizen ===
REM La deteccion vive en el bloque PowerShell del final de este archivo y
REM mira, por orden: log del RSI Launcher, rutas conocidas y un escaneo
REM acotado de los discos. Cada linea que devuelve es TAG|ruta.
set "FOUND_COUNT=0"
REM Con una ruta guardada valida no hace falta detectar nada (ejecuciones silenciosas)
if not defined SAVED_PATH goto :detect_installs
if exist "%SAVED_PATH%\LIVE" goto :pick_install

:detect_installs
call :log INFO "Buscando instalaciones de Star Citizen (launcher, rutas conocidas y escaneo de discos)..."
for /f "usebackq tokens=1,* delims=|" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$s.IndexOf('#PS_'+'BEGIN'); & ([scriptblock]::Create($s.Substring($i)))"`) do call :add_found "%%a" "%%b"
call :log INFO "Instalaciones encontradas: %FOUND_COUNT%"

:pick_install
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
call :log WARN "No se encontro Star Citizen automaticamente"
if not "%INTERACTIVE%"=="1" goto :no_install_abort
echo.
echo No se ha encontrado Star Citizen automaticamente.
echo Indica la carpeta de instalacion: la que contiene la carpeta LIVE
echo ^(ejemplo: D:\Roberts Space Industries\StarCitizen^)
set "MANUAL_TRIES=0"

:ask_manual_path
set /a MANUAL_TRIES+=1
set "MANUAL_PATH="
set /p "MANUAL_PATH=Ruta (vacio para cancelar): "
if not defined MANUAL_PATH goto :no_install_abort
set "MANUAL_PATH=%MANUAL_PATH:"=%"
if "%MANUAL_PATH:~-1%"=="\" set "MANUAL_PATH=%MANUAL_PATH:~0,-1%"
if /I "%MANUAL_PATH:~-5%"=="\LIVE" set "MANUAL_PATH=%MANUAL_PATH:~0,-5%"
if exist "%MANUAL_PATH%\LIVE\" goto :manual_path_ok
echo No existe la carpeta "%MANUAL_PATH%\LIVE", revisa la ruta.
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

call :log INFO "Nueva version del script disponible: %SELF_LATEST% (actual: %SCRIPT_VERSION%), descargando..."

set "SELF_TEMP=%TEMP%\%SELF_REPO%_selfupdate"
if exist "%SELF_TEMP%" rd /s /q "%SELF_TEMP%" >nul 2>&1
mkdir "%SELF_TEMP%" >nul 2>&1

set "SELF_URL_BAT=https://raw.githubusercontent.com/%SELF_OWNER%/%SELF_REPO%/v%SELF_LATEST%/UpdateStarCitizenES.bat"
set "SELF_URL_VBS=https://raw.githubusercontent.com/%SELF_OWNER%/%SELF_REPO%/v%SELF_LATEST%/SC_Lang_updater.vbs"

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
REM %1=OK|NOLIVE (lo decide el bloque PowerShell) %2=ruta de la instalacion
:add_found
if /I "%~1"=="NOLIVE" (
    call :log WARN "Instalacion sin carpeta LIVE (solo otros canales), se ignora: %~2"
    goto :eof
)
set /a FOUND_COUNT+=1
set "FOUNDPATH_%FOUND_COUNT%=%~2"
call :log OK "Instalacion %FOUND_COUNT% encontrada: %~2"
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

REM Seguridad: cmd nunca debe leer el bloque PowerShell de abajo como comandos.
exit /b 0

#PS_BEGIN
# Deteccion de instalaciones de Star Citizen. Imprime una linea TAG|ruta por
# instalacion: OK si tiene carpeta LIVE, NOLIVE si solo tiene otros canales.
$ErrorActionPreference = 'SilentlyContinue'
$channels = 'LIVE','PTU','EPTU','HOTFIX','TECH-PREVIEW'
$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$state = @{ ok = 0 }

function Test-Marker([string]$dir) {
    (Test-Path -LiteralPath "$dir\Data.p4k") -or (Test-Path -LiteralPath "$dir\Bin64\StarCitizen.exe")
}

# $strict: exige Data.p4k o StarCitizen.exe en algun canal (evita carpetas vacias
# o restos, como un C:\StarCitizen\LIVE creado a mano por versiones antiguas).
function Add-Root([string]$p, [bool]$strict) {
    if (-not $p) { return }
    $p = ($p -replace '\\{2,}', '\').Trim().TrimEnd('\')
    if ($seen.Contains($p.ToLower())) { return }
    $ch = @($channels | Where-Object { Test-Path -LiteralPath "$p\$_" -PathType Container })
    if ($ch.Count -eq 0) { return }
    if ($strict -and -not ($ch | Where-Object { Test-Marker "$p\$_" })) { return }
    [void]$seen.Add($p.ToLower())
    $tag = if ($ch -contains 'LIVE') { $state.ok++; 'OK' } else { 'NOLIVE' }
    "$tag|$p"
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

$drives = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -in 'Fixed','Removable','Network' })

# 2) Rutas conocidas en todos los discos
$known = 'Program Files\Roberts Space Industries\StarCitizen',
         'Program Files (x86)\Roberts Space Industries\StarCitizen',
         'StarCitizen', 'Roberts Space Industries\StarCitizen',
         'Games\StarCitizen', 'Games\Roberts Space Industries\StarCitizen'
foreach ($d in $drives) {
    foreach ($k in $known) { Add-Root (Join-Path $d.RootDirectory.FullName $k) $true }
}

# 3) Escaneo acotado (cuatro niveles) buscando carpetas llamadas StarCitizen.
#    Cubre bibliotecas personalizadas del launcher (D:\Juegos\RSI\StarCitizen...).
#    Solo si lo anterior no encontro ninguna: es la parte lenta (~15 s en C:).
if ($state.ok -eq 0) {
    $skip = '^(Windows|\$Recycle\.Bin|System Volume Information|ProgramData|AppData|Recovery|PerfLogs|WinSxS|node_modules|\..*)$'
    foreach ($d in ($drives | Where-Object { $_.DriveType -ne 'Network' })) {
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@($d.RootDirectory.FullName, 0))
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
