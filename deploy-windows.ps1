# PowerShell Wrapper for AWS Deployment on Windows
# This script finds Git Bash and runs the interactive deployment

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "License Plate Recognition - AWS Deployment" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Function to find Git Bash
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
    
    # Try to find bash.exe in PATH (but exclude WSL)
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
Write-Host "[INFO] Starting interactive deployment..." -ForegroundColor Green
Write-Host ""

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptDir "deploy-interactive.sh"

# Convert Windows path to Git Bash format
# Example: C:\Users\Name\path -> /c/Users/Name/path
$drive = $scriptPath.Substring(0,1).ToLower()
$pathWithoutDrive = $scriptPath.Substring(2) -replace '\\', '/'
$unixPath = "/$drive$pathWithoutDrive"

Write-Host "[DEBUG] Script path: $scriptPath" -ForegroundColor Gray
Write-Host "[DEBUG] Unix path: $unixPath" -ForegroundColor Gray
Write-Host ""

# Run the interactive script
& $gitBashPath -c "cd '$scriptDir' && bash deploy-interactive.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Deployment failed or was cancelled." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[INFO] Deployment completed successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"

