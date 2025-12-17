@echo off
echo ================================================
echo   INSTALADOR - Star Citizen ES Auto-Update
echo ================================================
echo.

REM Verificar privilegios de administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script necesita ejecutarse como Administrador.
    echo Por favor, haz clic derecho y selecciona "Ejecutar como administrador"
    pause
    exit /b 1
)

echo [1/4] Creando carpeta de scripts...
set "SCRIPT_DIR=C:\Scripts"
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"

echo [2/4] Guardando script de actualizacion...
(
echo @echo off
echo setlocal enabledelayedexpansion
echo REM ========================================
echo REM Script de Actualización Star Citizen ES
echo REM ========================================
echo.
echo REM === CONFIGURACIÓN ===
echo set "GITHUB_OWNER=Thord82"
echo set "GITHUB_REPO=Star_citizen_ES"
echo set "ZIP_NAME=Star_citizen_ES.zip"
echo set "COMMIT_FILE=%%USERPROFILE%%\%%GITHUB_REPO%%_last_commit.txt"
echo set "LOG_FILE=%%USERPROFILE%%\%%GITHUB_REPO%%_update_log.txt"
echo.
echo REM === Escribir en log ===
echo echo ========================================^>^> "%%LOG_FILE%%"
echo echo Inicio: %%DATE%% %%TIME%% ^>^> "%%LOG_FILE%%"
echo echo ========================================^>^> "%%LOG_FILE%%"
echo.
echo REM === Buscar ruta de instalación de Star Citizen en TODOS los discos ===
echo set "DEST_DIR="
echo echo Buscando Star Citizen en todos los discos... ^>^> "%%LOG_FILE%%"
echo.
echo REM Buscar en todas las unidades ^(C: hasta Z:^)
echo for %%%%d in ^(C D E F G H I J K L M N O P Q R S T U V W X Y Z^) do ^(
echo     if exist "%%%%d:\" ^(
echo         echo Comprobando disco %%%%d: ^>^> "%%LOG_FILE%%"
echo.
echo         REM Buscar en Program Files
echo         if exist "%%%%d:\StarCitizen\LIVE\data" ^(
echo             set "DEST_DIR=%%%%d:\StarCitizen\LIVE\data\Localization\spanish_^(spain^)"
echo             echo ENCONTRADO en %%%%d:\Program Files ^>^> "%%LOG_FILE%%"
echo             goto :found
echo         ^)
echo.
echo         REM Buscar en carpeta directa
echo         if exist "%%%%d:\StarCitizen\LIVE\data" ^(
echo             set "DEST_DIR=%%%%d:\StarCitizen\LIVE\data\Localization\spanish_^(spain^)"
echo             echo ENCONTRADO en %%%%d:\StarCitizen ^>^> "%%LOG_FILE%%"
echo             goto :found
echo         ^)
echo.
echo         REM Buscar en RSI Launcher
echo         if exist "%%%%d:\StarCitizen\LIVE\data" ^(
echo             set "DEST_DIR=%%%%d:\Roberts Space Industries\StarCitizen\LIVE\data\Localization\spanish_^(spain^)"
echo             echo ENCONTRADO en %%%%d:\Roberts Space Industries ^>^> "%%LOG_FILE%%"
echo             goto :found
echo         ^)
echo.
echo         REM Buscar en Games
echo         if exist "%%%%d:\Games\StarCitizen\LIVE\data" ^(
echo             set "DEST_DIR=%%%%d:\Games\StarCitizen\LIVE\data\Localization\spanish_^(spain^)"
echo             echo ENCONTRADO en %%%%d:\Games ^>^> "%%LOG_FILE%%"
echo             goto :found
echo         ^)
echo     ^)
echo ^)
echo.
echo :found
echo REM Si no se encuentra, usar ruta por defecto
echo if not defined DEST_DIR ^(
echo     set "DEST_DIR=C:\StarCitizen"
echo     echo AVISO: No se encontró Star Citizen, usando ruta por defecto ^>^> "%%LOG_FILE%%"
echo ^) else ^(
echo     echo Ruta detectada correctamente ^>^> "%%LOG_FILE%%"
echo ^)
echo.
echo echo Destino: "%%DEST_DIR%%" ^>^> "%%LOG_FILE%%"
echo.
echo REM === Verificar conexión a internet ===
echo ping -n 1 github.com ^>nul 2^>^&1
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo Sin conexión a internet ^>^> "%%LOG_FILE%%"
echo     exit /b 0
echo ^)
echo.
echo REM === Obtener último commit desde GitHub ===
echo powershell -NoProfile -Command "try { $json = Invoke-WebRequest -UseBasicParsing 'https://api.github.com/repos/%%GITHUB_OWNER%%/%%GITHUB_REPO%%/commits' | ConvertFrom-Json; $c = $json[0].sha; Write-Output $c } catch { exit 1 }" ^> "%%USERPROFILE%%\%%GITHUB_REPO%%_last_commit_tmp.txt" 2^>nul
echo.
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo ERROR: No se pudo obtener info de GitHub ^>^> "%%LOG_FILE%%"
echo     del "%%USERPROFILE%%\%%GITHUB_REPO%%_last_commit_tmp.txt" 2^>nul
echo     exit /b 0
echo ^)
echo.
echo for /f "delims=" %%%%a in ^("%%USERPROFILE%%\%%GITHUB_REPO%%_last_commit_tmp.txt"^) do set "LAST_COMMIT=%%%%a"
echo del "%%USERPROFILE%%\%%GITHUB_REPO%%_last_commit_tmp.txt" 2^>nul
echo echo Último commit remoto: %%LAST_COMMIT%% ^>^> "%%LOG_FILE%%"
echo.
echo REM === Leer commit local ===
echo if exist "%%COMMIT_FILE%%" ^(
echo     set /p "LOCAL_COMMIT="^<"%%COMMIT_FILE%%"
echo     echo Commit local: %%LOCAL_COMMIT%% ^>^> "%%LOG_FILE%%"
echo ^) else ^(
echo     echo Primera instalación ^>^> "%%LOG_FILE%%"
echo     set "LOCAL_COMMIT=none"
echo ^)
echo.
echo REM === Comparar commits ===
echo if "%%LAST_COMMIT%%"=="%%LOCAL_COMMIT%%" ^(
echo     echo Ya actualizado ^>^> "%%LOG_FILE%%"
echo     exit /b 0
echo ^)
echo.
echo echo Nueva actualización detectada ^>^> "%%LOG_FILE%%"
echo.
echo REM === Crear backup si existe instalación previa ===
echo if exist "%%DEST_DIR%%" ^(
echo     set "BACKUP_DIR=%%DEST_DIR%%_backup_%%date:~-4%%%%date:~3,2%%%%date:~0,2%%"
echo     echo Creando backup en: !BACKUP_DIR! ^>^> "%%LOG_FILE%%"
echo     xcopy "%%DEST_DIR%%\*" "!BACKUP_DIR!\" /E /Y /I ^>nul 2^>^&1
echo ^)
echo.
echo REM === Crear carpeta temporal ===
echo set "TEMP_DIR=%%USERPROFILE%%\Downloads\%%GITHUB_REPO%%_temp"
echo if exist "%%TEMP_DIR%%" rd /s /q "%%TEMP_DIR%%"
echo mkdir "%%TEMP_DIR%%" ^>nul 2^>^&1
echo.
echo REM === Descargar ZIP ===
echo set "ZIP_URL=https://github.com/%%GITHUB_OWNER%%/%%GITHUB_REPO%%/releases/latest/download/%%ZIP_NAME%%"
echo set "ZIP_FILE=%%TEMP_DIR%%\%%ZIP_NAME%%"
echo echo Descargando actualización... ^>^> "%%LOG_FILE%%"
echo.
echo powershell -NoProfile -Command "try { ^(New-Object Net.WebClient^).DownloadFile^('%%ZIP_URL%%', '%%ZIP_FILE%%'^); exit 0 } catch { exit 1 }"
echo.
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo ERROR: Falló la descarga ^>^> "%%LOG_FILE%%"
echo     rd /s /q "%%TEMP_DIR%%"
echo     exit /b 1
echo ^)
echo.
echo REM === Expandir ZIP ===
echo echo Extrayendo archivos... ^>^> "%%LOG_FILE%%"
echo powershell -NoProfile -Command "try { Expand-Archive -Force '%%ZIP_FILE%%' '%%TEMP_DIR%%\extracted' } catch { exit 1 }"
echo.
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo ERROR: Falló al expandir ^>^> "%%LOG_FILE%%"
echo     rd /s /q "%%TEMP_DIR%%"
echo     exit /b 1
echo ^)
echo.
echo REM === Crear directorio destino si no existe ===
echo if not exist "%%DEST_DIR%%" mkdir "%%DEST_DIR%%"
echo.
echo REM === Copiar archivos ===
echo echo Instalando traducción... ^>^> "%%LOG_FILE%%"
echo xcopy "%%TEMP_DIR%%\extracted\*" "%%DEST_DIR%%\" /E /Y /I
echo.
echo REM === Guardar nuevo commit ===
echo echo %%LAST_COMMIT%% ^> "%%COMMIT_FILE%%"
echo.
echo REM === Limpieza ===
echo rd /s /q "%%TEMP_DIR%%" ^>nul 2^>^&1
echo.
echo echo Actualización completada: %%LAST_COMMIT%% ^>^> "%%LOG_FILE%%"
echo echo ======================================== ^>^> "%%LOG_FILE%%"
echo.
echo exit /b 0
) > "%SCRIPT_DIR%\UpdateStarCitizenES.bat"

echo [3/4] Creando tarea programada...
schtasks /create /tn "UpdateStarCitizenES" /xml "%~dp0UpdateStarCitizenES.xml" /f >nul 2>&1

if %errorLevel% equ 0 (
    echo [4/4] Tarea creada exitosamente!
) else (
    echo [4/4] Creando tarea manualmente...
    schtasks /create /tn "UpdateStarCitizenES" /tr "\"%SCRIPT_DIR%\UpdateStarCitizenES.bat\"" /sc onlogon /rl highest /f
)

echo.
echo ================================================
echo   INSTALACION COMPLETADA
echo ================================================
echo.
echo Script instalado en: %SCRIPT_DIR%\UpdateStarCitizenES.bat
echo Tarea programada: UpdateStarCitizenES
echo.
echo La actualizacion se ejecutara automaticamente:
echo   - Al iniciar sesion en Windows
echo   - Puedes ejecutarla manualmente cuando quieras
echo.
echo Para ver el log de actualizaciones:
echo   %USERPROFILE%\Star_citizen_ES_update_log.txt
echo.
pause