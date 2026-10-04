# Tests de extremo a extremo del script sobre instalaciones simuladas. Todo ocurre en
# carpetas temporales (USERPROFILE, APPDATA y las raices de busqueda estan aisladas),
# pero SI usa la red: descarga la traduccion real de Thord82/Star_citizen_ES.
. "$PSScriptRoot\common.ps1"

$t = New-TestDir 'flows'

# Copia del script para pruebas: sin autoactualizacion y con las respuestas del
# usuario tomadas de variables de entorno TEST_ANS_1, TEST_ANS_2... (en lugar del teclado)
$txt = [IO.File]::ReadAllText($MainBat, [Text.Encoding]::UTF8)
$selfLine = 'set "SELF_REPO=SC-LangUPD_ES"'
$promptLine = 'set /p "%~1=%~2"'
if (-not $txt.Contains($selfLine) -or -not $txt.Contains($promptLine)) {
    Write-Host '  FAIL  el .bat ya no contiene las lineas que este test sustituye (SELF_REPO / :prompt)' -ForegroundColor Red
    exit 1
}
$emptyRoot = Join-Path $t 'raiz-vacia'
New-Item -ItemType Directory $emptyRoot | Out-Null
$txt = $txt.Replace($selfLine, 'set "SELF_REPO=zz-no-existe"')
$txt = $txt.Replace($promptLine, "set /a PROMPT_N+=1`r`ncall set `"%~1=%%TEST_ANS_%PROMPT_N%%%`"")
$copy = Join-Path $t 'script.bat'
[IO.File]::WriteAllText($copy, $txt, (New-Object Text.UTF8Encoding($false)))

function Invoke-Flow([string]$name, [string]$flags, [string[]]$answers, [string[]]$roots, [string]$batPath = $copy) {
    $profileDir = Join-Path $t "perfil-$name"
    $appdata = Join-Path $t "appdata-$name"
    New-Item -ItemType Directory $profileDir, $appdata -Force | Out-Null
    $saved = @{}
    foreach ($v in 'USERPROFILE', 'APPDATA', 'SC_TEST_ROOTS') { $saved[$v] = [Environment]::GetEnvironmentVariable($v) }
    foreach ($k in 1..6) { [Environment]::SetEnvironmentVariable("TEST_ANS_$k", $null) }
    $i = 0
    foreach ($a in $answers) { $i++; [Environment]::SetEnvironmentVariable("TEST_ANS_$i", $a) }
    $env:USERPROFILE = $profileDir
    $env:APPDATA = $appdata
    $env:SC_TEST_ROOTS = ($roots -join ';')
    try {
        & cmd.exe /c "`"$batPath`" $flags" 2>&1 | Out-Null
        $code = $LASTEXITCODE
    } finally {
        foreach ($v in $saved.Keys) { [Environment]::SetEnvironmentVariable($v, $saved[$v]) }
        foreach ($k in 1..6) { [Environment]::SetEnvironmentVariable("TEST_ANS_$k", $null) }
    }
    $logFile = Join-Path $profileDir 'Star_citizen_ES_update_log.txt'
    $stateFile = Join-Path $profileDir 'Star_citizen_ES_state.txt'
    [pscustomobject]@{
        Code  = $code
        Log   = $(if (Test-Path -LiteralPath $logFile) { [IO.File]::ReadAllText($logFile) } else { '' })
        State = $(if (Test-Path -LiteralPath $stateFile) { [IO.File]::ReadAllText($stateFile) } else { $null })
    }
}

function Get-Ini([string]$install, [string]$channel) {
    Join-Path $install "$channel\data\Localization\spanish_(spain)\global.ini"
}

# ------------------------------------------------------------------------------
Write-Host "== Sin red al iniciar sesion: reintenta y termina sin error"
$offline = $txt.Replace("ConnectAsync('api.github.com',443)", "ConnectAsync('127.0.0.1',9)").Replace('set "NET_MAX_TRIES=6"', 'set "NET_MAX_TRIES=3"').Replace('set "NET_RETRY_SECS=10"', 'set "NET_RETRY_SECS=1"')
$offlineCopy = Join-Path $t 'script-sin-red.bat'
[IO.File]::WriteAllText($offlineCopy, $offline, (New-Object Text.UTF8Encoding($false)))
$r = Invoke-Flow 'sin-red' '' @() @($emptyRoot) $offlineCopy
Assert ($r.Code -eq 0) 'termina con codigo 0 (se reintentara en el proximo inicio)'
Assert ($r.Log -match 'intento 1 de 3' -and $r.Log -match 'intento 2 de 3') 'reintenta con espera entre intentos'
Assert ($r.Log -match 'tras 3 intentos') 'tras agotar los intentos lo deja escrito en el log'
Assert ($r.Log -notmatch 'Buscando instalaciones') 'no sigue ejecutando sin red'

