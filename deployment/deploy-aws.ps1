# PowerShell wrapper for AWS deployment script
# Automatically finds and launches Git Bash to run deploy-aws.sh

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   License Plate Recognition - AWS Deployment (Windows)        " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Find Git Bash
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\bin\bash.exe"
)

$gitBash = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $gitBash = $path
        break
    }
}

if (-not $gitBash) {
    Write-Host "Git Bash not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Git for Windows from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Found Git Bash: $gitBash" -ForegroundColor Green
Write-Host ""

# Convert Windows path to Git Bash format
$scriptPath = $PSScriptRoot.Replace('\', '/').Replace('C:', '/c')
$scriptFile = "$scriptPath/deploy-aws.sh"

Write-Host "Starting deployment..." -ForegroundColor Yellow
Write-Host ""

# Run the bash script (note: we're already in deployment folder)
& $gitBash -c "cd '$scriptPath' && chmod +x deploy-aws.sh && ./deploy-aws.sh"

$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Deployment failed with exit code: $exitCode" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

exit $exitCode
