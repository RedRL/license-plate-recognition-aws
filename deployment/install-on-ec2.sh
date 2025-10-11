#!/bin/bash
# Script to run on EC2 to install everything
# This is uploaded and executed remotely

set -e

echo "=========================================="
echo "Installing License Plate Recognition App"
echo "=========================================="

# Get parameters from environment or arguments
AWS_REGION="${1:-eu-central-1}"
S3_BUCKET="${2:-}"
DB_HOST="${3:-}"
DB_PASSWORD="${4:-}"

# Extract code if tarball exists
if [ -f /tmp/lpr-app.tar.gz ]; then
    echo "[INFO] Extracting application code..."
    sudo mkdir -p /opt/lpr-app
    cd /opt/lpr-app
    sudo tar xzf /tmp/lpr-app.tar.gz
    sudo chown -R ubuntu:ubuntu /opt/lpr-app
    rm /tmp/lpr-app.tar.gz
fi

# Create environment file
echo "[INFO] Creating environment configuration..."
cat > /opt/lpr-app/.env << EOF
AWS_REGION=${AWS_REGION}
S3_BUCKET=${S3_BUCKET}
DB_HOST=${DB_HOST}
DB_PORT=3306
DB_NAME=license_plates_db
DB_USER=admin
DB_PASSWORD=${DB_PASSWORD}
LOCAL_MODE=false
ALPR_COUNTRY=eu
UPLOAD_DIR=/opt/lpr-app/backend/uploads
LOG_LEVEL=INFO
LOG_FILE=/opt/lpr-app/backend/logs/app.log
EOF

# Run provisioning script
echo "[INFO] Installing OpenALPR and dependencies (10-15 minutes)..."
cd /opt/lpr-app/deployment
chmod +x provision-ec2.sh
./provision-ec2.sh

# Build frontend
echo "[INFO] Building Angular frontend..."
cd /opt/lpr-app/frontend
npm install --legacy-peer-deps
npm run build -- --configuration production

# Start services
echo "[INFO] Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable lpr-backend
sudo systemctl start lpr-backend
sudo systemctl restart nginx

# Wait a moment
sleep 3

# Check status
echo ""
echo "=========================================="
echo "Service Status"
echo "=========================================="
sudo systemctl status lpr-backend --no-pager | head -15
echo ""
sudo systemctl status nginx --no-pager | head -15

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Check logs with:"
echo "  sudo journalctl -u lpr-backend -f"
echo "  tail -f /opt/lpr-app/backend/logs/backend.log"
echo ""


