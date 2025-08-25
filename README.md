# License Plate Recognition System — Automated Cloud Deploy

## ✅ What it does
- Creates S3 bucket for storing license plate images
- Spins up EC2 running:
  - Flask backend with OpenALPR for license plate recognition
  - Simple HTML frontend for image upload
- Self-contained deployment (no external GitHub dependency)

## 🚀 Quick Deploy (Any User)

### Prerequisites
1. **AWS CLI installed and configured**
2. **AWS credentials with EC2, S3, CloudFormation permissions**

### Deploy Steps
```bash
# 1. Clone this repository
git clone https://github.com/YOUR_USERNAME/LicensePlateRecognitionProject.git
cd LicensePlateRecognitionProject

# 2. Run deployment script
# On Windows:
.\deploy.ps1

# On Linux/macOS:
chmod +x deploy.sh
./deploy.sh
```

### What Happens
1. **Creates EC2 Key Pair** (if it doesn't exist)
2. **Deploys CloudFormation Stack** with:
   - S3 bucket for images
   - EC2 instance with all dependencies
   - Security groups for access
3. **Installs and starts applications** automatically

## 🌐 Access Your Application
After deployment (5-10 minutes):
- **Frontend**: http://[EC2_PUBLIC_IP]:4200
- **Backend API**: http://[EC2_PUBLIC_IP]:5000

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