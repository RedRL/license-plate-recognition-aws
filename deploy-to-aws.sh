#!/bin/bash
# Master Deployment Script for License Plate Recognition on AWS
# This script orchestrates the complete deployment process
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"
    
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi
    
    if ! command -v scp &> /dev/null; then
        missing_tools+=("scp")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install these tools and try again"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    log_info "All prerequisites met ✓"
}

# Parse command line arguments
parse_arguments() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <KeyPairName> <DBPassword> [YourIPAddress]"
        echo ""
        echo "Arguments:"
        echo "  KeyPairName    - Name of existing EC2 KeyPair for SSH access"
        echo "  DBPassword     - Password for RDS database (min 8 characters)"
        echo "  YourIPAddress  - (Optional) Your IP for SSH access (default: 0.0.0.0/0)"
        echo ""
        echo "Example:"
        echo "  $0 my-keypair MySecurePass123 203.0.113.0/32"
        exit 1
    fi
    
    KEY_NAME="$1"
    DB_PASSWORD="$2"
    YOUR_IP="${3:-0.0.0.0/0}"
    
    # Validate DB password
    if [ ${#DB_PASSWORD} -lt 8 ]; then
        log_error "Database password must be at least 8 characters"
        exit 1
    fi
    
    log_info "Configuration:"
    log_info "  Stack Name: $STACK_NAME"
    log_info "  Region: $REGION"
    log_info "  Key Pair: $KEY_NAME"
    log_info "  Your IP: $YOUR_IP"
}

# Deploy CloudFormation stack
deploy_cloudformation() {
    log_step "Step 1: Deploying CloudFormation Stack"
    
    # Check if stack exists and is in ROLLBACK_COMPLETE state
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST")
    
    if [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ]; then
        log_warn "Stack exists in ROLLBACK_COMPLETE state, deleting it first..."
        aws cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region "$REGION"
        
        log_info "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION"
        
        log_info "Old stack deleted successfully ✓"
        
        # Give AWS a few seconds to fully process the deletion
        log_info "Waiting a few seconds for AWS to process..."
        sleep 5
    fi
    
    log_info "Creating/updating CloudFormation stack..."
    aws cloudformation deploy \
        --template-file "${SCRIPT_DIR}/infra.yaml" \
        --stack-name "$STACK_NAME" \
        --parameter-overrides \
            KeyName="$KEY_NAME" \
            DBPassword="$DB_PASSWORD" \
            YourIPAddress="$YOUR_IP" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --no-fail-on-empty-changeset
    
    if [ $? -eq 0 ]; then
        log_info "CloudFormation stack deployed successfully ✓"
    else
        log_error "CloudFormation deployment failed"
        exit 1
    fi
}

# Wait for EC2 to be ready
wait_for_ec2() {
    log_step "Step 2: Waiting for EC2 Instance"
    
    log_info "Retrieving EC2 instance ID..."
    INSTANCE_ID=$(aws cloudformation describe-stack-resources \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "StackResources[?ResourceType=='AWS::EC2::Instance'].PhysicalResourceId" \
        --output text)
    
    if [ -z "$INSTANCE_ID" ]; then
        log_error "Failed to retrieve EC2 instance ID"
        exit 1
    fi
    
    log_info "Instance ID: $INSTANCE_ID"
    log_info "Waiting for instance to be running..."
    
    aws ec2 wait instance-running \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION"
    
    log_info "Instance is running ✓"
    
    # Get instance public IP
    EC2_IP=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" \
        --output text)
    
    log_info "Public IP: $EC2_IP"
    
    # Wait for SSH to be available
    log_info "Waiting for SSH to be available (this may take 1-2 minutes)..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
            -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} "echo SSH Ready" &> /dev/null; then
            log_info "SSH is ready ✓"
            break
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            log_error "SSH connection timeout. Please check your key pair and security group settings."
            exit 1
        fi
        
        echo -n "."
        sleep 10
    done
}

# Upload application code
upload_code() {
    log_step "Step 3: Uploading Application Code"
    
    # Create temporary directory for code
    local temp_dir=$(mktemp -d)
    log_info "Preparing code package in $temp_dir..."
    
    # Copy backend
    cp -r "${SCRIPT_DIR}/backend" "$temp_dir/"
    
    # Copy frontend
    cp -r "${SCRIPT_DIR}/frontend" "$temp_dir/"
    
    # Copy deployment scripts
    mkdir -p "$temp_dir/deployment"
    cp "${SCRIPT_DIR}/deployment/"*.sh "$temp_dir/deployment/" 2>/dev/null || true
    cp "${SCRIPT_DIR}/deployment/"*.sql "$temp_dir/deployment/" 2>/dev/null || true
    
    # Create tarball
    log_info "Creating code archive..."
    cd "$temp_dir"
    tar czf lpr-app.tar.gz backend frontend deployment
    
    # Upload to EC2
    log_info "Uploading code to EC2..."
    scp -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem \
        lpr-app.tar.gz ubuntu@${EC2_IP}:/tmp/
    
    # Extract on EC2
    log_info "Extracting code on EC2..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
        cd /opt/lpr-app
        sudo tar xzf /tmp/lpr-app.tar.gz --strip-components=0
        sudo chown -R ubuntu:ubuntu /opt/lpr-app
        rm /tmp/lpr-app.tar.gz
ENDSSH
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_info "Code uploaded successfully ✓"
}

