param(
    # Layer name: ODS, DDS, DM. The .env variable DATABASE_URL_<LAYER> is used.
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("ODS", "DDS", "DM")]
    [string]$Layer
)

# Start MCP PostgreSQL server for opencode.
# Reads a DATABASE_URL_* directly from .env in repo root.
# No process-level env var (setx) required.
# Usage: mcp-postgres.ps1 ODS | DDS | DM
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"

if (-not (Test-Path $envFile)) {
    Write-Error "File .env not found. Copy .env.example to .env and set DATABASE_URL_*."
    exit 1
}

$varName = "DATABASE_URL_$Layer"

$line = Get-Content $envFile | Where-Object { $_ -match "^\s*$varName=" } | Select-Object -First 1
if (-not $line) {
    Write-Error "$varName is not set in .env."
    exit 1
}

$url = ($line -split "=", 2)[1].Trim()

& npx -y "@modelcontextprotocol/server-postgres" $url
exit $LASTEXITCODE