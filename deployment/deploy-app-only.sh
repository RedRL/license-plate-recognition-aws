#!/bin/bash
# Deploy application only to existing EC2 instance

set -e

# Configuration
REGION="eu-central-1"
STACK_NAME="LicensePlateStack"
KEY_NAME="lpr-keypair-sshfix"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying application to existing EC2 instance...${NC}"

# Get EC2 IP
EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`EC2PublicIP`].OutputValue' \
    --output text)

echo "EC2 IP: $EC2_IP"

# Get other outputs
DB_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
    --output text)

S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

SQS_QUEUE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`SQSQueueURL`].OutputValue' \
    --output text)

DB_PASSWORD=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Parameters[?ParameterKey==`DBPassword`].ParameterValue' \
    --output text)

echo "Creating application package..."

# Create tarball
cd "$PROJECT_DIR"
tar -czf /tmp/lpr-app.tar.gz \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='.angular' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='vcpkg' \
    --exclude='OpenALPR*' \
    --exclude='New folder' \
    --exclude='uploads' \
    --exclude='logs' \
    backend/ frontend/ deployment/

echo "Uploading application code..."
scp -o StrictHostKeyChecking=no -i "${SCRIPT_DIR}/${KEY_NAME}.pem" /tmp/lpr-app.tar.gz "ubuntu@${EC2_IP}:/tmp/"

echo "Installing application on EC2..."
ssh -o StrictHostKeyChecking=no -i "${SCRIPT_DIR}/${KEY_NAME}.pem" ubuntu@${EC2_IP} << ENDSSH
    set -e
    
    # Extract application
    sudo rm -rf /opt/lpr-app
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar -xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    
    # Create environment file
    cat > /opt/lpr-app/.env << 'EOF'
AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}
SQS_QUEUE_URL=${SQS_QUEUE_URL}
DB_HOST=${DB_ENDPOINT}
DB_PORT=3306
DB_NAME=license_plates_db
DB_USER=admin
DB_PASSWORD=${DB_PASSWORD}
LOCAL_MODE=false
ASYNC_PROCESSING=true
ALPR_COUNTRY=eu
UPLOAD_DIR=/opt/lpr-app/backend/uploads
LOG_LEVEL=INFO
LOG_FILE=/opt/lpr-app/backend/logs/app.log
WORKER_LOG_FILE=/opt/lpr-app/backend/logs/worker.log
EOF
    
    # Run provisioning script
    cd /opt/lpr-app/deployment
    chmod +x provision-ec2.sh
    bash provision-ec2.sh
    
    # Start services
    sudo systemctl restart lpr-backend
    sudo systemctl restart lpr-worker
    
    echo "Deployment complete!"
ENDSSH

rm -f /tmp/lpr-app.tar.gz

echo -e "${GREEN}Application deployed successfully!${NC}"
echo "Application URL: http://${EC2_IP}"
