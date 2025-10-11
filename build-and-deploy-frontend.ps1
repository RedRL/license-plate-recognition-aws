# Build frontend locally and deploy to AWS EC2
# This avoids out-of-memory issues on t3.micro instances

$ErrorActionPreference = "Stop"

$EC2_IP = "3.66.164.127"
$KEY = "lpr-keypair.pem"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build & Deploy Frontend to AWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if key exists
if (-not (Test-Path $KEY)) {
    Write-Host "[ERROR] Key file not found: $KEY" -ForegroundColor Red
    Write-Host "Please make sure you're in the project directory and the key file exists." -ForegroundColor Red
    exit 1
}

# Step 1: Build frontend locally
Write-Host "[1/4] Building Angular frontend locally..." -ForegroundColor Green
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

Set-Location frontend

# Install dependencies if node_modules doesn't exist
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies first..." -ForegroundColor Yellow
    npm install
}

# Build production
npm run build -- --configuration production

if (-not (Test-Path "dist/new-front/browser")) {
    Write-Host "[ERROR] Frontend build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Frontend built successfully!" -ForegroundColor Green
Set-Location ..

# Step 2: Create tarball
Write-Host ""
Write-Host "[2/4] Creating deployment package..." -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tarFile = "frontend-dist-$timestamp.tar.gz"

# Use tar (available in Windows 10+)
tar -czf $tarFile -C frontend/dist/new-front browser

Write-Host "[SUCCESS] Package created: $tarFile" -ForegroundColor Green

# Step 3: Upload to EC2
Write-Host ""
Write-Host "[3/4] Uploading to EC2..." -ForegroundColor Green

scp -o StrictHostKeyChecking=no -i $KEY $tarFile "ubuntu@${EC2_IP}:/tmp/"

Write-Host "[SUCCESS] Uploaded to EC2!" -ForegroundColor Green

# Step 4: Deploy on EC2
Write-Host ""
Write-Host "[4/4] Deploying on EC2..." -ForegroundColor Green

# Upload deploy script
scp -o StrictHostKeyChecking=no -i $KEY deployment/deploy-frontend.sh "ubuntu@${EC2_IP}:/tmp/"

# Run it
ssh -o StrictHostKeyChecking=no -i $KEY "ubuntu@${EC2_IP}" "bash /tmp/deploy-frontend.sh $tarFile $EC2_IP"

# Cleanup local tarball
Remove-Item $tarFile

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your app is live at: http://$EC2_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Try uploading an image with a license plate!" -ForegroundColor Yellow
Write-Host ""

