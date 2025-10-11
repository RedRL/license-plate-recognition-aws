#!/bin/bash
# Interactive AWS Deployment Script for License Plate Recognition
# This script asks for all needed information during runtime

# Note: Not using 'set -e' to allow graceful error handling

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
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

log_question() {
    echo -e "${CYAN}[?]${NC} $1"
}

# Welcome banner
clear
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     License Plate Recognition - AWS Deployment Setup         ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

log_info "This script will guide you through deploying your application to AWS"
log_info "It will check prerequisites and ask for any missing information"
echo ""
read -p "Press Enter to continue..."

# Step 1: Check AWS CLI
log_step "Step 1/6: Checking AWS CLI"

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed!"
    echo ""
    echo "Please install AWS CLI:"
    echo "  Windows: https://awscli.amazonaws.com/AWSCLIV2.msi"
    echo "  Linux:   curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
    echo "  Mac:     brew install awscli"
    echo ""
    exit 1
else
    log_info "AWS CLI is installed: $(aws --version)"
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured!"
    echo ""
    log_question "Would you like to configure AWS credentials now? (yes/no)"
    read -p "> " configure_aws
    
    if [ "$configure_aws" = "yes" ] || [ "$configure_aws" = "y" ]; then
        echo ""
        log_info "Please enter your AWS credentials:"
        aws configure
        
        # Verify again
        if ! aws sts get-caller-identity &> /dev/null; then
            log_error "AWS credentials still not working. Please check and try again."
            exit 1
        fi
    else
        echo ""
        log_error "Please run 'aws configure' to set up your credentials, then run this script again."
        exit 1
    fi
else
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    log_info "AWS credentials verified ✓"
    log_info "Account ID: $ACCOUNT_ID"
    log_info "Caller: $CALLER_ARN"
fi

# Step 2: Set deployment region
log_step "Step 2/4: AWS Region"

REGION="eu-central-1"
log_info "Deploying to: $REGION (Frankfurt - closest to Israel with free tier) ✓"

# Step 3: EC2 Key Pair
log_step "Step 3/4: EC2 Key Pair Setup"

KEY_NAME="lpr-keypair"
log_info "Using key pair name: $KEY_NAME"

# Check if this key pair already exists in the region
KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "")

# Determine key storage location - use script directory (most reliable)
KEY_PATH="${SCRIPT_DIR}/${KEY_NAME}.pem"

if [ -n "$KEY_EXISTS" ]; then
    log_info "Key pair '$KEY_NAME' already exists in AWS ✓"
    
    if [ -f "$KEY_PATH" ]; then
        log_info "Found local key file at: $KEY_PATH ✓"
    else
        log_warn "Key pair exists in AWS but .pem file not found locally"
        log_warn "Expected location: $KEY_PATH"
        log_warn "You won't be able to SSH unless you have the .pem file elsewhere"
    fi
else
    log_info "Creating new key pair: $KEY_NAME"
    log_info "Saving to: $KEY_PATH"
    
    # Create the key pair and get the key material
    KEY_MATERIAL=$(aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$REGION" \
        --query 'KeyMaterial' \
        --output text 2>&1)
    
    if [ $? -eq 0 ] && [[ "$KEY_MATERIAL" == "-----BEGIN RSA PRIVATE KEY-----"* ]]; then
        # Successfully created, save to file
        (echo "$KEY_MATERIAL" > "$KEY_PATH") 2>/dev/null || true
        
        if [ -f "$KEY_PATH" ]; then
            chmod 400 "$KEY_PATH" 2>/dev/null || true
            log_info "Key pair created and saved to: $KEY_PATH ✓"
        else
            log_warn "Key pair created in AWS but couldn't save locally"
            log_warn "SSH access won't be available, but deployment will continue"
        fi
    else
        log_warn "Could not create key pair in AWS (might already exist)"
        log_warn "Deployment will continue without SSH access"
    fi
fi

# Step 4: Database Password
log_step "Step 4/4: Database Configuration"

# Auto-generate a secure password
DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
log_info "Auto-generated secure database password ✓"
log_info "Password: $DB_PASSWORD"
log_info "Note: This password is stored in AWS Secrets Manager and used automatically by the app"

# Security - Your IP address
log_info "Configuring SSH security..."

log_info "Auto-detecting your public IP address for SSH security..."
YOUR_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s api.ipify.org || echo "")

