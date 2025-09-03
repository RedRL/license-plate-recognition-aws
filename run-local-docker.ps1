param(
    [switch]$Rebuild,
    [switch]$Logs
)

$ErrorActionPreference = 'Stop'

Write-Host "==> Checking Docker..." -ForegroundColor Cyan
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not on PATH. Install Docker Desktop and try again."; exit 1
}

Write-Host "==> Ensuring backend folders exist..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "backend\uploads" | Out-Null
New-Item -ItemType Directory -Force -Path "backend\logs" | Out-Null

if ($Rebuild) {
    Write-Host "==> Rebuilding images..." -ForegroundColor Cyan
    docker compose build --no-cache
} else {
    Write-Host "==> Building images..." -ForegroundColor Cyan
    docker compose build
}

Write-Host "==> Starting containers (backend and frontend)..." -ForegroundColor Cyan
docker compose up -d

if ($Logs) {
    Write-Host "==> Tailing container logs (press Ctrl+C to stop)..." -ForegroundColor Yellow
    docker compose logs -f --tail=200
}

Write-Host "==> Containers status:" -ForegroundColor Cyan
docker compose ps

Write-Host "==> Open URLs:" -ForegroundColor Cyan
Write-Host "   Backend:  http://localhost:5000" -ForegroundColor Green
Write-Host "   Frontend: http://localhost:4200" -ForegroundColor Green 