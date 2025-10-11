#!/bin/bash
# Helper script to update the application code on an existing deployment
# Usage: ./update-app.sh <KeyPairName>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <KeyPairName>"
    exit 1
fi

KEY_NAME="$1"
STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Updating Application Code"
echo "=========================================="
echo ""

# Get EC2 IP
echo "Retrieving EC2 IP..."
EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" \
    --output text)

echo -e "${GREEN}✓${NC} EC2 IP: $EC2_IP"

# Create temporary directory for code
temp_dir=$(mktemp -d)
echo "Preparing code package..."

# Copy backend and frontend
cp -r "${SCRIPT_DIR}/backend" "$temp_dir/"
cp -r "${SCRIPT_DIR}/frontend" "$temp_dir/"

# Create tarball
cd "$temp_dir"
tar czf lpr-app-update.tar.gz backend frontend

# Upload to EC2
echo "Uploading code..."
scp -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem \
    lpr-app-update.tar.gz ubuntu@${EC2_IP}:/tmp/

# Extract and rebuild on EC2
echo "Extracting and rebuilding..."
ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} << 'ENDSSH'
    cd /opt/lpr-app
    sudo tar xzf /tmp/lpr-app-update.tar.gz --strip-components=0
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    rm /tmp/lpr-app-update.tar.gz
    
    # Rebuild frontend
    cd /opt/lpr-app/frontend
    npm install
    npm run build -- --configuration production
    
    # Restart backend
    sudo systemctl restart lpr-backend
    
    # Reload nginx
    sudo systemctl reload nginx
ENDSSH

# Cleanup
rm -rf "$temp_dir"

echo ""
echo -e "${GREEN}✓${NC} Application updated successfully!"
echo "Check logs with: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_IP} 'tail -f /opt/lpr-app/backend/logs/backend.log'"


