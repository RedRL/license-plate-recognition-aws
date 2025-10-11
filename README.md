# License Plate Recognition System — AWS Cloud Deployment

## ✨ **Three Ways to Deploy**

### 🌐 **Option 1: AWS CloudShell (EASIEST - No Setup!)**

**100% browser-based, zero installation required!**

1. Open [AWS Console](https://console.aws.amazon.com/)
2. Click the **CloudShell icon** (>_) in the top bar
3. Run:
   ```bash
   git clone https://github.com/YOUR-REPO/license-plate-recognition-aws.git
   cd license-plate-recognition-aws
   bash deploy-cloudshell.sh
   ```

**Done!** No AWS CLI, no Git, no configuration needed! 🎉

---

### 💻 **Option 2: Local Deployment (Windows)**

**Double-click:** `deploy-windows.ps1` 🖱️

Or from PowerShell:
```powershell
.\deploy-windows.ps1
```

---

### 🐧 **Option 3: Local Deployment (Linux/Mac/Git Bash)**

```bash
bash deploy-interactive.sh
```

**Requirements:** AWS CLI configured (`aws configure`)

---

## ✅ What This System Does

- **Complete License Plate Recognition** with color detection
- **Flask Backend** with OpenALPR (built from source)
- **Angular Frontend** with beautiful Material Design UI
- **RDS MySQL Database** for storing plate records
- **S3 Storage** for uploaded images
- **Production-Ready** AWS infrastructure (VPC, EC2, RDS, S3, IAM)

## 🎯 What Gets Deployed

- **VPC** with public/private subnets across 2 availability zones
- **EC2 t2.micro** running Flask + Angular + OpenALPR + nginx (FREE TIER eligible!)
- **RDS MySQL db.t2.micro** in private subnet (FREE TIER eligible!)
- **S3 Bucket** with versioning and CORS (FREE TIER included)
- **Security Groups** and IAM roles (least privilege)
- **Complete Application** with all features working

**Cost:** 🆓 **FREE for first 12 months!** (Then ~$15/month)  
**Deployment Time:** 20-30 minutes

---

## 📋 Interactive Deployment

The `deploy-interactive.sh` script guides you through:

1. ✅ **AWS CLI check** - Verifies or helps configure
2. ✅ **Region selection** - Choose where to deploy
3. ✅ **Key pair setup** - Uses existing or creates new
4. ✅ **Database password** - Secure password entry
5. ✅ **Security config** - Auto-detects your IP
6. ✅ **Confirmation** - Shows summary before deploying
7. ✅ **Automatic deployment** - Does everything!

### Example Run:
```
Which AWS region would you like to deploy to?
  1) eu-central-1 (Frankfurt) - Default
  2) us-east-1 (N. Virginia)
  3) us-west-2 (Oregon)
> 1

Found existing key pairs:
  1) my-key
  2) Create a new key pair
> 2

Enter a name for the new key pair:
> lpr-keypair

Enter database password (min 8 characters):
> ********

Auto-detect your IP address? (yes/no)
> yes

[Shows configuration summary]

Proceed with deployment? (yes/no)
> yes

[Deploys everything automatically!]
```

---

## 🌐 Access Your Application

After deployment completes, you'll see:
```
==========================================
Web Application URL: http://3.123.45.67
==========================================
```

Open this URL in your browser!

### Features Available:
- 📸 **Upload images** with license plates
- 🔍 **Automatic recognition** (plate + color)
- 💾 **Database storage** of all results
- 🔎 **Query interface** to search records
- ✏️ **Edit entries** directly in the UI

## 📋 What's Included
- **Backend**: Flask API with OpenALPR license plate recognition
- **Frontend**: Simple HTML interface for image upload
- **Infrastructure**: Complete AWS setup (EC2, S3, Security Groups)
- **Self-contained**: No external dependencies during deployment

## ⚡ Features
- **Drag & Drop**: Upload images through web interface
- **License Plate Recognition**: Uses OpenALPR for detection
- **S3 Storage**: Images stored in AWS S3
- **Real-time Results**: Immediate recognition results

## ✅ Clean up
```bash
aws cloudformation delete-stack --stack-name LicensePlateStack
```

## 🔧 Customization
- **Modify Code**: Edit files in `backend/` and `frontend/` directories
- **Redeploy**: Run deployment script again
- **Update**: Changes are embedded in the CloudFormation template

## 📌 Notes
- **OpenALPR Community** doesn't provide make/model/color detection
- **EC2 Instance**: t2.micro (free tier eligible)
- **Region**: eu-central-1 (modify in infra.yaml if needed)