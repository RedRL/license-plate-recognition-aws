# Update frontend on AWS after making changes
# This is faster than full redeployment

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Update Frontend on AWS                                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Get EC2 IP from credentials file
$credFile = "../aws-credentials.txt"
if (-not (Test-Path $credFile)) {
    Write-Host "✗ aws-credentials.txt not found. Run deployment\deploy-aws.ps1 first!" -ForegroundColor Red
    exit 1
}

$EC2_IP = (Get-Content $credFile | Select-String "EC2 Instance:" | ForEach-Object { $_.ToString().Split(":")[1].Trim() })
$KEY = "../lpr-keypair.pem"

if (-not (Test-Path $KEY)) {
    Write-Host "✗ Key file not found: $KEY" -ForegroundColor Red
    exit 1
}

Write-Host "[1/4] Building frontend locally..." -ForegroundColor Green
Set-Location ../frontend
npm run build -- --configuration production
Set-Location ../deployment

Write-Host "`n[2/4] Creating deployment package..." -ForegroundColor Green
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tarFile = "frontend-dist-$timestamp.tar.gz"
tar -czf $tarFile -C ../frontend/dist/new-front browser

Write-Host "`n[3/4] Uploading to EC2..." -ForegroundColor Green
scp -o StrictHostKeyChecking=no -i $KEY $tarFile "ubuntu@${EC2_IP}:/tmp/"

Write-Host "`n[4/4] Deploying on EC2..." -ForegroundColor Green
ssh -o StrictHostKeyChecking=no -i $KEY "ubuntu@${EC2_IP}" @"
    sudo rm -rf /opt/lpr-app/frontend/dist
    sudo mkdir -p /opt/lpr-app/frontend/dist/new-front
    cd /opt/lpr-app/frontend/dist/new-front
    sudo tar -xzf /tmp/$tarFile
    sudo chown -R ubuntu:ubuntu /opt/lpr-app/frontend/dist
    sudo systemctl reload nginx
    echo '✓ Frontend updated successfully!'
"@

Remove-Item $tarFile

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Frontend Updated Successfully!                               ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "Visit: http://$EC2_IP`n" -ForegroundColor Cyan


