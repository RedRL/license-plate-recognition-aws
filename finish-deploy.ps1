# Simple PowerShell script to finish deployment
# Uploads install script to EC2 and runs it

$EC2_IP = "3.66.164.127"
$KEY = "lpr-keypair.pem"
$REGION = "eu-central-1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Finishing AWS Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get AWS resources
Write-Host "[INFO] Getting configuration from AWS..." -ForegroundColor Green

$DB_ENDPOINT = (aws cloudformation describe-stacks --stack-name LicensePlateStack --region $REGION --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" --output text)
$S3_BUCKET = (aws cloudformation describe-stacks --stack-name LicensePlateStack --region $REGION --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" --output text)
$DB_PASSWORD = (aws cloudformation describe-stacks --stack-name LicensePlateStack --region $REGION --query "Stacks[0].Parameters[?ParameterKey=='DBPassword'].ParameterValue" --output text)

Write-Host "[INFO] DB: $DB_ENDPOINT" -ForegroundColor Green
Write-Host "[INFO] S3: $S3_BUCKET" -ForegroundColor Green
Write-Host ""

# Upload install script
Write-Host "[INFO] Uploading install script to EC2..." -ForegroundColor Green
scp -o StrictHostKeyChecking=no -i $KEY deployment/install-on-ec2.sh "ubuntu@${EC2_IP}:/tmp/"

Write-Host "[INFO] Running installation (this will take 15-20 minutes)..." -ForegroundColor Yellow
Write-Host "[INFO] You can monitor progress - the script is running on EC2..." -ForegroundColor Yellow
Write-Host ""

# Run the install script on EC2
ssh -o StrictHostKeyChecking=no -i $KEY "ubuntu@${EC2_IP}" "bash /tmp/install-on-ec2.sh $REGION $S3_BUCKET $DB_ENDPOINT $DB_PASSWORD"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your app is live at: http://$EC2_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open this URL in your browser!" -ForegroundColor Green
Write-Host ""


