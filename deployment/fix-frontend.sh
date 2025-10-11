#!/bin/bash
# Fix and build frontend on EC2

cd /opt/lpr-app/frontend

# Clear previous build
rm -rf dist node_modules .angular

# Install with force
npm install --force

# Build production
npm run build -- --configuration production

# Configure nginx
sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /opt/lpr-app/frontend/dist/new-front/browser;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx

echo "Frontend deployed!"


