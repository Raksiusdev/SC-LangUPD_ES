# Utilidades compartidas por los tests. Se cargan con: . "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
$script:Fails = 0

$RepoRoot = Split-Path -Parent $PSScriptRoot
$MainBat = Join-Path $RepoRoot 'UpdateStarCitizenES.bat'

function Assert($cond, $msg) {
    if ($cond) {
        Write-Host "  PASS  $msg"
    } else {
        Write-Host "  FAIL  $msg" -ForegroundColor Red
        $script:Fails++
    }
}

function Finish-Tests {
    if ($script:Fails -gt 0) {
        Write-Host "`n$($script:Fails) comprobacion(es) fallida(s)" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nTodo correcto"
    exit 0
}

function New-TestDir($name) {
    $d = Join-Path ([IO.Path]::GetTempPath()) ("sc-tests-$name-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory $d | Out-Null
    $d
}

function New-TestFile($path, $content = '') {
    New-Item -ItemType Directory (Split-Path $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, $content)
}

# Simula una instalacion: crea <root>\<canal>\Data.p4k para cada canal indicado
function New-FakeInstall($installDir, [string[]]$channels) {
    foreach ($c in $channels) { New-TestFile (Join-Path $installDir "$c\Data.p4k") }
}

# Ejecuta SOLO el bloque de deteccion PowerShell del .bat (igual que hace el script
# real) contra raices de prueba, y devuelve las rutas detectadas en orden.
function Invoke-Detection([string[]]$roots, [string]$appdata) {
    $oldRoots = $env:SC_TEST_ROOTS
    $oldAppData = $env:APPDATA
    $env:SC_TEST_ROOTS = ($roots -join ';')
    $env:APPDATA = $appdata
    try {
        $cmd = "`$s=[IO.File]::ReadAllText('$MainBat',[Text.Encoding]::UTF8); `$i=`$s.IndexOf('#PS_'+'BEGIN'); & ([scriptblock]::Create(`$s.Substring(`$i)))"
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
        @($out | Where-Object { $_ -match '^OK\|' } | ForEach-Object { $_.Substring(3) })
    } finally {
        $env:SC_TEST_ROOTS = $oldRoots
        $env:APPDATA = $oldAppData
    }
}
