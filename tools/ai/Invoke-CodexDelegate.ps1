[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PromptFile,

    [switch]$ReadOnly,

    [switch]$WithUnrealMcp,

    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$CodexCommand = Get-Command codex -ErrorAction Stop

$LoginStatus = & $CodexCommand.Source login status 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Codex CLI non autenticata. Eseguire 'codex login' con il proprio account ChatGPT prima della delega. Dettaglio: $LoginStatus"
}

if ($CheckOnly) {
    Write-Output "Codex CLI pronta per le deleghe nel progetto: $ProjectRoot"
    exit 0
}

$ResolvedPrompt = (Resolve-Path -LiteralPath $PromptFile).Path
if (-not $ResolvedPrompt.StartsWith($ProjectRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Il prompt deve trovarsi nel repository: $ProjectRoot"
}

$PromptExtension = [System.IO.Path]::GetExtension($ResolvedPrompt)
if ($PromptExtension -notin @('.md', '.txt')) {
    throw 'Il prompt deve essere un file .md o .txt.'
}

$PromptText = Get-Content -LiteralPath $ResolvedPrompt -Raw
if ([string]::IsNullOrWhiteSpace($PromptText)) {
    throw 'Il prompt di delega e vuoto.'
}

$SandboxMode = if ($ReadOnly) { 'read-only' } else { 'workspace-write' }
$Arguments = @(
    'exec',
    '-',
    '--ephemeral',
    '--sandbox', $SandboxMode,
    '-C', $ProjectRoot
)

if (-not $WithUnrealMcp) {
    $Arguments += @('-c', 'mcp_servers.unreal-mcp.enabled=false')
}

$PromptText | & $CodexCommand.Source @Arguments
exit $LASTEXITCODE
