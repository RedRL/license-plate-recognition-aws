# Interactive AWS Deployment Guide

## 🚀 Super Simple Deployment

We've created an **interactive deployment script** that asks for everything it needs!

---

## ✨ Two Ways to Deploy

### **Option 1: Windows (Double-Click!)** 

Just **double-click** `deploy.bat` in Windows Explorer!

The script will:
1. ✅ Check if you have Git Bash
2. ✅ Launch the interactive deployment
3. ✅ Ask you for everything it needs
4. ✅ Deploy to AWS automatically

**That's it!** No command line needed! 🎉

---

### **Option 2: Git Bash / Linux / Mac**

```bash
bash deploy-interactive.sh
```

Or make it executable first:
```bash
chmod +x deploy-interactive.sh
./deploy-interactive.sh
```

---

## 📋 What the Script Will Ask You

The interactive script guides you through 6 steps:

### **Step 1: AWS CLI Check**
- Checks if AWS CLI is installed
- If not configured, offers to run `aws configure`
- Verifies your credentials work

### **Step 2: jq Check**
- Checks if jq (JSON processor) is installed
- Offers to continue without it (optional)

### **Step 3: Select Region**
```
Which AWS region would you like to deploy to?
  1) eu-central-1 (Frankfurt) - Default
  2) us-east-1 (N. Virginia)
  3) us-west-2 (Oregon)
  4) ap-southeast-1 (Singapore)
  5) Other (type region code)
```

### **Step 4: EC2 Key Pair**
- Lists your existing key pairs (if any)
- Offers to create a new one
- Automatically saves the .pem file for you

### **Step 5: Database Password**
- Asks for a secure password (min 8 characters)
- Confirms the password
- Hidden input for security

### **Step 6: Security Configuration**
- Auto-detects your IP address
- Sets up SSH access restriction
- Option to allow from anywhere (0.0.0.0/0)

### **Configuration Summary**
Shows everything before deploying:
```
Stack Name:       LicensePlateStack
AWS Region:       eu-central-1
AWS Account:      123456789012
EC2 Key Pair:     lpr-keypair
SSH Access From:  203.0.113.0/32

AWS Resources to be created:
  • VPC with public/private subnets
  • EC2 instance (t3.medium) - ~$30/month
  • RDS MySQL database (db.t3.micro) - ~$15/month
  • S3 bucket for image storage - ~$1/month

Estimated monthly cost: ~$47
Deployment time: ~15-20 minutes

Do you want to proceed with deployment? (yes/no)
```

### **Deployment Begins!**
Then it automatically:
1. Deploys CloudFormation stack
2. Uploads your code
3. Installs OpenALPR
4. Builds frontend
5. Starts all services
6. Gives you the URL!

---

## 🎯 Example Run

```bash
$ bash deploy-interactive.sh

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     License Plate Recognition - AWS Deployment Setup         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

[INFO] This script will guide you through deploying your application to AWS
[INFO] It will check prerequisites and ask for any missing information

Press Enter to continue...

========================================
Step 1/6: Checking AWS CLI
========================================

[INFO] AWS CLI is installed: aws-cli/2.15.0
[INFO] AWS credentials verified ✓
[INFO] Account ID: 123456789012
[INFO] Caller: arn:aws:iam::123456789012:user/admin

========================================
Step 2/6: Checking jq (JSON processor)
========================================

[INFO] jq is installed: jq-1.6

========================================
Step 3/6: Select AWS Region
========================================

[?] Which AWS region would you like to deploy to?
  1) eu-central-1 (Frankfurt) - Default
  2) us-east-1 (N. Virginia)
  3) us-west-2 (Oregon)
  4) ap-southeast-1 (Singapore)
  5) Other (type region code)
Enter choice [1-5] (default: 1): 1
[INFO] Selected region: eu-central-1

========================================
Step 4/6: EC2 Key Pair Setup
========================================

[INFO] Checking for existing EC2 key pairs in eu-central-1...
[INFO] Found existing key pairs:
  1) my-old-key
  2) another-key
  3) Create a new key pair
[?] Select a key pair [1-3]:
> 3
[?] Enter a name for the new key pair:
> lpr-keypair
[INFO] Creating key pair: lpr-keypair
[INFO] Key pair created and saved to: /home/user/.ssh/lpr-keypair.pem

========================================
Step 5/6: Database Configuration
========================================

[?] Enter a password for the RDS MySQL database (min 8 characters):
> ********
[?] Confirm password:
> ********
[INFO] Password set ✓

========================================
Step 6/6: Security Configuration
========================================

[INFO] For security, we'll restrict SSH access to your IP address
[?] Would you like to automatically detect your IP address? (yes/no)
> yes
[INFO] Detecting your public IP address...
[INFO] Detected IP: 203.0.113.45/32

========================================
Deployment Configuration Summary
========================================

Please review your deployment configuration:

  Stack Name:       LicensePlateStack
  AWS Region:       eu-central-1
  AWS Account:      123456789012
  EC2 Key Pair:     lpr-keypair
  SSH Access From:  203.0.113.45/32

AWS Resources to be created:
  • VPC with public/private subnets
  • EC2 instance (t3.medium) - ~$30/month
  • RDS MySQL database (db.t3.micro) - ~$15/month
  • S3 bucket for image storage - ~$1/month
  • Security groups, IAM roles, etc.

Estimated monthly cost: ~$47
Deployment time: ~15-20 minutes

[?] Do you want to proceed with deployment? (yes/no)
> yes

========================================
Starting AWS Deployment
========================================

[INFO] Calling main deployment script...

[... deployment proceeds automatically ...]

========================================
Deployment Complete!
========================================

Web Application URL: http://3.123.45.67

[INFO] Your License Plate Recognition system is now live on AWS!
```

