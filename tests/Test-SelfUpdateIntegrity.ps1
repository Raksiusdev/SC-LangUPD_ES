# Prueba la verificacion SHA256 de la autoactualizacion ejecutando el comando REAL
# del .bat contra un SHA256SUMS.txt local (file://). Offline.
. "$PSScriptRoot\common.ps1"

$bat = [IO.File]::ReadAllText($MainBat, [Text.Encoding]::UTF8)
$line = ($bat -split "`r?`n") | Where-Object { $_ -match "DownloadString\('%SELF_URL_SUMS%'\)" } | Select-Object -First 1
Assert ($null -ne $line) 'el .bat contiene el comando de verificacion SHA256SUMS'
if ($null -eq $line) { Finish-Tests }

$null = $line -match '-Command "(.*)" >nul 2>&1\s*$'
$template = $Matches[1]

$t = New-TestDir 'integrity'
$selfTemp = Join-Path $t 'descarga'
New-Item -ItemType Directory $selfTemp | Out-Null
[IO.File]::WriteAllText("$selfTemp\UpdateStarCitizenES.bat", "@echo off`r`necho hola`r`n")
[IO.File]::WriteAllText("$selfTemp\SC_Lang_updater.vbs", "Set x = Nothing`r`n")
$hBat = (Get-FileHash "$selfTemp\UpdateStarCitizenES.bat" -Algorithm SHA256).Hash.ToLower()
$hVbs = (Get-FileHash "$selfTemp\SC_Lang_updater.vbs" -Algorithm SHA256).Hash.ToLower()
$zeros = '0' * 64

function Invoke-Verify([string]$sumsContent) {
    $sums = Join-Path $t 'SHA256SUMS.txt'
    if ($null -ne $sumsContent) { [IO.File]::WriteAllText($sums, $sumsContent) }
    $uri = ([Uri]$sums).AbsoluteUri
    $code = $template.Replace('%SELF_URL_SUMS%', $uri).Replace('%SELF_TEMP%', $selfTemp)
    $script = Join-Path $t 'verify.ps1'
    [IO.File]::WriteAllText($script, $code)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script | Out-Null
    $LASTEXITCODE
}

Write-Host "== Verificacion SHA256 de la autoactualizacion"
$ok = "$hBat  UpdateStarCitizenES.bat`n$hVbs  SC_Lang_updater.vbs`n"
Assert ((Invoke-Verify $ok) -eq 0) 'hashes correctos -> codigo 0 (se aplica)'
Assert ((Invoke-Verify "$($hBat.ToUpper())  UpdateStarCitizenES.bat`n$($hVbs.ToUpper())  SC_Lang_updater.vbs`n") -eq 0) 'los hashes en mayusculas tambien valen'
Assert ((Invoke-Verify "$hBat *UpdateStarCitizenES.bat`n$hVbs *SC_Lang_updater.vbs`n") -eq 0) 'formato binario de sha256sum (asterisco) -> codigo 0'
Assert ((Invoke-Verify "$zeros  UpdateStarCitizenES.bat`n$hVbs  SC_Lang_updater.vbs`n") -eq 2) 'hash del .bat que no coincide -> codigo 2 (se descarta)'
Assert ((Invoke-Verify "$hBat  UpdateStarCitizenES.bat`n$zeros  SC_Lang_updater.vbs`n") -eq 2) 'hash del .vbs que no coincide -> codigo 2 (se descarta)'
Assert ((Invoke-Verify "$hBat  UpdateStarCitizenES.bat`n") -eq 3) 'falta una entrada en el archivo -> codigo 3 (no verificable)'
[IO.File]::Delete((Join-Path $t 'SHA256SUMS.txt'))
Assert ((Invoke-Verify $null) -eq 3) 'la release no publica SHA256SUMS.txt -> codigo 3 (no verificable)'

Finish-Tests
