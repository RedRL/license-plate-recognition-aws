# Fix frontend build issues and deploy

$EC2_IP = "3.66.164.127"
$KEY = "lpr-keypair.pem"

Write-Host "[INFO] Fixing frontend build..." -ForegroundColor Green

# Run commands on EC2 to fix and build frontend
ssh -o StrictHostKeyChecking=no -i $KEY "ubuntu@${EC2_IP}" @'
cd /opt/lpr-app/frontend

# Clear any previous build
rm -rf dist node_modules .angular

# Install dependencies with force
npm install --force

# Build with verbose output
npm run build -- --configuration production 2>&1 | tee build.log

# Check if build succeeded
if [ -d "dist/new-front/browser" ]; then
    echo "[SUCCESS] Frontend built successfully!"
    
    # Update nginx config to point to correct path
    sudo tee /etc/nginx/sites-available/lpr-frontend > /dev/null << 'NGINX_EOF'
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
NGINX_EOF

    sudo nginx -t
    sudo systemctl reload nginx
    
    echo ""
    echo "Frontend deployed successfully!"
else
    echo "[ERROR] Frontend build failed. Check build.log"
    tail -50 build.log
    exit 1
fi
'@

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Frontend Fixed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Visit: http://$EC2_IP" -ForegroundColor Cyan
Write-Host ""


