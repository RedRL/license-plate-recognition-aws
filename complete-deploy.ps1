# PowerShell script to complete the AWS deployment
# Run this after CloudFormation succeeds

$ErrorActionPreference = "Continue"

$EC2_IP = "3.66.164.127"
$KEY_PATH = "lpr-keypair.pem"
$REGION = "eu-central-1"

Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "Completing AWS Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get DB endpoint and S3 bucket
Write-Host "[INFO] Getting AWS resources..." -ForegroundColor Green

$DB_ENDPOINT = aws cloudformation describe-stacks `
    --stack-name LicensePlateStack `
    --region $REGION `
    --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" `
    --output text

$S3_BUCKET = aws cloudformation describe-stacks `
    --stack-name LicensePlateStack `
    --region $REGION `
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" `
    --output text

$DB_PASSWORD = aws cloudformation describe-stacks `
    --stack-name LicensePlateStack `
    --region $REGION `
    --query "Stacks[0].Parameters[?ParameterKey=='DBPassword'].ParameterValue" `
    --output text

Write-Host "[INFO] DB Endpoint: $DB_ENDPOINT" -ForegroundColor Green
Write-Host "[INFO] S3 Bucket: $S3_BUCKET" -ForegroundColor Green
Write-Host ""

# Create package
Write-Host "[INFO] Creating code package..." -ForegroundColor Green
$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

Copy-Item -Recurse backend $tempDir/
Copy-Item -Recurse frontend $tempDir/
New-Item -ItemType Directory -Path "$tempDir/deployment" -Force | Out-Null
Copy-Item deployment/*.sh $tempDir/deployment/ -ErrorAction SilentlyContinue
Copy-Item deployment/*.sql $tempDir/deployment/ -ErrorAction SilentlyContinue

# Use tar if available, otherwise use 7zip or skip
Push-Location $tempDir
if (Get-Command tar -ErrorAction SilentlyContinue) {
    tar -czf lpr-app.tar.gz backend frontend deployment
} else {
    Write-Host "[WARN] tar not found, uploading folders directly..." -ForegroundColor Yellow
}
Pop-Location

# Upload to EC2
Write-Host "[INFO] Uploading to EC2..." -ForegroundColor Green
if (Test-Path "$tempDir/lpr-app.tar.gz") {
    scp -o StrictHostKeyChecking=no -i $KEY_PATH "$tempDir/lpr-app.tar.gz" "ubuntu@${EC2_IP}:/tmp/"
} else {
    scp -o StrictHostKeyChecking=no -i $KEY_PATH -r "$tempDir/*" "ubuntu@${EC2_IP}:/tmp/lpr-upload/"
}

Write-Host "[INFO] Installing application on EC2..." -ForegroundColor Green
Write-Host "[INFO] This will take 15-20 minutes (installing OpenALPR, building frontend)..." -ForegroundColor Yellow
Write-Host ""

# Run installation on EC2
$sshCommand = @"
# Extract code
if [ -f /tmp/lpr-app.tar.gz ]; then
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
fi

# Create environment file
cat > /opt/lpr-app/.env << 'EOF'
AWS_REGION=$REGION
S3_BUCKET=$S3_BUCKET
DB_HOST=$DB_ENDPOINT
DB_PORT=3306
DB_NAME=license_plates_db
DB_USER=admin
DB_PASSWORD=$DB_PASSWORD
LOCAL_MODE=false
ALPR_COUNTRY=eu
EOF

# Install OpenALPR and dependencies
cd /opt/lpr-app/deployment
chmod +x provision-ec2.sh
./provision-ec2.sh

# Build frontend
cd /opt/lpr-app/frontend
npm install --legacy-peer-deps
npm run build -- --configuration production

# Start services
sudo systemctl enable lpr-backend
sudo systemctl start lpr-backend
sudo systemctl restart nginx

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
"@

ssh -o StrictHostKeyChecking=no -i $KEY_PATH "ubuntu@${EC2_IP}" $sshCommand

# Cleanup
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "=========================================="  -ForegroundColor Green
Write-Host "DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "=========================================="  -ForegroundColor Green
Write-Host ""
Write-Host "Your License Plate Recognition app is now live at:" -ForegroundColor Cyan
Write-Host "  http://$EC2_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open this URL in your browser to use the application!" -ForegroundColor Green
Write-Host ""


