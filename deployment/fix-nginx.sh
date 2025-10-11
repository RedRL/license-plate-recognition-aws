#!/bin/bash
# Fix nginx configuration

sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /opt/lpr-app/frontend/dist/new-front/browser;
    index index.html;
    
    # Allow larger file uploads
    client_max_body_size 50M;

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
        client_max_body_size 50M;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx

echo "Nginx configuration updated!"