if [ -z "$YOUR_IP" ]; then
    log_warn "Could not automatically detect IP address, using 0.0.0.0/0 (allow from anywhere)"
    YOUR_IP="0.0.0.0/0"
else
    YOUR_IP="${YOUR_IP}/32"
    log_info "Detected your IP: $YOUR_IP ✓"
    log_info "SSH access will be restricted to your IP only (more secure)"
fi

# Deployment Summary
log_step "Deployment Configuration Summary"

echo "Please review your deployment configuration:"
echo ""
echo "  Stack Name:       $STACK_NAME"
echo "  AWS Region:       $REGION"
echo "  AWS Account:      $ACCOUNT_ID"
echo "  EC2 Key Pair:     $KEY_NAME"
echo "  SSH Access From:  $YOUR_IP"
echo "  DB Password:      $DB_PASSWORD"
echo ""
echo "AWS Resources to be created:"
echo "  • VPC with public/private subnets"
echo "  • EC2 instance (t3.micro) - 🆓 FREE TIER (750 hours/month for 12 months)"
echo "  • RDS MySQL database (db.t3.micro) - 🆓 FREE TIER (750 hours/month for 12 months)"
echo "  • S3 bucket for image storage - 🆓 FREE TIER (5GB storage)"
echo "  • Security groups, IAM roles, etc."
echo ""
echo "💰 Estimated cost:"
echo "  • First 12 months with free tier: 🆓 FREE! (if within 750 hours/month usage)"
echo "  • After free tier: ~\$20/month"
echo ""
echo "⏱️  Deployment time: ~20-30 minutes"
echo ""

log_question "Do you want to proceed with deployment? (yes/no)"
read -p "> " proceed

if [ "$proceed" != "yes" ] && [ "$proceed" != "y" ]; then
    log_info "Deployment cancelled."
    exit 0
fi

# Start deployment
log_step "Starting AWS Deployment"

log_info "Calling main deployment script..."
echo ""

# Call the main deployment script with collected parameters
bash "${SCRIPT_DIR}/deploy-to-aws.sh" "$KEY_NAME" "$DB_PASSWORD" "$YOUR_IP"

DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo ""
    log_step "Deployment Successful! 🎉"
    
    echo ""
    log_info "Your License Plate Recognition system is now live on AWS!"
    echo ""
    log_info "Next steps:"
    echo "  1. Visit the Web Application URL shown above"
    echo "  2. Test uploading an image with a license plate"
    echo "  3. Query the database to see stored results"
    echo ""
    
    if [ -n "$KEY_PATH" ]; then
        log_info "SSH Access:"
        EC2_IP=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$EC2_IP" ]; then
            echo "  ssh -i $KEY_PATH ubuntu@${EC2_IP}"
        fi
    fi
    
    echo ""
    log_info "Useful commands:"
    echo "  • Check status:  ./deployment/check-deployment.sh"
    echo "  • Update app:    ./deployment/update-app.sh $KEY_NAME"
    echo "  • Teardown:      ./deployment/teardown.sh"
    echo ""
else
    echo ""
    log_error "Deployment failed! Check the error messages above."
    echo ""
    log_info "Common issues:"
    echo "  • AWS service limits (try a different region)"
    echo "  • Insufficient IAM permissions"
    echo "  • Network connectivity issues"
    echo ""
    log_info "For detailed troubleshooting, see DEPLOYMENT.md"
    exit 1
fi

