#!/bin/bash
# Deploy application only to existing EC2 instance

set -e

# Configuration
REGION="eu-central-1"
STACK_NAME="LicensePlateStack"
KEY_NAME="lpr-keypair"
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
SECRETS_DIR="${HOME}/.secrets/lpr"
mkdir -p "$SECRETS_DIR" 2>/dev/null || true
KEY_FILE="${SECRETS_DIR}/${KEY_NAME}.pem"
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" /tmp/lpr-app.tar.gz "ubuntu@${EC2_IP}:/tmp/"

echo "Installing application on EC2..."
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@${EC2_IP} << ENDSSH
    set -e
    
    # Extract application
    sudo rm -rf /opt/lpr-app
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar -xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    
    # Create environment file
    cat > /opt/lpr-app/.env << EOF
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
    
    # Run provisioning script (convert line endings if needed)
    cd /opt/lpr-app/deployment
    if command -v dos2unix &> /dev/null; then
        dos2unix provision-ec2.sh
    else
        sed -i 's/\r$//' provision-ec2.sh
    fi
    chmod +x provision-ec2.sh
    bash provision-ec2.sh
    
    # Build frontend on EC2 (ensures Angular dist exists)
    echo "Building frontend on EC2..."
    cd /opt/lpr-app/frontend
    npm install
    npm run build -- --configuration production
    
    # Ensure nginx points to the correct dist path and reload
    sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'NGINX_EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /opt/lpr-app/frontend/dist/new-front/browser;
    index index.html;
    client_max_body_size 50M;

    location /uploads/ {
        alias /opt/lpr-app/backend/uploads/;
        access_log off;
        expires 1h;
    }

    location /api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        client_max_body_size 50M;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF
    
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx
    
    # Initialize database schema
    set -a
    . /opt/lpr-app/.env
    set +a
    echo "Initializing database schema..."
    mysql --connect-timeout=10 -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" || true
    mysql --connect-timeout=10 -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /opt/lpr-app/deployment/init-db.sql
    
    # Start services
    sudo systemctl restart lpr-backend
    sudo systemctl restart lpr-worker
    
    echo "Deployment complete!"
ENDSSH

rm -f /tmp/lpr-app.tar.gz

echo -e "${GREEN}Application deployed successfully!${NC}"
echo "Application URL: http://${EC2_IP}"
