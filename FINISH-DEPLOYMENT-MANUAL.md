# Manual Steps to Finish Deployment

The CloudFormation stack is deployed, but the application needs to be installed on EC2.

## Quick Steps

### 1. SSH into EC2 and run these commands:

```bash
# SSH into your EC2 instance
ssh -i lpr-keypair.pem ubuntu@3.66.164.127

# Once connected, run these commands:

# Update system
sudo apt-get update

# Install build dependencies
sudo apt-get install -y build-essential cmake git libopencv-dev libtesseract-dev libleptonica-dev tesseract-ocr liblog4cplus-dev libcurl4-openssl-dev python3-pip

# Build OpenALPR
cd /tmp
git clone https://github.com/openalpr/openalpr.git
cd openalpr/src
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_INSTALL_SYSCONFDIR:PATH=/etc ..
make -j$(nproc)
sudo make install

# Install Python dependencies
cd /opt/lpr-app/backend
pip3 install -r requirements.txt

# Install Node.js and build frontend
cd /opt/lpr-app/frontend
npm install --legacy-peer-deps
npm run build -- --configuration production

# Create systemd service
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
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/lpr-frontend /etc/nginx/sites-enabled/

# Start services
sudo systemctl daemon-reload
sudo systemctl enable lpr-backend
sudo systemctl start lpr-backend
sudo systemctl restart nginx

# Check status
sudo systemctl status lpr-backend
sudo systemctl status nginx
```

### 2. Wait a few seconds, then visit:
```
http://3.66.164.127
```

Your app should be live!

---

## OR: Use this one-liner

SSH in and run:
```bash
ssh -i lpr-keypair.pem ubuntu@3.66.164.127 'bash -s' < deployment/provision-ec2.sh
```

Then manually build frontend and start services.


