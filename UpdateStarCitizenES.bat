@echo on
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
REM === Escribir en log ===
echo ========================================>> "%LOG_FILE%"
echo Inicio: %DATE% %TIME% >> "%LOG_FILE%"
echo ========================================>> "%LOG_FILE%"
REM === Buscar ruta de instalación de Star Citizen en TODOS los discos ===
set "DEST_DIR="
echo Buscando Star Citizen en todos los discos... >> "%LOG_FILE%"
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\" (
        echo Comprobando disco %%d: >> "%LOG_FILE%"
        if exist "%%d:\Program Files\Roberts Space Industries\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Program Files\Roberts Space Industries\StarCitizen"
            echo ENCONTRADO en %%d:\Program Files >> "%LOG_FILE%"
            goto :found
        )
        if exist "%%d:\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\StarCitizen"
            echo ENCONTRADO en %%d:\StarCitizen >> "%LOG_FILE%"
            goto :found
        )
        if exist "%%d:\Roberts Space Industries\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Roberts Space Industries\StarCitizen"
            echo ENCONTRADO en %%d:\Roberts Space Industries >> "%LOG_FILE%"
            goto :found
        )
        if exist "%%d:\Games\StarCitizen\LIVE" (
            set "DEST_DIR=%%d:\Games\StarCitizen"
            echo ENCONTRADO en %%d:\Games >> "%LOG_FILE%"
            goto :found
        )
    )
)
:found
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

REM === Obtener última release (versión) desde GitHub ===
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
    echo ERROR: No se pudo obtener la versión de GitHub >> "%LOG_FILE%"
    set "LAST_RELEASE=no-release-yet"
)

echo Última release remota: %LAST_RELEASE% >> "%LOG_FILE%"

echo.
echo ========================================
echo DEBUG: Última release obtenida de GitHub
echo LAST_RELEASE = [%LAST_RELEASE%]
echo Longitud: 
echo "%LAST_RELEASE%" | find /v "" | find /c /v ""
echo ========================================
pause

REM === Leer release local (con trim total de espacios) ===
set "LOCAL_RELEASE=none"
if exist "!RELEASE_FILE!" (
    for /f "usebackq tokens=*" %%b in ("!RELEASE_FILE!") do set "LOCAL_RELEASE=%%b"
)
if "!LOCAL_RELEASE!"=="none" (
    echo Primera instalación >> "%LOG_FILE%"
) else (
    echo Release local: !LOCAL_RELEASE! >> "%LOG_FILE%"
)

echo.
echo ========================================
echo DEBUG: Leyendo archivo local %RELEASE_FILE%
type "%RELEASE_FILE%"
echo.
echo LOCAL_RELEASE = [!LOCAL_RELEASE!]
if defined LOCAL_RELEASE (
    echo La variable LOCAL_RELEASE está definida
) else (
    echo La variable LOCAL_RELEASE está VACÍA o no definida
)
echo ========================================
pause

REM === Comparar releases ===
if "%LAST_RELEASE%"=="!LOCAL_RELEASE!" (
    echo Ya actualizado >> "%LOG_FILE%"
    exit /b 0
)
if "%LAST_RELEASE%"=="no-release-yet" (
    echo No hay releases disponibles >> "%LOG_FILE%"
    exit /b 0
)
echo Nueva actualización detectada (%LAST_RELEASE%) >> "%LOG_FILE%"

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

REM === Guardar nueva release ===
REM echo %LAST_RELEASE% > "%RELEASE_FILE%"
REM <nul set /p =!LAST_RELEASE! > "%RELEASE_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ver = '!LAST_RELEASE!'; " ^
    "$ver | Out-File -FilePath '%RELEASE_FILE%' -Encoding ascii -NoNewline"

REM === Limpieza ===
rd /s /q "%TEMP_DIR%" >nul 2>&1
echo Actualización completada: %LAST_RELEASE% >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"
exit /b 0