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
set "SCRIPT_DIR=C:\Scripts"
set "SCRIPT_NAME=UpdateStarCitizenES.bat"
set "SCRIPT_PATH=%SCRIPT_DIR%\%SCRIPT_NAME%"

REM === Crear carpeta de scripts ===
echo [1/3] Creando carpeta de scripts...
if not exist "%SCRIPT_DIR%" (
    mkdir "%SCRIPT_DIR%"
    echo [OK] Carpeta creada: %SCRIPT_DIR%
) else (
    echo [OK] Carpeta ya existe: %SCRIPT_DIR%
)
echo.

REM === Crear script de actualización ===
echo [2/3] Creando script de actualización...

REM Crear archivo temporal con el script
set "TEMP_SCRIPT=%TEMP%\update_script_temp.bat"

> "%TEMP_SCRIPT%" echo @echo off
>> "%TEMP_SCRIPT%" echo setlocal enabledelayedexpansion
>> "%TEMP_SCRIPT%" echo REM ========================================
>> "%TEMP_SCRIPT%" echo REM Script de Actualización Star Citizen ES
>> "%TEMP_SCRIPT%" echo REM ========================================
>> "%TEMP_SCRIPT%" echo REM === CONFIGURACIÓN ===
>> "%TEMP_SCRIPT%" echo set "GITHUB_OWNER=Thord82"
>> "%TEMP_SCRIPT%" echo set "GITHUB_REPO=Star_citizen_ES"
>> "%TEMP_SCRIPT%" echo set "ZIP_NAME=Star_citizen_ES.zip"
>> "%TEMP_SCRIPT%" echo set "RELEASE_FILE=%%USERPROFILE%%\%%GITHUB_REPO%%_last_release.txt"
>> "%TEMP_SCRIPT%" echo set "LOG_FILE=%%USERPROFILE%%\%%GITHUB_REPO%%_update_log.txt"
>> "%TEMP_SCRIPT%" echo REM === Escribir en log ===
>> "%TEMP_SCRIPT%" echo echo ========================================^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo echo Inicio: %%DATE%% %%TIME%% ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo echo ========================================^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo REM === Buscar ruta de instalación de Star Citizen en TODOS los discos ===
>> "%TEMP_SCRIPT%" echo set "DEST_DIR="
>> "%TEMP_SCRIPT%" echo echo Buscando Star Citizen en todos los discos... ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo for %%%%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
>> "%TEMP_SCRIPT%" echo     if exist "%%%%d:\" (
>> "%TEMP_SCRIPT%" echo         echo Comprobando disco %%%%d: ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo         if exist "%%%%d:\Program Files\Roberts Space Industries\StarCitizen\LIVE" (
>> "%TEMP_SCRIPT%" echo             set "DEST_DIR=%%%%d:\Program Files\Roberts Space Industries\StarCitizen"
>> "%TEMP_SCRIPT%" echo             echo ENCONTRADO en %%%%d:\Program Files ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo             goto :found
>> "%TEMP_SCRIPT%" echo         )
>> "%TEMP_SCRIPT%" echo         if exist "%%%%d:\StarCitizen\LIVE" (
>> "%TEMP_SCRIPT%" echo             set "DEST_DIR=%%%%d:\StarCitizen"
>> "%TEMP_SCRIPT%" echo             echo ENCONTRADO en %%%%d:\StarCitizen ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo             goto :found
>> "%TEMP_SCRIPT%" echo         )
>> "%TEMP_SCRIPT%" echo         if exist "%%%%d:\Roberts Space Industries\StarCitizen\LIVE" (
>> "%TEMP_SCRIPT%" echo             set "DEST_DIR=%%%%d:\Roberts Space Industries\StarCitizen"
>> "%TEMP_SCRIPT%" echo             echo ENCONTRADO en %%%%d:\Roberts Space Industries ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo             goto :found
>> "%TEMP_SCRIPT%" echo         )
>> "%TEMP_SCRIPT%" echo         if exist "%%%%d:\Games\StarCitizen\LIVE" (
>> "%TEMP_SCRIPT%" echo             set "DEST_DIR=%%%%d:\Games\StarCitizen"
>> "%TEMP_SCRIPT%" echo             echo ENCONTRADO en %%%%d:\Games ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo             goto :found
>> "%TEMP_SCRIPT%" echo         )
>> "%TEMP_SCRIPT%" echo     )
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo :found
>> "%TEMP_SCRIPT%" echo if not defined DEST_DIR (
>> "%TEMP_SCRIPT%" echo     set "DEST_DIR=C:\StarCitizen"
>> "%TEMP_SCRIPT%" echo     echo AVISO: No se encontró Star Citizen, usando ruta por defecto ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo ) else (
>> "%TEMP_SCRIPT%" echo     echo Ruta detectada correctamente ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo echo Destino: "%%DEST_DIR%%" ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo REM === Verificar conexión a internet ===
>> "%TEMP_SCRIPT%" echo ping -n 1 github.com ^>nul 2^>^&1
>> "%TEMP_SCRIPT%" echo if %%ERRORLEVEL%% neq 0 (
>> "%TEMP_SCRIPT%" echo     echo Sin conexión a internet ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     exit /b 0
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Obtener última release desde GitHub ===
>> "%TEMP_SCRIPT%" echo for /f "usebackq delims=" %%%%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$owner = '%%GITHUB_OWNER%%'; $repo = '%%GITHUB_REPO%%'; $uri = 'https://api.github.com/repos/' + $owner + '/' + $repo + '/releases/latest'; $headers = @{'User-Agent' = 'StarCitizenES-Updater'; 'Accept' = 'application/vnd.github.v3+json'}; try { $resp = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop; $tag = $resp.tag_name; $tag = $tag -replace '^v\.?', ''; $tag } catch { 'no-release-yet' }"`) do set "LAST_RELEASE=%%%%a"
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo if not defined LAST_RELEASE (
>> "%TEMP_SCRIPT%" echo     echo ERROR: No se pudo obtener la versión de GitHub ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     set "LAST_RELEASE=no-release-yet"
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo echo Última release remota: %%LAST_RELEASE%% ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Leer release local ===
>> "%TEMP_SCRIPT%" echo set "LOCAL_RELEASE=none"
>> "%TEMP_SCRIPT%" echo if exist "!RELEASE_FILE!" (
>> "%TEMP_SCRIPT%" echo     for /f "usebackq tokens=*" %%%%b in ("!RELEASE_FILE!") do set "LOCAL_RELEASE=%%%%b"
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo if "!LOCAL_RELEASE!"=="none" (
>> "%TEMP_SCRIPT%" echo     echo Primera instalación ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo ) else (
>> "%TEMP_SCRIPT%" echo     echo Release local: !LOCAL_RELEASE! ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Comparar releases ===
>> "%TEMP_SCRIPT%" echo if "%%LAST_RELEASE%%"=="!LOCAL_RELEASE!" (
>> "%TEMP_SCRIPT%" echo     echo Ya actualizado ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     exit /b 0
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo if "%%LAST_RELEASE%%"=="no-release-yet" (
>> "%TEMP_SCRIPT%" echo     echo No hay releases disponibles ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     exit /b 0
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo echo Nueva actualización detectada (%%LAST_RELEASE%%) ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Crear carpeta temporal ===
>> "%TEMP_SCRIPT%" echo set "TEMP_DIR=%%USERPROFILE%%\Downloads\%%GITHUB_REPO%%_temp"
>> "%TEMP_SCRIPT%" echo if exist "%%TEMP_DIR%%" rd /s /q "%%TEMP_DIR%%"
>> "%TEMP_SCRIPT%" echo mkdir "%%TEMP_DIR%%" ^>nul 2^>^&1
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Descargar ZIP ===
>> "%TEMP_SCRIPT%" echo set "ZIP_URL=https://github.com/%%GITHUB_OWNER%%/%%GITHUB_REPO%%/releases/latest/download/%%ZIP_NAME%%"
>> "%TEMP_SCRIPT%" echo set "ZIP_FILE=%%TEMP_DIR%%\%%ZIP_NAME%%"
>> "%TEMP_SCRIPT%" echo echo Descargando actualización... ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadFile('%%ZIP_URL%%', '%%ZIP_FILE%%'); exit 0 } catch { exit 1 }"
>> "%TEMP_SCRIPT%" echo if %%ERRORLEVEL%% neq 0 (
>> "%TEMP_SCRIPT%" echo     echo ERROR: Falló la descarga ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     rd /s /q "%%TEMP_DIR%%"
>> "%TEMP_SCRIPT%" echo     exit /b 1
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo REM === Expandir ZIP ===
>> "%TEMP_SCRIPT%" echo echo Extrayendo archivos... ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo powershell -NoProfile -Command "try { Expand-Archive -Force '%%ZIP_FILE%%' '%%TEMP_DIR%%\extracted' } catch { exit 1 }"
>> "%TEMP_SCRIPT%" echo if %%ERRORLEVEL%% neq 0 (
>> "%TEMP_SCRIPT%" echo     echo ERROR: Falló al expandir ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo     rd /s /q "%%TEMP_DIR%%"
>> "%TEMP_SCRIPT%" echo     exit /b 1
>> "%TEMP_SCRIPT%" echo )
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Crear directorio destino si no existe ===
>> "%TEMP_SCRIPT%" echo if not exist "%%DEST_DIR%%" mkdir "%%DEST_DIR%%"
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Copiar archivos ===
>> "%TEMP_SCRIPT%" echo echo Instalando traducción... ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo xcopy "%%TEMP_DIR%%\extracted\*" "%%DEST_DIR%%\" /E /Y /I
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Guardar nueva release ===
>> "%TEMP_SCRIPT%" echo powershell -NoProfile -ExecutionPolicy Bypass -Command "$ver = '!LAST_RELEASE!'; $ver | Out-File -FilePath '%%RELEASE_FILE%%' -Encoding ascii -NoNewline"
>> "%TEMP_SCRIPT%" echo.
>> "%TEMP_SCRIPT%" echo REM === Limpieza ===
>> "%TEMP_SCRIPT%" echo rd /s /q "%%TEMP_DIR%%" ^>nul 2^>^&1
>> "%TEMP_SCRIPT%" echo echo Actualización completada: %%LAST_RELEASE%% ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo echo ======================================== ^>^> "%%LOG_FILE%%"
>> "%TEMP_SCRIPT%" echo exit /b 0

REM Copiar el script temporal a la ubicación final
copy /Y "%TEMP_SCRIPT%" "%SCRIPT_PATH%" >nul

REM Limpiar archivo temporal
del "%TEMP_SCRIPT%" >nul 2>&1

if exist "%SCRIPT_PATH%" (
    echo [OK] Script creado correctamente
) else (
    echo [ERROR] No se pudo crear el script
    pause
    exit /b 1
)
echo.

REM === Crear tarea programada ===
echo [3/3] Configurando tarea programada...

REM Eliminar tarea existente si existe
schtasks /query /tn "UpdateStarCitizenES" >nul 2>&1
if %errorLevel% equ 0 (
    echo [INFO] Eliminando tarea existente...
    schtasks /delete /tn "UpdateStarCitizenES" /f >nul 2>&1
)

REM Crear nueva tarea
echo [INFO] Creando tarea programada...
schtasks /create /tn "UpdateStarCitizenES" /tr "\"%SCRIPT_PATH%\"" /sc onlogon /rl highest /f >nul 2>&1

if %errorLevel% equ 0 (
    echo [OK] Tarea programada creada exitosamente
) else (
    echo [ERROR] No se pudo crear la tarea programada
    echo         Puedes configurarla manualmente desde el Programador de Tareas
)
echo.

echo ================================================
echo   INSTALACIÓN COMPLETADA
echo ================================================
echo.
echo Configuración:
echo   - Script: %SCRIPT_PATH%
echo   - Tarea: UpdateStarCitizenES
echo   - Log: %USERPROFILE%\Star_citizen_ES_update_log.txt
echo.
echo.
echo ========================================
echo   EJECUTANDO PRIMERA ACTUALIZACIÓN
echo ========================================
echo.

REM Ejecutar el script por primera vez - SIN call para ver la salida
"%SCRIPT_PATH%"

echo.
echo ========================================
echo   PRIMERA ACTUALIZACIÓN COMPLETADA
echo ========================================
echo.
echo Revisa el log para detalles:
echo   %USERPROFILE%\Star_citizen_ES_update_log.txt
echo.
echo La próxima actualización será automática al iniciar Windows
echo.
echo Para gestionar la tarea programada:
echo   - Ejecutar:    schtasks /run /tn "UpdateStarCitizenES"
echo   - Desactivar:  schtasks /change /tn "UpdateStarCitizenES" /disable
echo   - Eliminar:    schtasks /delete /tn "UpdateStarCitizenES" /f
echo.
pause