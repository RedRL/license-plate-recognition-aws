#!/bin/bash
# Deploy frontend build to EC2

TAR_FILE=$1
EC2_IP=$2

# Extract frontend
sudo mkdir -p /opt/lpr-app/frontend/dist/new-front
cd /tmp
tar -xzf "$TAR_FILE"
sudo rm -rf /opt/lpr-app/frontend/dist/new-front/browser
sudo mv browser /opt/lpr-app/frontend/dist/new-front/

# Remove all existing nginx configs
sudo rm -f /etc/nginx/sites-enabled/*

# Configure nginx
sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /opt/lpr-app/frontend/dist/new-front/browser;
    index index.html;

    # Serve uploaded images
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
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/lpr-frontend

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx

# Cleanup
rm -f "/tmp/$TAR_FILE"

echo ""
echo "[SUCCESS] Frontend deployed!"

