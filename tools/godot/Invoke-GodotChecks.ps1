<#
.SYNOPSIS
  Gate di qualita del progetto Godot: validazione statica, test automatici, smoke test headless.

.DESCRIPTION
  1. --check-only su ogni script .gd del progetto (esclusi gli addon di terze parti in
     godot/addons: usano il nome globale dei propri autoload, che in --check-only non esiste);
  2. tutte le suite in godot/tests a 60 fps fissi;
  3. avvio headless dal menu iniziale con `-- --autostart` (passa subito al livello)
     e verifica dei marker attesi.
  Con -Executable verifica invece una build esportata (stessi marker, senza 1-2).
  Exit code 0 solo se tutto passa.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
  powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1 -Executable LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe
#>
param(
    [string]$Executable = ""
)

$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$project = Join-Path $repo "godot"
$godot = (Get-Command godot_console -ErrorAction Stop).Source
$failures = 0

$expectedMarkers = @(
    "PROTOTYPE01_MENU_READY",
    "PROTOTYPE01_SMOKE_TEST_OK",
    "PROTOTYPE01_INPUT_READY",
    "PROTOTYPE01_EXPOSURE_READY",
    "PROTOTYPE01_ARENA_READY",
    "PROTOTYPE01_TERRAIN_GRID_READY",
    "PROTOTYPE01_CHARACTER_READY",
    "PROTOTYPE01_TERRAIN_MODE Dig",
    "PROTOTYPE01_CAMERA_READY",
    "PROTOTYPE01_COMPANION_READY",
    "PROTOTYPE01_RUN_START",
    "PROTOTYPE01_PATH_FIELD_READY"
)

# Righe di errore runtime di Godot che non fanno fallire il gate. Ogni voce e un
# errore noto e spiegato; aggiungerne una solo con il motivo accanto.
$allowedErrorPatterns = @(
    # P-09 (review 9 ottobre 2026): il renderer fittizio di --headless stampa
    # `ERROR: Parameter "material" is null` quando TerrainGrid libera la scena.
    # Non e un bug del progetto: con finestra reale non compare.
    'Parameter "material" is null'
)

# Righe `SCRIPT ERROR` o `ERROR:` nell'output, tolte quelle in allowlist (U-03).
function Get-RuntimeErrors([string]$text) {
    $lines = @($text -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|^ERROR:" })
    return @($lines | Where-Object {
        $line = $_
        -not ($allowedErrorPatterns | Where-Object { $line -match [regex]::Escape($_) })
    })
}

function Invoke-Captured([string]$file, [string[]]$arguments, [int]$timeoutSeconds = 300) {
    # Processo separato con timeout: un test che non chiama quit() non deve
    # bloccare il gate per sempre (successo davvero, vedi GODOT_WORKFLOW.md).
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    $quoted = $arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $process = Start-Process -FilePath $file -ArgumentList $quoted -NoNewWindow -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    # PowerShell 5.1: senza aprire subito l'handle, ExitCode resta vuoto dopo l'uscita.
    $null = $process.Handle
    $finished = $process.WaitForExit($timeoutSeconds * 1000)
    if (-not $finished) {
        # Il launcher godot_console avvia un processo figlio: chiudere l'albero intero.
        # Niente redirezione di stderr: con $ErrorActionPreference = "Stop" un
        # processo gia uscito farebbe abortire il gate invece di riportare TIMEOUT (U-15).
        try { & taskkill /F /T /PID $process.Id | Out-Null } catch { }
    }
    $text = ((Get-Content $outFile -Raw) + "`n" + (Get-Content $errFile -Raw))
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
    if (-not $finished) {
        return @{ Code = 124; Text = "TIMEOUT dopo $timeoutSeconds s`n$text" }
    }
    return @{ Code = $process.ExitCode; Text = $text }
}

function Test-Markers([string]$text) {
    $missing = @($expectedMarkers | Where-Object { -not $text.Contains($_) })
    $errors = Get-RuntimeErrors $text
    if ($missing.Count -gt 0) { Write-Host "  FAIL marker mancanti: $($missing -join ', ')" }
    if ($errors.Count -gt 0) { Write-Host "  FAIL errori runtime:`n$($errors -join "`n")" }
    return ($missing.Count -eq 0 -and $errors.Count -eq 0)
}

if ($Executable) {
    Write-Host "== smoke test build: $Executable"
    $run = Invoke-Captured (Resolve-Path $Executable) @("--headless", "--quit-after", "180", "--", "--autostart")
    if (Test-Markers $run.Text) { Write-Host "  ok   tutti i marker presenti" } else { $failures++ }
    if ($failures -eq 0) { Write-Host "GODOT_CHECKS PASS" } else { Write-Host "GODOT_CHECKS FAIL" }
    exit [int]($failures -gt 0)
}

Write-Host "== check-only"
Get-ChildItem -Path $project -Recurse -Filter *.gd | Where-Object { $_.FullName -notmatch "\\\.godot\\|\\addons\\" } | ForEach-Object {
    $resPath = "res://" + $_.FullName.Substring($project.Length + 1).Replace("\", "/")
    $result = Invoke-Captured $godot @("--headless", "--path", "$project", "--check-only", "--script", $resPath)
    if ($result.Code -ne 0) {
        $failures++
        Write-Host "  FAIL $resPath`n$($result.Text)"
    } else {
        Write-Host "  ok   $resPath"
    }
}

Write-Host "== test suites"
Get-ChildItem -Path (Join-Path $project "tests") -Filter *.gd | ForEach-Object {
    $resPath = "res://tests/" + $_.Name
    $result = Invoke-Captured $godot @("--headless", "--path", "$project", "--fixed-fps", "60", "--script", $resPath)
    $summary = ($result.Text -split "`n" | Where-Object { $_ -match "PROTOTYPE01_TESTS" }) -join ""
    # Una suite verde che scatena un errore runtime non asserito e comunque FAIL (U-03).
    $errors = Get-RuntimeErrors $result.Text
    if ($result.Code -ne 0 -or -not $summary.Contains("PASS") -or $errors.Count -gt 0) {
        $failures++
        Write-Host "  FAIL $resPath (exit $($result.Code), errori runtime $($errors.Count))"
        $result.Text -split "`n" | Where-Object { $_ -match "FAIL|TIMEOUT" } | ForEach-Object { Write-Host "       $_" }
        $errors | ForEach-Object { Write-Host "       $_" }
    } else {
        Write-Host "  ok   $resPath $summary"
    }
}

Write-Host "== smoke test headless"
$run = Invoke-Captured $godot @("--headless", "--path", "$project", "--quit-after", "180", "--", "--autostart")
if (Test-Markers $run.Text) { Write-Host "  ok   tutti i marker presenti" } else { $failures++ }

if ($failures -eq 0) { Write-Host "GODOT_CHECKS PASS" } else { Write-Host "GODOT_CHECKS FAIL ($failures)" }
exit [int]($failures -gt 0)
