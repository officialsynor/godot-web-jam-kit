<#
.SYNOPSIS
    One command to go from source to a playable web build.

.DESCRIPTION
    import -> error check -> export -> serve.

    Run this at the 13:00 hard gate and again before the 17:30 deadline, so
    nobody is typing paths from memory while the clock is running.

.PARAMETER NoServe
    Build only. Use this for the final ship build.

.PARAMETER Port
    Port for the local test server. Defaults to 8080.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -NoServe
#>
param(
    [switch]$NoServe,
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# --- edit these two if you move things ---
$Godot = "D:\Hack club\Godot_v4.7.2-stable_win64_console.exe"
$ProjectPath = $PSScriptRoot
# -----------------------------------------

$WebDir = Join-Path $ProjectPath "build\web"
$Index  = Join-Path $WebDir "index.html"

if (-not (Test-Path -LiteralPath $Godot)) {
    throw "Godot not found at '$Godot'. Fix the `$Godot path at the top of this script."
}

# [1/4] -------------------------------------------------------------
# Global class names (class_name Player, etc.) are only registered during an
# import pass. Skip this and every reference to a class added since the last
# run fails with "Could not find type ... in the current scope".
Write-Host "[1/4] Importing..." -ForegroundColor Cyan
& $Godot --headless --path $ProjectPath --import
if ($LASTEXITCODE -ne 0) { throw "Import failed (exit $LASTEXITCODE)." }

# [2/4] -------------------------------------------------------------
# Export does NOT fail on a broken script - it happily ships a build with the
# broken script inside. So actually run the game and read the output.
Write-Host "[2/4] Checking for script errors..." -ForegroundColor Cyan
$check = (& $Godot --headless --path $ProjectPath --quit-after 60 2>&1 | Out-String)
$bad = $check -split "`r?`n" | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Failed to load script" }
if ($bad) {
    Write-Host "Script errors found - fixing these first, not exporting:" -ForegroundColor Red
    $bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Build aborted: the game does not load cleanly."
}
Write-Host "      clean." -ForegroundColor Green

# [3/4] -------------------------------------------------------------
Write-Host "[3/4] Exporting web build..." -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()
& $Godot --headless --path $ProjectPath --export-release "Web" $Index
$sw.Stop()
if ($LASTEXITCODE -ne 0) { throw "Export failed (exit $LASTEXITCODE)." }

# IMPORTANT: this project folder is named "GAME]", and ']' is a PowerShell
# wildcard character. Plain Test-Path/Get-Item report a file as MISSING when it
# exists. Every path check in this script must use -LiteralPath.
$wasm = Join-Path $WebDir "index.wasm"
if (-not (Test-Path -LiteralPath $Index)) { throw "Export reported success but $Index never appeared." }
if (-not (Test-Path -LiteralPath $wasm))  { throw "Export reported success but $wasm never appeared." }

$sw.Stop()
$wasmSize = (Get-Item -LiteralPath $wasm).Length / 1MB
Write-Host ("      exported in {0:N1}s. index.wasm is {1:N1} MB." -f `
    $sw.Elapsed.TotalSeconds, $wasmSize) -ForegroundColor Green

if ($NoServe) {
    Write-Host "`nDone. Ship it:" -ForegroundColor Green
    Write-Host "  & `"D:\Hack club\tools\butler\windows-amd64\butler.exe`" push `"$WebDir`" `"YOURUSER/YOURGAME:web`""
    exit 0
}

# [4/4] -------------------------------------------------------------
Write-Host "[4/4] Serving http://127.0.0.1:$Port/index.html   (Ctrl+C to stop)" -ForegroundColor Cyan
python (Join-Path $ProjectPath "tools\serve.py") $WebDir $Port
