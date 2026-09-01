# Start MCP PostgreSQL server for opencode.
# Reads DATABASE_URL directly from .env in repo root.
# No process-level env var (setx) required.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"

if (-not (Test-Path $envFile)) {
    Write-Error "File .env not found. Copy .env.example to .env and set DATABASE_URL."
    exit 1
}

$line = Get-Content $envFile | Where-Object { $_ -match "^\s*DATABASE_URL=" } | Select-Object -First 1
if (-not $line) {
    Write-Error "DATABASE_URL is not set in .env."
    exit 1
}

$url = ($line -split "=", 2)[1].Trim()

& npx -y "@modelcontextprotocol/server-postgres" $url
exit $LASTEXITCODE