# ------------------------------------------------------------------------------
Write-Host "== Sin instalacion detectada: ejecucion silenciosa"
$r = Invoke-Flow 'silencioso' '' @() @($emptyRoot)
Assert ($r.Code -eq 1) 'termina con codigo 1'
Assert ($r.Log -match 'no se instala nada') 'lo deja escrito en el log'
Assert ($null -eq $r.State) 'no guarda estado'
Assert (-not (Test-Path 'C:\StarCitizen')) 'no crea C:\StarCitizen'

Write-Host "== Sin instalacion detectada: instalador con rutas manuales invalidas"
$r = Invoke-Flow 'manual-invalida' '/interactive' @("$t\no1", "$t\no2", "$t\no3") @($emptyRoot)
Assert ($r.Code -eq 1) 'tras 3 intentos termina con codigo 1'
Assert ($null -eq $r.State) 'no guarda estado'

# ------------------------------------------------------------------------------
Write-Host "== Varios canales: LIVE, HOTFIX, PTU y EPTU (se acepta PTU y se rechaza EPTU)"
$root = Join-Path $t 'disco-canales'
$inst = Join-Path $root 'Games\StarCitizen'
New-FakeInstall $inst @('LIVE', 'HOTFIX', 'PTU', 'EPTU')
$r = Invoke-Flow 'canales' '/interactive' @('S', 'N') @($root)
Assert ($r.Code -eq 0) 'termina bien'
Assert (Test-Path -LiteralPath (Get-Ini $inst 'LIVE')) 'instala en LIVE'
Assert (Test-Path -LiteralPath (Get-Ini $inst 'HOTFIX')) 'instala en HOTFIX sin preguntar'
Assert (Test-Path -LiteralPath (Get-Ini $inst 'PTU')) 'instala en PTU porque se confirmo'
Assert (-not (Test-Path -LiteralPath (Join-Path $inst 'EPTU\data'))) 'NO instala en EPTU porque se rechazo'
Assert (Test-Path -LiteralPath (Join-Path $inst 'LIVE\user.cfg')) 'copia tambien user.cfg'
$liveSize = ([IO.FileInfo](Get-Ini $inst 'LIVE')).Length
Assert (([IO.FileInfo](Get-Ini $inst 'HOTFIX')).Length -eq $liveSize) 'HOTFIX usa los textos de LIVE'
Assert (([IO.FileInfo](Get-Ini $inst 'PTU')).Length -ne $liveSize) 'PTU usa su propio global.ini'
Assert ($r.State -match 'PREVIEW_ON=PTU\r?\n') 'guarda la decision (PREVIEW_ON=PTU)'
Assert ($r.Log -match 'Canal EPTU: el usuario decidio no instalar') 'deja constancia del rechazo en el log'

Write-Host "== Varios canales: ejecucion silenciosa posterior (reparacion y decisiones guardadas)"
[IO.File]::Delete((Get-Ini $inst 'HOTFIX'))
$r = Invoke-Flow 'canales' '' @() @($root)      # mismo nombre = mismo perfil: reutiliza el estado guardado
$code = $r.Code
$log2 = $r.Log
Assert ($code -eq 0) 'termina bien'
Assert (Test-Path -LiteralPath (Get-Ini $inst 'HOTFIX')) 'repone el global.ini borrado de HOTFIX'
Assert ($log2 -match 'Canal EPTU detectado pero sin confirmar') 'no instala EPTU sin confirmacion'
Assert (-not (Test-Path -LiteralPath (Join-Path $inst 'EPTU\data'))) 'EPTU sigue sin traduccion'

# ------------------------------------------------------------------------------
Write-Host "== Solo LIVE: no se crea una carpeta PTU ni EPTU, ruta manual con comillas y \LIVE"
$inst2 = Join-Path $t 'Mis Juegos\StarCitizen'
New-FakeInstall $inst2 @('LIVE')
$r = Invoke-Flow 'solo-live' '/interactive' @("`"$inst2\LIVE`"") @($emptyRoot)
Assert ($r.Code -eq 0) 'termina bien'
Assert (Test-Path -LiteralPath (Get-Ini $inst2 'LIVE')) 'instala en LIVE'
Assert (-not (Test-Path -LiteralPath (Join-Path $inst2 'PTU'))) 'no crea carpeta PTU (antes se copiaba todo el ZIP)'
Assert ($r.State -match [regex]::Escape("INSTALL_PATH=$inst2") + '\r?\n') 'guarda la ruta sin el sufijo \LIVE ni comillas'

Finish-Tests
