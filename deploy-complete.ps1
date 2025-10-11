# Complete PowerShell Deployment Script
# Handles AWS CLI check, credentials, IAM user setup, and deployment

$ErrorActionPreference = "Stop"

# Find and run the bash script
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "License Plate Recognition - Complete Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Find-GitBash {
    $possiblePaths = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles(x86)\Git\bin\bash.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    $bashInPath = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($bashInPath) {
        $bashPath = $bashInPath.Source
        if ($bashPath -like "*Git*") {
            return $bashPath
        }
    }
    
    return $null
}

Write-Host "[INFO] Searching for Git Bash..." -ForegroundColor Green

$gitBashPath = Find-GitBash

if (-not $gitBashPath) {
    Write-Host "[ERROR] Git Bash not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Git for Windows from:" -ForegroundColor Yellow
    Write-Host "https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After installation, run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[INFO] Found Git Bash: $gitBashPath" -ForegroundColor Green
Write-Host "[INFO] Starting complete deployment setup..." -ForegroundColor Green
Write-Host ""

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run the complete bash script
& $gitBashPath -c "cd '$scriptDir' && bash deploy-complete.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Deployment failed or was cancelled." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[INFO] Deployment completed successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"


