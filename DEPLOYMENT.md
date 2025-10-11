# AWS Deployment Guide - License Plate Recognition System

This guide provides complete instructions for deploying the License Plate Recognition application to AWS.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Architecture Overview](#architecture-overview)
4. [Detailed Deployment Steps](#detailed-deployment-steps)
5. [Post-Deployment](#post-deployment)
6. [Updating the Application](#updating-the-application)
7. [Monitoring and Logs](#monitoring-and-logs)
8. [Teardown](#teardown)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install the following tools on your local machine:

- **AWS CLI** (v2.x or higher)
  ```bash
  # Install on Linux/Mac
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  
  # Install on Windows
  # Download from: https://awscli.amazonaws.com/AWSCLIV2.msi
  ```

- **jq** (JSON processor)
  ```bash
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # Mac
  brew install jq
  
  # Windows
  # Download from: https://stedolan.github.io/jq/download/
  ```

- **SSH client** (included in most systems)

### AWS Requirements

1. **AWS Account** with appropriate permissions
2. **AWS CLI configured** with credentials
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, Region, and output format
   ```

3. **EC2 Key Pair** created in your target region
   ```bash
   # Create a new key pair
   aws ec2 create-key-pair \
     --key-name lpr-keypair \
     --query 'KeyMaterial' \
     --output text > ~/.ssh/lpr-keypair.pem
   
   chmod 400 ~/.ssh/lpr-keypair.pem
   ```

4. **Service Limits** - Ensure you have capacity for:
   - 1x t3.medium EC2 instance
   - 1x db.t3.micro RDS instance
   - 1x S3 bucket

---

## Quick Start

### One-Command Deployment

Deploy everything with a single script:

```bash
# Make the script executable
chmod +x deploy-to-aws.sh

# Run deployment
./deploy-to-aws.sh <YourKeyPairName> <DatabasePassword> [YourIPAddress]
```

**Example:**
```bash
./deploy-to-aws.sh lpr-keypair MySecurePass123 203.0.113.0/32
```

**Parameters:**
- `YourKeyPairName` - Name of your EC2 key pair (e.g., `lpr-keypair`)
- `DatabasePassword` - Password for RDS MySQL (minimum 8 characters)
- `YourIPAddress` - (Optional) Your IP for SSH access (default: 0.0.0.0/0)

The script will:
1. ✅ Deploy CloudFormation stack (VPC, EC2, RDS, S3, IAM)
2. ✅ Wait for resources to be ready
3. ✅ Upload application code
4. ✅ Initialize database
5. ✅ Install OpenALPR and dependencies
6. ✅ Build and deploy frontend
7. ✅ Start all services
8. ✅ Provide you with the application URL

**Total deployment time:** ~15-20 minutes

---

## Architecture Overview

### AWS Resources Created

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │                                                         │ │
│  │  ┌──────────────────┐       ┌──────────────────┐      │ │
│  │  │  Public Subnet   │       │  Public Subnet   │      │ │
│  │  │   (10.0.1.0/24)  │       │   (10.0.2.0/24)  │      │ │
│  │  │                  │       │                  │      │ │
│  │  │  ┌────────────┐  │       │                  │      │ │
│  │  │  │ EC2 Instance│  │       │                  │      │ │
│  │  │  │  (t3.medium)│  │       │                  │      │ │
│  │  │  │             │  │       │                  │      │ │
│  │  │  │ - Flask API │  │       │                  │      │ │
│  │  │  │ - Angular   │  │       │                  │      │ │
│  │  │  │ - OpenALPR  │  │       │                  │      │ │
│  │  │  └────────────┘  │       │                  │      │ │
│  │  └──────────────────┘       └──────────────────┘      │ │
│  │                                                         │ │
│  │  ┌──────────────────┐       ┌──────────────────┐      │ │
│  │  │ Private Subnet   │       │ Private Subnet   │      │ │
│  │  │   (10.0.3.0/24)  │       │   (10.0.4.0/24)  │      │ │
│  │  │                  │       │                  │      │ │
│  │  │  ┌────────────┐  │       │  ┌────────────┐  │      │ │
│  │  │  │ RDS MySQL  │◄─┼───────┼──┤ RDS Replica│  │      │ │
│  │  │  │(db.t3.micro)│  │       │  │ (Optional) │  │      │ │
│  │  │  └────────────┘  │       │  └────────────┘  │      │ │
│  │  └──────────────────┘       └──────────────────┘      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────┐          ┌──────────────────┐        │
│  │   S3 Bucket      │          │  Secrets Manager │        │
│  │ (Image Storage)  │          │ (DB Credentials) │        │
│  └──────────────────┘          └──────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **EC2 Instance (t3.medium)**
   - Flask backend (Python)
   - Angular frontend (via nginx)
   - OpenALPR for license plate recognition
   - Vehicle attributes detection service

2. **RDS MySQL (db.t3.micro)**
   - Stores license plate records
   - Automatic backups enabled
   - Multi-AZ optional

3. **S3 Bucket**
   - Stores uploaded images
   - Versioning enabled
   - CORS configured

4. **Networking**
   - VPC with public and private subnets
   - Internet Gateway for public access
   - Security groups for EC2 and RDS

5. **IAM**
   - EC2 instance role with S3 and Secrets Manager access
   - Least privilege permissions

---

## Detailed Deployment Steps

### Step 1: Prepare Your Environment

```bash
# Clone the repository
cd /path/to/license-plate-recognition-aws

# Verify all files are present
ls -la deploy-to-aws.sh infra.yaml deployment/
```

### Step 2: Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

### Step 3: Create EC2 Key Pair (if needed)

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name lpr-keypair \
  --region eu-central-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/lpr-keypair.pem

# Set permissions
chmod 400 ~/.ssh/lpr-keypair.pem
```

### Step 4: Run Deployment Script

```bash
# Make executable
chmod +x deploy-to-aws.sh
chmod +x deployment/*.sh

# Deploy
./deploy-to-aws.sh lpr-keypair MySecurePassword123 $(curl -s ifconfig.me)/32
```

The script will display progress for each step:
- ✅ Checking prerequisites
- ✅ Deploying CloudFormation stack
- ✅ Waiting for EC2 instance
- ✅ Uploading application code
- ✅ Initializing database
- ✅ Provisioning EC2 (installing OpenALPR, etc.)
- ✅ Building frontend
- ✅ Starting services
- ✅ Verifying deployment

### Step 5: Access Your Application

Once deployment is complete, you'll see:

```
==========================================
DEPLOYMENT SUMMARY
==========================================

Web Application URL:
  http://1.2.3.4

EC2 Instance:
  Public IP: 1.2.3.4
  SSH: ssh -i ~/.ssh/lpr-keypair.pem ubuntu@1.2.3.4

S3 Bucket:
  lpr-images-123456789-eu-central-1

Database:
  Endpoint: lpr-database.xxxxx.eu-central-1.rds.amazonaws.com
  Database: license_plates_db
  Username: admin

==========================================

Your License Plate Recognition application is now live!
Visit http://1.2.3.4 to access the web interface
```

Open your browser and navigate to the provided URL!

---

## Post-Deployment

### Verify Services

```bash
# Check deployment status
chmod +x deployment/check-deployment.sh
./deployment/check-deployment.sh
```

### SSH into EC2

```bash
ssh -i ~/.ssh/lpr-keypair.pem ubuntu@<EC2-IP>
```

### Check Service Status

```bash
# Backend service
sudo systemctl status lpr-backend

# Nginx
sudo systemctl status nginx

# View backend logs
tail -f /opt/lpr-app/backend/logs/backend.log
```

### Test the Application

1. **Upload an Image**
   - Go to "Upload Your Image"
   - Select or drag an image with a license plate
   - Click Upload
   - View recognition results

2. **Query Database**
   - Go to "Query Database"
   - Search by license plate, color, etc.
   - Edit entries by double-clicking

---

## Updating the Application

### Update Application Code

If you make changes to the code, update the deployment:

```bash
# Make script executable
chmod +x deployment/update-app.sh

# Run update
./deployment/update-app.sh lpr-keypair
```

This will:
1. Upload new code to EC2
2. Rebuild frontend
3. Restart backend service
4. Reload nginx

### Manual Update

```bash
# SSH into EC2
ssh -i ~/.ssh/lpr-keypair.pem ubuntu@<EC2-IP>

# Pull latest code (if using Git)
cd /opt/lpr-app
git pull

# Rebuild frontend
cd frontend
npm install
npm run build -- --configuration production

# Restart services
sudo systemctl restart lpr-backend
sudo systemctl reload nginx
```

---

## Monitoring and Logs

### Application Logs

```bash
# Backend logs
ssh -i ~/.ssh/lpr-keypair.pem ubuntu@<EC2-IP>
tail -f /opt/lpr-app/backend/logs/backend.log

# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log
```

### System Logs

```bash
# Backend service logs
sudo journalctl -u lpr-backend -f

# System logs
sudo journalctl -f
```

### Database Monitoring

```bash
# Connect to database
mysql -h <DB-ENDPOINT> -u admin -p

# View tables
USE license_plates_db;
SHOW TABLES;
SELECT COUNT(*) FROM plates;
```

### S3 Bucket

```bash
# List uploaded images
aws s3 ls s3://lpr-images-<ACCOUNT>-<REGION>/

# Check bucket size
aws s3 ls s3://lpr-images-<ACCOUNT>-<REGION>/ --recursive --summarize
```

---

## Teardown

### Complete Teardown

To remove all AWS resources:

```bash
# Make script executable
chmod +x deployment/teardown.sh

# Run teardown
./deployment/teardown.sh
```

This will:
1. Empty the S3 bucket
2. Delete the CloudFormation stack
3. Remove all resources (EC2, RDS, VPC, etc.)

**⚠️ WARNING:** This is irreversible! All data will be lost.

### Manual Teardown

```bash
# Empty S3 bucket first
aws s3 rm s3://lpr-images-<ACCOUNT>-<REGION>/ --recursive

# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name LicensePlateStack \
  --region eu-central-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name LicensePlateStack \
  --region eu-central-1
```

---

## Troubleshooting

### Deployment Fails at CloudFormation

**Issue:** Stack creation fails

**Solutions:**
1. Check AWS service limits (EC2, RDS)
2. Verify key pair exists in the region
3. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name LicensePlateStack \
     --region eu-central-1
   ```

### Cannot SSH into EC2

**Issue:** Connection timeout or refused

**Solutions:**
1. Verify your IP in security group:
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=LPR-EC2-SG" \
     --region eu-central-1
   ```
2. Check key pair permissions:
   ```bash
   chmod 400 ~/.ssh/lpr-keypair.pem
   ```
3. Wait 2-3 minutes after instance creation

### Application Not Accessible

**Issue:** Cannot access web app at http://EC2-IP

**Solutions:**
1. Check nginx status:
   ```bash
   ssh -i ~/.ssh/lpr-keypair.pem ubuntu@<EC2-IP>
   sudo systemctl status nginx
   ```
2. Check backend status:
   ```bash
   sudo systemctl status lpr-backend
   ```
3. View logs:
   ```bash
   tail -f /opt/lpr-app/backend/logs/backend.log
   ```

### Database Connection Fails

**Issue:** Backend cannot connect to RDS

**Solutions:**
1. Verify RDS endpoint in .env file:
   ```bash
   cat /opt/lpr-app/.env
   ```
2. Check security group rules allow EC2 → RDS
3. Test MySQL connection:
   ```bash
   mysql -h <DB-ENDPOINT> -u admin -p
   ```

### OpenALPR Not Working

**Issue:** License plate recognition fails

**Solutions:**
1. Verify OpenALPR installation:
   ```bash
   which alpr
   alpr --version
   ```
2. Test manually:
   ```bash
   alpr -c eu /path/to/test/image.jpg
   ```
3. Rebuild OpenALPR if needed:
   ```bash
   cd /opt/lpr-app/deployment
   ./provision-ec2.sh
   ```

### Frontend Build Fails

**Issue:** npm build errors

**Solutions:**
1. Check Node.js version:
   ```bash
   node --version  # Should be 18.x
   ```
2. Clear npm cache:
   ```bash
   cd /opt/lpr-app/frontend
   rm -rf node_modules package-lock.json
   npm install
   npm run build -- --configuration production
   ```

---

## Cost Estimate

Approximate monthly AWS costs (us-east-1 region):

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| EC2 t3.medium | 24/7 running | ~$30 |
| RDS db.t3.micro | 24/7 running | ~$15 |
| S3 Storage | 10GB + requests | ~$1 |
| Data Transfer | 10GB outbound | ~$1 |
| **Total** | | **~$47/month** |

*Prices are estimates and may vary by region and usage*

### Cost Optimization

1. **Use Reserved Instances** - Save up to 70% for 1-3 year commitments
2. **Auto-scaling** - Stop instances during non-business hours
3. **S3 Lifecycle Policies** - Move old images to Glacier
4. **RDS Snapshots** - Use snapshots and stop RDS when not needed

---

## Security Best Practices

1. **Restrict SSH Access**
   - Use your specific IP instead of 0.0.0.0/0
   - Rotate SSH keys regularly

2. **Strong Database Password**
   - Use AWS Secrets Manager for password rotation
   - Minimum 16 characters with special chars

3. **Enable CloudWatch Logs**
   - Monitor access patterns
   - Set up alarms for suspicious activity

4. **Regular Updates**
   - Keep system packages updated
   - Update application dependencies

5. **Backup Strategy**
   - RDS automated backups (enabled by default)
   - S3 versioning (enabled by default)
   - Export data regularly

---

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review CloudFormation stack events
3. Check application logs
4. Review AWS service health dashboard

---

## Summary

You now have a complete, production-ready License Plate Recognition system running on AWS! The deployment script handles everything automatically, from infrastructure setup to application deployment.

**Next Steps:**
- Test the application with various license plate images
- Set up CloudWatch monitoring and alarms
- Configure automated backups
- Consider adding a custom domain name and SSL certificate

Enjoy your automated license plate recognition system! 🚗🔍


