# Prueba la logica del vigilante (puente/vigilante.py) con datos locales. Offline.
. "$PSScriptRoot\common.ps1"

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
Assert ($null -ne $py) 'hay Python disponible'
if (-not $py) { Finish-Tests }
$script = Join-Path $RepoRoot 'puente\vigilante.py'
$t = New-TestDir 'vigilante'

function New-Bridge([string]$base, [string]$ss) {
    [ordered]@{ tag_name = 'bridge-4.10.2'; prerelease = $true; draft = $false; body = "BASE=$base`nSS=$ss" }
}
function New-Fixture([string]$thordName, [string]$thordTag, [string]$build, $bridge, $issues = @(), [string]$thordBody = '') {
    $rels = @(); if ($null -ne $bridge) { $rels = @($bridge) }
    $fx = [ordered]@{
        thord    = [ordered]@{ tag_name = $thordTag; name = $thordName; body = $thordBody }
        commits  = @([ordered]@{ commit = [ordered]@{ message = "Update for build $build" } })
        releases = $rels
        issues   = @($issues)
    }
    $f = Join-Path $t 'fx.json'
    [IO.File]::WriteAllText($f, (ConvertTo-Json $fx -Depth 8))
    $f
}
function Invoke-Vig($fx) { ((& $py.Source -I $script --fixture $fx) | Out-String).Trim() }
$b1 = 'sc-alpha-4.10.2_live_12881860'

Write-Host "== Vigilante"
Assert ((Invoke-Vig (New-Fixture 'LIVE 4.10.1' 'v.4.10.10.00' $b1 (New-Bridge 'v.4.10.10.00' $b1))) -eq 'Sin novedades.') 'puente al dia con StarStrings y con Thord -> sin avisos'
$o = Invoke-Vig (New-Fixture 'LIVE 4.10.1' 'v.4.10.10.00' 'sc-alpha-4.10.3_live_13000000' (New-Bridge 'v.4.10.10.00' $b1))
Assert ($o -match 'AVISO: Nuevo build de StarStrings sc-alpha-4.10.3_live_13000000') 'build nuevo de StarStrings -> avisa de regenerar el puente'
$o = Invoke-Vig (New-Fixture 'LIVE 4.10.1' 'v.4.10.10.00' $b1 $null)
Assert ($o -match 'AVISO: Nuevo build de StarStrings') 'sin puente y StarStrings por delante de Thord -> avisa'
$o = Invoke-Vig (New-Fixture 'LIVE 4.10.2' 'v.4.10.20.00' $b1 $null)
Assert ($o -eq 'Sin novedades.') 'Thord ya llega al build de StarStrings y no hay puente -> sin avisos'
$o = Invoke-Vig (New-Fixture 'LIVE 4.10.2' 'v.4.10.20.00' $b1 (New-Bridge 'v.4.10.10.00' $b1))
Assert ($o -match 'AVISO: Thord publico v\.4\.10\.20\.00: revisar y archivar el puente bridge-4\.10\.2') 'Thord publico algo posterior a la BASE -> avisa de revisar'
Assert ($o -notmatch 'Nuevo build') 'y no pide regenerar el puente'
$iss = @([ordered]@{ title = 'Thord publico v.4.10.20.00: revisar y archivar el puente bridge-4.10.2' })
$o = Invoke-Vig (New-Fixture 'LIVE 4.10.2' 'v.4.10.20.00' $b1 (New-Bridge 'v.4.10.10.00' $b1) $iss)
Assert ($o -match '\(ya existe\)' -and $o -notmatch 'AVISO') 'no duplica un issue que ya existe'
$o = Invoke-Vig (New-Fixture '' 'v.4.10.10.00' 'sc-alpha-4.10.3_live_13000000' $null @() 'Actualizado al parche LIVE 4.10.3')
Assert ($o -eq 'Sin novedades.') 'la version de Thord tambien se lee de la descripcion cuando la release no tiene nombre'

Finish-Tests
