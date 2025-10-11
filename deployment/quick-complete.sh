#!/bin/bash
# Quick completion script - skips DB init, focuses on getting app running

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "\n${BLUE}========================================${NC}\n${BLUE}$1${NC}\n${BLUE}========================================${NC}\n"; }

EC2_IP="3.66.164.127"
KEY_PATH="/c/Users/HarelY/Documents/Projects/FCloud/NewBonusProject/GIT/license-plate-recognition-aws/lpr-keypair.pem"

log_step "Quick Deployment Completion"

# Provision EC2
log_step "Installing OpenALPR and Dependencies"
log_info "This will take 10-15 minutes..."

ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    cd /opt/lpr-app/deployment
    chmod +x provision-ec2.sh
    ./provision-ec2.sh
ENDSSH

log_info "Dependencies installed ✓"

# Build frontend
log_step "Building Frontend"

ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    cd /opt/lpr-app/frontend
    npm install --legacy-peer-deps
    npm run build -- --configuration production
ENDSSH

log_info "Frontend built ✓"

# Start services
log_step "Starting Services"

ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@${EC2_IP} << 'ENDSSH'
    sudo systemctl enable lpr-backend
    sudo systemctl start lpr-backend
    sudo systemctl restart nginx
    
    # Show status
    sudo systemctl status lpr-backend --no-pager
    sudo systemctl status nginx --no-pager
ENDSSH

log_info "Services started ✓"

log_step "Deployment Complete!"

echo ""
echo "Your app is now live at: http://${EC2_IP}"
echo ""
echo "The database table will be created automatically when you upload the first image."
echo ""


