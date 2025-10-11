#!/bin/bash
# Complete the deployment after CloudFormation succeeds
# This script uploads code, installs dependencies, and starts services

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "\n${BLUE}========================================${NC}\n${BLUE}$1${NC}\n${BLUE}========================================${NC}\n"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
KEY_NAME="lpr-keypair"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

# Get EC2 IP
log_info "Getting EC2 instance IP..."
EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" \
    --output text)

if [ -z "$EC2_IP" ]; then
    log_error "Could not get EC2 IP. Is the CloudFormation stack deployed?"
    exit 1
fi

log_info "EC2 IP: $EC2_IP"

# Find key file
if [ -f "${SCRIPT_DIR}/${KEY_NAME}.pem" ]; then
    KEY_PATH="${SCRIPT_DIR}/${KEY_NAME}.pem"
elif [ -f "$HOME/.ssh/${KEY_NAME}.pem" ]; then
    KEY_PATH="$HOME/.ssh/${KEY_NAME}.pem"
else
    log_error "Key file not found! Expected at:"
    echo "  ${SCRIPT_DIR}/${KEY_NAME}.pem"
    echo "  or $HOME/.ssh/${KEY_NAME}.pem"
    exit 1
fi

log_info "Using key: $KEY_PATH"

# Test SSH connectivity
log_step "Testing SSH Connectivity"

log_info "Waiting for SSH to be available..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
        -i "$KEY_PATH" ubuntu@${EC2_IP} "echo SSH Ready" &> /dev/null; then
        log_info "SSH is ready ✓"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        log_error "SSH connection timeout after 5 minutes"
        exit 1
    fi
    
    echo -n "."
    sleep 5
done

# Upload application code
log_step "Uploading Application Code"

temp_dir=$(mktemp -d)
log_info "Preparing code package..."

cp -r "${SCRIPT_DIR}/backend" "$temp_dir/"
cp -r "${SCRIPT_DIR}/frontend" "$temp_dir/"
mkdir -p "$temp_dir/deployment"
cp "${SCRIPT_DIR}/deployment/"*.sh "$temp_dir/deployment/" 2>/dev/null || true
cp "${SCRIPT_DIR}/deployment/"*.sql "$temp_dir/deployment/" 2>/dev/null || true

cd "$temp_dir"
tar czf lpr-app.tar.gz backend frontend deployment

log_info "Uploading to EC2..."
scp -o StrictHostKeyChecking=no -i "$KEY_PATH" \
    lpr-app.tar.gz ubuntu@${EC2_IP}:/tmp/

log_info "Extracting on EC2..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    rm /tmp/lpr-app.tar.gz
ENDSSH

rm -rf "$temp_dir"
log_info "Code uploaded ✓"

# Get DB endpoint
log_step "Getting Database Configuration"

DB_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
    --output text)

S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text)

log_info "DB Endpoint: $DB_ENDPOINT"
log_info "S3 Bucket: $S3_BUCKET"

# Initialize database
log_step "Initializing Database"

log_info "Waiting for RDS database to be available..."
aws rds wait db-instance-available \
    --db-instance-identifier lpr-database \
    --region "$REGION"

log_info "RDS is available ✓"

# Get password from CloudFormation parameters
DB_PASSWORD=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Parameters[?ParameterKey=='DBPassword'].ParameterValue" \
    --output text)

if [ -z "$DB_PASSWORD" ]; then
    log_error "Could not retrieve database password from CloudFormation"
    log_info "Trying Secrets Manager..."
    
    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id LPR-DB-Credentials \
        --region "$REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$SECRET_JSON" ]; then
        DB_PASSWORD=$(echo "$SECRET_JSON" | grep -o '"password":"[^"]*"' | cut -d'"' -f4)
    fi
fi

log_info "Retrieved database credentials ✓"
log_info "Running database initialization..."

# Install MySQL client on EC2 if not already installed
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << ENDSSH
    if ! command -v mysql &> /dev/null; then
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client
    fi
    
    mysql -h ${DB_ENDPOINT} -u admin -p${DB_PASSWORD} < /opt/lpr-app/deployment/init-db.sql
ENDSSH

log_info "Database initialized ✓"

# Provision EC2
log_step "Provisioning EC2 Instance"

log_info "Installing OpenALPR and dependencies (this takes 10-15 minutes)..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    cd /opt/lpr-app/deployment
    chmod +x provision-ec2.sh
    ./provision-ec2.sh
ENDSSH

log_info "EC2 provisioned ✓"

# Build frontend
log_step "Building Frontend"

log_info "Building Angular application..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    cd /opt/lpr-app/frontend
    npm install
    npm run build -- --configuration production
ENDSSH

log_info "Frontend built ✓"

# Start services
log_step "Starting Services"

log_info "Starting backend and nginx..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    sudo systemctl enable lpr-backend
    sudo systemctl start lpr-backend
    sudo systemctl restart nginx
ENDSSH

log_info "Services started ✓"

# Display final info
log_step "Deployment Complete!"

echo ""
echo "=========================================="
echo "DEPLOYMENT SUCCESSFUL!"
echo "=========================================="
echo ""
echo "Web Application URL:"
echo "  http://${EC2_IP}"
echo ""
echo "SSH Access:"
echo "  ssh -i ${KEY_PATH} ubuntu@${EC2_IP}"
echo ""
echo "S3 Bucket: ${S3_BUCKET}"
echo "Database: ${DB_ENDPOINT}"
echo ""
echo "Your License Plate Recognition app is now live! 🎉"
echo ""

