# Comprueba que la subrutina :log del .bat escribe TODAS las lineas, incluidas las
# que acaban en un digito (con "echo ...2>> log" ese digito se leia como handle y
# la linea se perdia). Ejecuta la subrutina real extraida del .bat. Offline.
. "$PSScriptRoot\common.ps1"

$bat = [IO.File]::ReadAllText($MainBat, [Text.Encoding]::UTF8)
$m = [regex]::Match($bat, '(?ms)^:log\r?\n(.*?)^goto :eof')
Assert $m.Success 'el .bat contiene la subrutina :log'
if (-not $m.Success) { Finish-Tests }

$t = New-TestDir 'log'
$logFile = Join-Path $t 'log.txt'
$harness = Join-Path $t 'harness.bat'
$body = "@echo off`r`nset `"LOG_FILE=$logFile`"`r`n" +
    "call :log INFO `"Instalaciones encontradas: 2`"`r`n" +
    "call :log INFO `"SHA256 del ZIP: ABC123`"`r`n" +
    "call :log OK `"Version instalada: 1.2.3`"`r`n" +
    "call :log INFO `"sin digito final`"`r`n" +
    "exit /b 0`r`n:log`r`n" + $m.Groups[1].Value + "goto :eof`r`n"
[IO.File]::WriteAllText($harness, $body)

Write-Host "== Subrutina :log"
$console = & cmd /c "`"$harness`"" 2>&1 | Out-String
$lines = @(Get-Content $logFile)
Assert ($lines.Count -eq 4) 'las 4 lineas llegan al log'
Assert (($lines | Where-Object { $_ -match 'encontradas: 2$' }).Count -eq 1) 'linea acabada en 2 completa'
Assert (($lines | Where-Object { $_ -match 'ABC123$' }).Count -eq 1) 'linea acabada en digito (hash) completa'
Assert (($lines | Where-Object { $_ -match '1\.2\.3$' }).Count -eq 1) 'linea acabada en version completa'
Assert ($console.Trim() -eq '') 'no se filtra nada a la consola'

Finish-Tests
