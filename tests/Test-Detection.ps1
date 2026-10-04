# Tests de la deteccion de instalaciones de Star Citizen (offline, sin tocar el sistema real).
. "$PSScriptRoot\common.ps1"

$t = New-TestDir 'detect'
$noLog = Join-Path $t 'appdata-vacio'
New-Item -ItemType Directory $noLog | Out-Null

Write-Host "== Rutas conocidas"
$d1 = Join-Path $t 'disco1'
New-FakeInstall "$d1\Program Files\Roberts Space Industries\StarCitizen" @('LIVE')
New-FakeInstall "$d1\Games\StarCitizen" @('PTU')                     # solo PTU: tambien es una instalacion valida
New-TestFile "$d1\StarCitizen\LIVE\restos.txt"                         # carpeta suelta sin Data.p4k: no es una instalacion
$found = @(Invoke-Detection @($d1) $noLog)
Assert ($found.Count -eq 2) "detecta 2 instalaciones (encontradas: $($found.Count))"
Assert ($found -contains "$d1\Program Files\Roberts Space Industries\StarCitizen") 'detecta Program Files\Roberts Space Industries'
Assert ($found -contains "$d1\Games\StarCitizen") 'acepta una instalacion con solo PTU'
Assert (-not ($found -contains "$d1\StarCitizen")) 'ignora StarCitizen\LIVE sin Data.p4k ni StarCitizen.exe'

Write-Host "== Escaneo de discos (biblioteca personalizada)"
$d2 = Join-Path $t 'disco2'
New-FakeInstall "$d2\Mis Cosas\Juegos\StarCitizen" @('LIVE', 'HOTFIX')
$found = @(Invoke-Detection @($d2) $noLog)
Assert ($found.Count -eq 1 -and $found[0] -eq "$d2\Mis Cosas\Juegos\StarCitizen") 'encuentra una ruta personalizada por escaneo'

Write-Host "== Escaneo: limite de profundidad y carpetas excluidas"
$d3 = Join-Path $t 'disco3'
New-FakeInstall "$d3\a\b\c\d\StarCitizen" @('LIVE')                    # demasiado profundo
New-FakeInstall "$d3\AppData\Juegos\StarCitizen" @('LIVE')            # carpeta excluida
$found = @(Invoke-Detection @($d3) $noLog)
Assert ($found.Count -eq 0) 'no baja mas de 4 niveles ni entra en AppData'

Write-Host "== Log del RSI Launcher"
$d4 = Join-Path $t 'disco4'
$custom = "$d4\En Un Sitio\Raro\StarCitizen"
New-Item -ItemType Directory "$custom\LIVE" -Force | Out-Null         # sin Data.p4k: solo lo sabe el launcher
$appdata = Join-Path $t 'appdata'
$logDir = Join-Path $appdata 'rsilauncher\logs'
New-Item -ItemType Directory $logDir -Force | Out-Null
$escaped = ($custom -replace '\\', '\\')
[IO.File]::WriteAllText("$logDir\log.log", '{ "t":"2026-10-01", "[main][info] ": "[Launcher::launch] Launching Star Citizen LIVE from (' + $escaped + '\\LIVE)"  },' + "`r`n")
New-FakeInstall "$d4\Games\StarCitizen" @('LIVE')
$found = @(Invoke-Detection @($d4) $appdata)
Assert ($found.Count -eq 2) "detecta la del log y la conocida (encontradas: $($found.Count))"
Assert ($found[0] -eq $custom) 'la ruta del log del launcher va primero (JSON con barras dobles)'

Write-Host "== Sin instalaciones"
$d5 = Join-Path $t 'disco5'
New-Item -ItemType Directory "$d5\Carpeta" -Force | Out-Null
$found = @(Invoke-Detection @($d5) $noLog)
Assert ($found.Count -eq 0) 'no devuelve nada si no hay juego'

Finish-Tests