# Initialize database
initialize_database() {
    log_step "Step 4: Initializing Database"
    
    log_info "Retrieving database endpoint..."
    DB_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
        --output text)
    
    log_info "Database endpoint: $DB_ENDPOINT"
    
    # Initialize database via EC2
    log_info "Running database initialization script..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << ENDSSH
        mysql -h ${DB_ENDPOINT} -u admin -p${DB_PASSWORD} < /opt/lpr-app/deployment/init-db.sql
ENDSSH
    
    if [ $? -eq 0 ]; then
        log_info "Database initialized successfully ✓"
    else
        log_warn "Database initialization had issues, but continuing..."
    fi
}

# Provision EC2 instance
provision_ec2() {
    log_step "Step 5: Provisioning EC2 Instance"
    
    log_info "Running provisioning script on EC2..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
        cd /opt/lpr-app/deployment
        chmod +x provision-ec2.sh
        ./provision-ec2.sh
ENDSSH
    
    if [ $? -eq 0 ]; then
        log_info "EC2 provisioned successfully ✓"
    else
        log_error "EC2 provisioning failed"
        exit 1
    fi
}

# Build and deploy frontend
build_frontend() {
    log_step "Step 6: Building Frontend"
    
    log_info "Building Angular application..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
        cd /opt/lpr-app/frontend
        npm install
        npm run build -- --configuration production
ENDSSH
    
    if [ $? -eq 0 ]; then
        log_info "Frontend built successfully ✓"
    else
        log_error "Frontend build failed"
        exit 1
    fi
}

# Start services
start_services() {
    log_step "Step 7: Starting Services"
    
    log_info "Starting backend service..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
        sudo systemctl enable lpr-backend
        sudo systemctl start lpr-backend
        sudo systemctl status lpr-backend --no-pager
ENDSSH
    
    log_info "Starting nginx..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
        sudo systemctl restart nginx
        sudo systemctl status nginx --no-pager
ENDSSH
    
    log_info "Services started successfully ✓"
}

# Verify deployment
verify_deployment() {
    log_step "Step 8: Verifying Deployment"
    
    log_info "Testing backend health..."
    local backend_response=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} \
        "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/ || echo 'failed'")
    
    if [ "$backend_response" = "404" ] || [ "$backend_response" = "200" ]; then
        log_info "Backend is responding ✓"
    else
        log_warn "Backend health check returned: $backend_response"
    fi
    
    log_info "Testing nginx..."
    local nginx_response=$(curl -s -o /dev/null -w '%{http_code}' http://${EC2_IP}/ || echo 'failed')
    
    if [ "$nginx_response" = "200" ]; then
        log_info "Frontend is accessible ✓"
    else
        log_warn "Frontend health check returned: $nginx_response"
    fi
}

# Display final information
display_summary() {
    log_step "Deployment Complete!"
    
    # Get all outputs
    S3_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
        --output text)
    
    WEB_URL=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='WebAppURL'].OutputValue" \
        --output text)
    
    echo ""
    echo "=========================================="
    echo "DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo ""
    echo "Web Application URL:"
    echo "  ${WEB_URL}"
    echo ""
    echo "EC2 Instance:"
    echo "  Public IP: ${EC2_IP}"
    echo "  SSH: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP}"
    echo ""
    echo "S3 Bucket:"
    echo "  ${S3_BUCKET}"
    echo ""
    echo "Database:"
    echo "  Endpoint: ${DB_ENDPOINT}"
    echo "  Database: license_plates_db"
    echo "  Username: admin"
    echo ""
    echo "Services:"
    echo "  Backend: sudo systemctl status lpr-backend"
    echo "  Frontend: sudo systemctl status nginx"
    echo ""
    echo "Logs:"
    echo "  Backend: /opt/lpr-app/backend/logs/backend.log"
    echo "  Nginx: /var/log/nginx/"
    echo ""
    echo "=========================================="
    echo ""
    log_info "Your License Plate Recognition application is now live!"
    log_info "Visit ${WEB_URL} to access the web interface"
    echo ""
}

# Main execution
main() {
    log_step "License Plate Recognition - AWS Deployment"
    
    parse_arguments "$@"
    check_prerequisites
    deploy_cloudformation
    wait_for_ec2
    upload_code
    initialize_database
    provision_ec2
    build_frontend
    start_services
    verify_deployment
    display_summary
}

# Run main function
main "$@"