---

## 🛠️ What You Need (Minimal)

The script will check everything, but here's what you need:

1. **Git Bash** (Windows) or bash shell (Linux/Mac)
   - Windows: Comes with Git for Windows
   - Usually already installed

2. **AWS Account**
   - Free tier eligible for testing
   - Need AWS Access Key ID and Secret Access Key

3. **Internet Connection**
   - To download dependencies and communicate with AWS

That's literally it! The script handles everything else! 🎉

---

## ❓ What If Something Is Missing?

The script will:
- ✅ **AWS CLI not installed?** → Tells you where to download it
- ✅ **AWS not configured?** → Offers to run `aws configure`
- ✅ **No key pair?** → Creates one for you
- ✅ **jq missing?** → Offers to continue without it
- ✅ **No credentials?** → Guides you through setup

---

## 🎯 Quick Start

### **Windows:**
1. Double-click `deploy.bat`
2. Answer the questions
3. Wait 15-20 minutes
4. Done! 🚀

### **Linux/Mac/Git Bash:**
1. Run `bash deploy-interactive.sh`
2. Answer the questions
3. Wait 15-20 minutes
4. Done! 🚀

---

## 🧹 After Deployment

### **Access Your App:**
```
http://your-ec2-ip-address
```
The script shows you the URL at the end!

### **Check Status:**
```bash
bash deployment/check-deployment.sh
```

### **Update Code:**
```bash
bash deployment/update-app.sh your-keypair-name
```

### **Remove Everything:**
```bash
bash deployment/teardown.sh
```

---

## 🆘 Troubleshooting

### **"Git Bash not found"** (Windows)
Install Git for Windows:
https://git-scm.com/download/win

### **"AWS credentials not configured"**
The script will offer to run `aws configure` for you!

Or manually:
```bash
aws configure
# Enter:
#   AWS Access Key ID
#   AWS Secret Access Key
#   Default region: eu-central-1
#   Default output format: json
```

### **"Deployment failed"**
Check:
- AWS service limits (try different region)
- IAM permissions (need EC2, RDS, S3, IAM access)
- Internet connectivity

---

## 📖 Full Documentation

For detailed information:
- **Quick Guide:** `QUICK-START.md`
- **Full Guide:** `DEPLOYMENT.md`
- **File Overview:** `AWS-DEPLOYMENT-SUMMARY.md`

---

## ✨ Summary

**Before:** Complex setup with multiple commands and configuration files

**Now:** 
1. Run `deploy.bat` (Windows) or `bash deploy-interactive.sh`
2. Answer a few questions
3. Get your app URL!

**That's it!** 🎉

The script handles:
- ✅ Checking prerequisites
- ✅ Creating AWS resources
- ✅ Installing dependencies
- ✅ Building OpenALPR
- ✅ Deploying your code
- ✅ Starting services
- ✅ Everything!

**No more manual configuration!** Just run and answer questions! 🚀


