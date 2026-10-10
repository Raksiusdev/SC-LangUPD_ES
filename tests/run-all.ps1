# Ejecuta todos los tests. Uso: powershell -File tests\run-all.ps1 [-SinRed]
#   -SinRed  omite los tests de flujos completos (necesitan internet para descargar la traduccion)
param([switch]$SinRed)

$tests = @('Test-Detection.ps1', 'Test-SelfUpdateIntegrity.ps1', 'Test-Log.ps1', 'Test-Bridge.ps1')
if (-not $SinRed) { $tests += 'Test-Flows.ps1' }

$failed = @()
foreach ($t in $tests) {
    Write-Host "`n################ $t ################"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $t)
    if ($LASTEXITCODE -ne 0) { $failed += $t }
}

if ($failed.Count -gt 0) {
    Write-Host "`nTests con fallos: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nTodos los tests correctos"
