# ============================================================================
# owlnighter - bootstrap wrapper (Windows / PowerShell)
#
# Handles the "nothing installed" case: makes sure Node >= 20 and pnpm exist
# (installing Node LTS via winget if it's missing), enables pnpm through
# corepack, then hands off to scripts/setup.mjs which does the real work.
#
# It deliberately does NOT auto-install the heavy tools (Docker Desktop,
# Flutter/Android SDK) - those installs are fragile to script. setup.mjs detects
# them and prints the official installer links instead.
#
# Usage (from the repo root):
#   ./scripts/setup.ps1
#   ./scripts/setup.ps1 --non-interactive
# If PowerShell blocks the script, run once:
#   powershell -ExecutionPolicy Bypass -File scripts/setup.ps1
# Safe to re-run.
# ============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host $msg -ForegroundColor Red }

function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Get-NodeMajor {
  try {
    $v = (& node -v) 2>$null
    if ($v -match '^v(\d+)') { return [int]$Matches[1] }
  } catch {}
  return 0
}

# --- 1. Node -----------------------------------------------------------------
if (-not (Have node) -or (Get-NodeMajor) -lt 20) {
  Write-Info "Node >= 20 not found - attempting to install via winget..."
  if (Have winget) {
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    Write-Warn "Node installed. If 'node' isn't recognized below, open a NEW terminal and re-run this script (PATH refresh)."
    # Best-effort PATH refresh for the current session.
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
  } else {
    Write-Err "winget not available. Install Node >= 20 LTS from https://nodejs.org/en/download and re-run."
    exit 1
  }
}

if (-not (Have node)) {
  Write-Err "Node still not on PATH. Open a new terminal and re-run this script."
  exit 1
}
Write-Info "Using Node $(& node -v)"

# --- 2. pnpm via corepack ----------------------------------------------------
if (-not (Have pnpm)) {
  if (Have corepack) {
    Write-Info "Enabling pnpm via corepack..."
    try { corepack enable } catch { Write-Warn "corepack enable failed; setup.mjs will retry." }
  } else {
    Write-Warn "corepack not found; setup.mjs will fall back to detecting pnpm."
  }
}

# --- 3. Hand off to the orchestrator -----------------------------------------
Write-Info "Launching setup..."
Set-Location $RepoRoot
& node scripts/setup.mjs @args
exit $LASTEXITCODE
