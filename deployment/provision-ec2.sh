#!/bin/bash
# EC2 Provisioning Script for License Plate Recognition
# This script installs OpenALPR, Python dependencies, and sets up the application
set -e

echo "========================================"
echo "LPR EC2 Provisioning Script"
echo "========================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    log_error "Please run as ubuntu user, not root"
    exit 1
fi

log_info "Starting provisioning process..."

# Update system
log_info "Updating system packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install build dependencies for OpenALPR
log_info "Installing OpenALPR build dependencies..."
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    libopencv-dev \
    libtesseract-dev \
    libleptonica-dev \
    tesseract-ocr \
    tesseract-ocr-eng \
    liblog4cplus-dev \
    libcurl4-openssl-dev \
    wget \
    unzip

# Build and install OpenALPR from source
log_info "Building OpenALPR from source..."
cd /tmp
if [ -d "openalpr" ]; then
    rm -rf openalpr
fi

git clone https://github.com/openalpr/openalpr.git
cd openalpr/src
mkdir -p build
cd build

cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_INSTALL_SYSCONFDIR:PATH=/etc ..

# Use only 1 core for t3.micro to avoid memory issues
log_info "Compiling OpenALPR (this will take 15-20 minutes on t3.micro)..."
make -j1
sudo make install

# Verify OpenALPR installation
if ! command -v alpr &> /dev/null; then
    log_error "OpenALPR installation failed"
    exit 1
fi

log_info "OpenALPR installed successfully: $(alpr --version 2>&1 | head -1)"

# Install Python dependencies
log_info "Installing Python dependencies..."
cd /opt/lpr-app

# Copy requirements.txt from uploaded code
if [ -f "backend/requirements.txt" ]; then
    pip3 install --upgrade pip
    pip3 install -r backend/requirements.txt
    log_info "Python dependencies installed"
else
    log_warn "requirements.txt not found, will be installed later"
fi

# Install Node.js dependencies for frontend
log_info "Installing frontend dependencies..."
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
    cd frontend
    npm install
    log_info "Frontend dependencies installed"
    cd /opt/lpr-app
else
    log_warn "Frontend directory not found, will be installed later"
fi

# Create directories for uploads and logs
log_info "Creating application directories..."
mkdir -p /opt/lpr-app/backend/uploads
mkdir -p /opt/lpr-app/backend/logs
chown -R ubuntu:ubuntu /opt/lpr-app

# Set up systemd service for Flask backend
log_info "Setting up Flask backend service..."
sudo tee /etc/systemd/system/lpr-backend.service > /dev/null << 'EOF'
[Unit]
Description=License Plate Recognition Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/lpr-app/backend
EnvironmentFile=/opt/lpr-app/.env
Environment="PYTHONUNBUFFERED=1"
ExecStart=/usr/bin/python3 /opt/lpr-app/backend/app.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/lpr-app/backend/logs/backend.log
StandardError=append:/opt/lpr-app/backend/logs/backend-error.log

[Install]
WantedBy=multi-user.target
EOF

# Set up nginx for frontend
log_info "Configuring nginx..."
sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /opt/lpr-app/frontend/dist/frontend/browser;
    index index.html;

    # Serve Angular app
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to Flask backend
    location /api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Serve uploaded files (if needed)
    location /uploads/ {
        alias /opt/lpr-app/backend/uploads/;
        autoindex off;
    }
}
EOF

# Remove default nginx site and enable our site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Reload systemd
sudo systemctl daemon-reload

log_info "Provisioning complete!"
log_info "Services are configured but not started yet."
log_info "Run 'sudo systemctl start lpr-backend' to start the backend"
log_info "Run 'sudo systemctl restart nginx' to start nginx"

echo "========================================"
echo "Provisioning Summary:"
echo "  - OpenALPR: Installed from source"
echo "  - Python dependencies: Installed"
echo "  - Systemd service: lpr-backend.service"
echo "  - Nginx: Configured for frontend + API proxy"
echo "========================================"

