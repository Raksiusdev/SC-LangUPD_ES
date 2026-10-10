# Prueba la seleccion de la traduccion puente ejecutando el bloque PowerShell REAL del
# .bat (entre #PS_BRIDGE y #PS_BEGIN) contra un JSON local de releases. Offline.
. "$PSScriptRoot\common.ps1"

$bat = [IO.File]::ReadAllText($MainBat, [Text.Encoding]::UTF8)
$i = $bat.IndexOf('#PS_' + 'BRIDGE'); $j = $bat.IndexOf('#PS_' + 'BEGIN')
Assert ($i -ge 0 -and $j -gt $i) 'el .bat contiene el bloque del puente antes del de deteccion'
if (-not ($i -ge 0 -and $j -gt $i)) { Finish-Tests }
$t = New-TestDir 'bridge'
$blockFile = Join-Path $t 'bridge.ps1'
[IO.File]::WriteAllText($blockFile, $bat.Substring($i, $j - $i))

function New-Rel($tag, $body, [bool]$pre = $true, [bool]$draft = $false, [string]$digest = $null, [string]$asset = 'Star_citizen_ES.zip') {
    $a = [ordered]@{ name = $asset; browser_download_url = "https://example.test/$tag/$asset" }
    if ($digest) { $a.digest = $digest }
    [ordered]@{ tag_name = $tag; prerelease = $pre; draft = $draft; body = $body; assets = @($a) }
}
function Invoke-Bridge($rels, [string]$thordTag) {
    $json = Join-Path $t 'rels.json'
    [IO.File]::WriteAllText($json, (ConvertTo-Json @($rels) -Depth 6))
    $old = @($env:SC_BRIDGE_JSON, $env:SC_THORD_TAG)
    $env:SC_BRIDGE_JSON = $json; $env:SC_THORD_TAG = $thordTag
    try { (& powershell -NoProfile -ExecutionPolicy Bypass -File $blockFile | Out-String).Trim() }
    finally { $env:SC_BRIDGE_JSON = $old[0]; $env:SC_THORD_TAG = $old[1] }
}
$sha = 'a' * 64

Write-Host "== Seleccion de la traduccion puente"
$ok = New-Rel 'bridge-4.10.2' "Puente 4.10.2`r`nBASE=v.4.10.10.00`r`n" $true $false "sha256:$sha"
Assert ((Invoke-Bridge @($ok) '4.10.10.00') -eq "bridge-4.10.2|https://example.test/bridge-4.10.2/Star_citizen_ES.zip|$sha") 'BASE coincide con la ultima release de Thord -> se usa el puente (con su SHA256)'
Assert ((Invoke-Bridge @($ok) '4.10.11.00') -eq '') 'Thord ya publico otra release -> el puente deja de aplicarse'
Assert ((Invoke-Bridge @((New-Rel 'bridge-4.10.2' 'BASE=4.10.10.00' $true $false)) '4.10.10.00') -eq 'bridge-4.10.2|https://example.test/bridge-4.10.2/Star_citizen_ES.zip|') 'BASE sin prefijo v. y sin digest -> se usa, sin hash'
Assert ((Invoke-Bridge @((New-Rel 'bridge-4.10.2' 'BASE=v.4.10.10.00' $false)) '4.10.10.00') -eq '') 'una release normal (no pre-release) no cuenta como puente'
Assert ((Invoke-Bridge @((New-Rel 'bridge-4.10.2' 'BASE=v.4.10.10.00' $true $true)) '4.10.10.00') -eq '') 'un borrador no cuenta'
Assert ((Invoke-Bridge @((New-Rel 'otra-4.10.2' 'BASE=v.4.10.10.00')) '4.10.10.00') -eq '') 'una pre-release que no empieza por bridge- no cuenta'
Assert ((Invoke-Bridge @((New-Rel 'bridge-4.10.2' 'sin base')) '4.10.10.00') -eq '') 'sin linea BASE no se usa'
Assert ((Invoke-Bridge @((New-Rel 'bridge-4.10.2' 'BASE=v.4.10.10.00' $true $false $null 'otro.zip')) '4.10.10.00') -eq '') 'sin el asset Star_citizen_ES.zip no se usa'
$old = New-Rel 'bridge-4.10.1' 'BASE=v.4.09.00.03'
Assert ((Invoke-Bridge @($old, $ok) '4.10.10.00') -like 'bridge-4.10.2|*') 'entre varios puentes elige el que corresponde a la base actual'

Finish-Tests
