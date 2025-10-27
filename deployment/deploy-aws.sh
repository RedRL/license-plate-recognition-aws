#!/bin/bash
#
# Complete AWS Deployment Script for License Plate Recognition System
# This script deploys the entire application to AWS (EC2, RDS, S3)
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - Git Bash (Windows) or Bash shell (Linux/Mac)
#   - AWS account with appropriate permissions
#
# Usage: ./deploy-aws.sh
#

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
KEY_NAME="lpr-keypair"

# Secrets directory (cross-platform). Prefer ~/.secrets/lpr; fallback to derived USERPROFILE
if [[ "${HOME:-}" == /* ]]; then
    SECRETS_DIR="${HOME}/.secrets/lpr"
else
    if [ -n "${USERPROFILE:-}" ]; then
        WIN_HOME="${USERPROFILE//\\/\/}"
        DRIVE="${WIN_HOME%%:*}"
        PATH_PART="${WIN_HOME#*:}"
        SECRETS_DIR="/${DRIVE,,}${PATH_PART}/.secrets/lpr"
    else
        SECRETS_DIR="${SCRIPT_DIR}/.secrets/lpr"
    fi
fi
mkdir -p "$SECRETS_DIR" 2>/dev/null || true
chmod 700 "$SECRETS_DIR" 2>/dev/null || true
KEY_FILE="${SECRETS_DIR}/${KEY_NAME}.pem"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   License Plate Recognition - AWS Deployment Script            ║"
echo "║   Complete automated deployment to AWS                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Please install: https://aws.amazon.com/cli/${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not configured. Run: aws configure${NC}"
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity)
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": *"[^"]*"' | cut -d'"' -f4)
USER_ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": *"[^"]*"' | cut -d'"' -f4)

echo -e "${GREEN}✓ AWS CLI configured${NC}"
echo -e "  Account: ${ACCOUNT_ID}"
echo -e "  User: ${USER_ARN}"

# Check for required files
cd "$PROJECT_DIR"
for file in "deployment/infra.yaml" "backend/app.py" "frontend/package.json"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Required file not found: $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required files present${NC}"

# Handle EC2 Key Pair
echo -e "\n${YELLOW}[2/8] Setting up EC2 key pair...${NC}"

RECREATE_NEEDED=false
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &> /dev/null; then
    echo -e "${GREEN}✓ Key pair '$KEY_NAME' already exists${NC}"
    if [ ! -f "$KEY_FILE" ] || [ "${FORCE_RECREATE_KEY:-false}" = "true" ]; then
        echo -e "${YELLOW}⚠ Local PEM missing or force recreate requested. Regenerating key pair...${NC}"
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" >/dev/null 2>&1 || true
        RECREATE_NEEDED=true
    fi
else
    RECREATE_NEEDED=true
fi

if [ "$RECREATE_NEEDED" = true ]; then
    echo "Creating new key pair: $KEY_NAME"
    KEY_MATERIAL=$(aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$REGION" \
        --query 'KeyMaterial' \
        --output text 2>&1)
    if [ $? -eq 0 ]; then
        # Ensure directory exists
        mkdir -p "$(dirname "$KEY_FILE")" 2>/dev/null || true
        # If file exists and may be read-only, make it writable or remove it
        if [ -f "$KEY_FILE" ]; then
            chmod u+w "$KEY_FILE" 2>/dev/null || true
            rm -f "$KEY_FILE" 2>/dev/null || true
        fi
        # Save (overwrite) local PEM and validate
        if printf '%s\n' "$KEY_MATERIAL" > "$KEY_FILE" 2>/dev/null; then
            chmod 400 "$KEY_FILE" 2>/dev/null || true
            echo -e "${GREEN}✓ Key pair created and saved to: ${KEY_FILE}${NC}"
        else
            echo -e "${RED}✗ Failed to save key to ${KEY_FILE}${NC}"
            exit 1
        fi
    fi
fi

# Get public IP for SSH security group
echo -e "\n${YELLOW}[3/8] Detecting your public IP for SSH access...${NC}"

MY_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://checkip.amazonaws.com 2>/dev/null || echo "0.0.0.0")
if [ "$MY_IP" = "0.0.0.0" ]; then
    echo -e "${YELLOW}⚠ Could not detect IP. SSH will be open to all (0.0.0.0/0)${NC}"
    SSH_CIDR="0.0.0.0/0"
else
    SSH_CIDR="${MY_IP}/32"
    echo -e "${GREEN}✓ Your IP: ${MY_IP}${NC}"
fi

# Generate or reuse database password
echo -e "\n${YELLOW}[4/8] Setting up database password...${NC}"

PASSWORD_FILE="${SCRIPT_DIR}/.db-password"
if [ -f "$PASSWORD_FILE" ]; then
    DB_PASSWORD=$(cat "$PASSWORD_FILE")
    echo -e "${GREEN}✓ Reusing existing database password${NC}"
else
    DB_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
    echo "$DB_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    echo -e "${GREEN}✓ Database password generated and saved${NC}"
fi

# Check for existing stack
echo -e "\n${YELLOW}[5/8] Checking for existing CloudFormation stack...${NC}"

STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "NONE")

if [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ]; then
    echo "Stack in ROLLBACK_COMPLETE state. Deleting..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    
    echo "Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
    sleep 5
    STACK_STATUS="NONE"
fi

# Deploy CloudFormation stack
echo -e "\n${YELLOW}[6/8] Deploying CloudFormation stack...${NC}"
echo "This will take 5-10 minutes..."

aws cloudformation deploy \
    --template-file deployment/infra.yaml \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        KeyName="$KEY_NAME" \
        SSHLocation="$SSH_CIDR" \
        DBPassword="$DB_PASSWORD"

echo -e "${GREEN}✓ CloudFormation stack deployed${NC}"

# Get stack outputs
echo -e "\n${YELLOW}[7/8] Retrieving infrastructure details...${NC}"

EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`EC2PublicIP`].OutputValue' \
    --output text)

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

# Fetch SQS queue URLs
SQS_QUEUE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`SQSQueueURL`].OutputValue' \
    --output text)

SQS_DLQ_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`SQSDeadLetterQueueURL`].OutputValue' \
    --output text)

echo -e "${GREEN}✓ Infrastructure ready${NC}"
echo "  EC2 Instance: ${EC2_IP}"
echo "  RDS Database: ${DB_ENDPOINT}"
echo "  S3 Bucket: ${S3_BUCKET}"
echo "  SQS Queue: ${SQS_QUEUE_URL}"
echo "  SQS DLQ: ${SQS_DLQ_URL}"

# Deploy application code to EC2
echo -e "\n${YELLOW}[8/8] Deploying application to EC2...${NC}"
echo "Waiting for EC2 to be ready (this may take 2-3 minutes)..."

# Resolve instance ID and wait for instance status checks to pass
EC2_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=ip-address,Values=${EC2_IP}" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

if [ "$EC2_ID" != "None" ] && [ -n "$EC2_ID" ]; then
    echo "Waiting for EC2 instance checks (instance-status-ok)..."
    aws ec2 wait instance-status-ok --region "$REGION" --instance-ids "$EC2_ID" || true
fi

# Wait for RDS to be available at the service level before SSH provisioning
echo "Waiting for RDS service to be available..."
aws rds wait db-instance-available --db-instance-identifier lpr-database --region "$REGION" || true

# Wait for EC2 to be accessible
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@${EC2_IP} "echo 'SSH Ready'" 2>/dev/null; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Could not connect to EC2 instance${NC}"
    exit 1
fi

echo -e "${GREEN}✓ EC2 instance accessible${NC}"

# Create deployment package (frontend will be built on EC2)
echo "Creating deployment package..."
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
    backend/ frontend/ deployment/

# Upload and extract on EC2
echo "Uploading application code..."
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" /tmp/lpr-app.tar.gz "ubuntu@${EC2_IP}:/tmp/"

# Run deployment on EC2
echo "Installing application on EC2..."
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@${EC2_IP} << ENDSSH
    set -e
    
    # Extract application
    sudo rm -rf /opt/lpr-app
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar -xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    
    # Create environment file with interpolated values
    cat > /opt/lpr-app/.env <<EOF
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
    
    # Load env for subsequent commands
    set -a
    . /opt/lpr-app/.env
    set +a
    
    # Run provisioning script (convert line endings if needed)
    cd /opt/lpr-app/deployment
    if command -v dos2unix &> /dev/null; then
        dos2unix provision-ec2.sh
    else
        sed -i 's/\r$//' provision-ec2.sh
    fi
    chmod +x provision-ec2.sh
    bash provision-ec2.sh
    
    # Build frontend on EC2
    echo "Building frontend on EC2..."
    cd /opt/lpr-app/frontend
    npm install
    npm run build -- --configuration production
    
    # Wait for RDS and initialize database
    echo "Waiting for RDS to accept connections at \$DB_HOST..."
    ATTEMPTS=0
    until mysql --connect-timeout=10 -h "\$DB_HOST" -u "\$DB_USER" -p"\$DB_PASSWORD" -e 'SELECT 1' >/dev/null 2>&1; do
        ATTEMPTS=\$((ATTEMPTS+1))
        if [ \$ATTEMPTS -ge 30 ]; then
            echo "Failed to connect to RDS after \$ATTEMPTS attempts."
            echo "Testing network connectivity..."
            nc -zv "\$DB_HOST" 3306 || echo "Port 3306 not reachable"
            echo "Attempting one more connection with verbose output..."
            mysql --connect-timeout=10 -h "\$DB_HOST" -u "\$DB_USER" -p"\$DB_PASSWORD" -e 'SELECT 1' 2>&1 | head -10
            exit 1
        fi
        echo "Attempt \$ATTEMPTS/30 failed, retrying in 10 seconds..."
        sleep 10
    done
    echo "RDS is ready. Initializing schema..."
    mysql -h "\$DB_HOST" -u "\$DB_USER" -p"\$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \$DB_NAME;" || true
    mysql -h "\$DB_HOST" -u "\$DB_USER" -p"\$DB_PASSWORD" "\$DB_NAME" < /opt/lpr-app/deployment/init-db.sql
    
    # Configure nginx (frontend already built locally)
    sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'NGINX_EOF'
server {
    listen 80 default_server;
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        client_max_body_size 50M;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX_EOF
    
    sudo rm -f /etc/nginx/sites-enabled/*
    sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx
    
    # Start backend and worker services
    sudo systemctl restart lpr-backend
    sudo systemctl restart lpr-worker
    
    echo "Deployment complete!"
ENDSSH

rm -f /tmp/lpr-app.tar.gz

# Save credentials to file first
CREDS_FILE="${SCRIPT_DIR}/aws-credentials.txt"
cat > "$CREDS_FILE" << EOF
License Plate Recognition - AWS Credentials
Generated: $(date)

Web Application: http://${EC2_IP}

EC2 Instance: ${EC2_IP}
SSH Command: ssh -i ${KEY_NAME}.pem ubuntu@${EC2_IP}

RDS Database: ${DB_ENDPOINT}
Database User: admin
Database Password: ${DB_PASSWORD}
Database Name: license_plates_db

S3 Bucket: ${S3_BUCKET}

SQS Queue: ${SQS_QUEUE_URL}
SQS Dead Letter Queue: ${SQS_DLQ_URL}

Region: ${REGION}
CloudFormation Stack: ${STACK_NAME}
EOF

# Final summary
echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT SUCCESSFUL! 🎉                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}Infrastructure Details:${NC}"
echo -e "  📦 EC2 Instance: ${EC2_IP}"
echo -e "  🗄️  RDS Database: ${DB_ENDPOINT}"
echo -e "  💾 S3 Bucket: ${S3_BUCKET}"
echo -e "  📨 SQS Queue: ${SQS_QUEUE_URL}"
echo -e "  ⚠️  SQS DLQ: ${SQS_DLQ_URL}"
echo -e "  🔑 SSH Key: ${KEY_FILE}"
echo ""
echo -e "${CYAN}SSH Access:${NC}"
echo -e "  ssh -i ${KEY_FILE} ubuntu@${EC2_IP}"
echo ""
echo -e "${CYAN}Database Connection:${NC}"
echo -e "  Host: ${DB_ENDPOINT}"
echo -e "  User: admin"
echo -e "  Password: ${DB_PASSWORD}"
echo -e "  Database: license_plates_db"
echo ""
echo -e "${GREEN}✓ Credentials saved to: ${CREDS_FILE}${NC}"
echo ""
echo -e "${YELLOW}⚠️  Save these credentials in a secure location!${NC}"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Your application is now live at:${NC}"
echo ""
echo -e "  🌐 ${GREEN}${BOLD}http://${EC2_IP}${NC}"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""


