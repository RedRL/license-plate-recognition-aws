# Project Structure

This document describes the clean, consolidated file structure after cleanup.

## 🚀 Deployment Scripts (All in `deployment/` folder)

### **Main Deployment:**

| File | Purpose | Platform |
|------|---------|----------|
| `deployment/deploy-aws.sh` | **Main deployment script** - deploys everything to AWS | Linux/Mac/Git Bash |
| `deployment/deploy-aws.ps1` | **Windows wrapper** - launches deploy-aws.sh via Git Bash | Windows PowerShell |
| `deployment/update-frontend.ps1` | **Quick frontend updates** - faster than full redeployment | Windows PowerShell |

### **Infrastructure:**

| File | Purpose |
|------|---------|
| `deployment/infra.yaml` | CloudFormation template - defines all AWS resources (EC2, RDS, S3, IAM) |

### **Helper Scripts:**

| File | Purpose |
|------|---------|
| `deployment/provision-ec2.sh` | Installs OpenALPR, Python, Node.js on EC2 |
| `deployment/init-db.sql` | Database schema for RDS MySQL |

## 📁 Application Code

### **Backend (Flask API):**

```
backend/
├── app.py                              # Main Flask application
├── plate_service.py                    # OpenALPR integration
├── vehicle_attributes_service.py       # Vehicle color detection
└── requirements.txt                    # Python dependencies
```

### **Frontend (Angular):**

```
frontend/
├── src/
│   ├── app/
│   │   ├── components/
│   │   │   ├── home/                   # Home page
│   │   │   ├── upload-image/           # Image upload interface
│   │   │   └── query-db/               # Database query interface
│   │   ├── services/                   # API services
│   │   └── app.component.*             # Root component
│   ├── environments/                   # Environment configs
│   └── styles.scss                     # Global styles
├── package.json                        # Node dependencies
└── angular.json                        # Angular configuration
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| `README.md` | **Main documentation** - quick start, usage, troubleshooting |
| `PROJECT-STRUCTURE.md` | This file - explains the clean structure |

## 🗑️ What Was Removed

The following redundant files were deleted:

### Redundant Deployment Scripts:
- `deploy.sh`, `deploy.ps1`, `deploy.bat`
- `deploy-windows.ps1`
- `deploy-interactive.sh`
- `deploy-to-aws.sh`
- `deploy-complete.sh`, `deploy-complete.bat`, `deploy-complete.ps1`
- `complete-deploy.ps1`
- `deploy-cloudshell.sh`
- `finish-deploy.ps1`
- `fix-frontend.ps1`
- `build-and-deploy-frontend.ps1`

### Redundant Helper Scripts:
- `deployment/check-deployment.sh`
- `deployment/complete-deployment.sh`
- `deployment/quick-complete.sh`
- `deployment/update-app.sh`
- `deployment/test-aws-services.sh`
- `deployment/test-db-connection.py`
- `deployment/query-db.py`
- `deployment/verify-db.py`
- `deployment/teardown.sh`

### Redundant Documentation:
- `AWS-DEPLOYMENT-SUMMARY.md`
- `DEPLOYMENT.md`
- `INTERACTIVE-DEPLOYMENT.md`
- `WINDOWS-DEPLOYMENT.md`
- `ZERO-SETUP-DEPLOYMENT.md`
- `START-HERE.md`
- `QUICK-START.md`
- `FINISH-DEPLOYMENT-MANUAL.md`

### Other:
- `deployment-progress.log`

## 🎯 Simple Decision Tree

**Want to deploy to AWS for the first time?**
→ Run `deployment\deploy-aws.ps1` (Windows) or `deployment/deploy-aws.sh` (Linux/Mac)

**Already deployed and made frontend changes?**
→ Run `deployment\update-frontend.ps1`

**Need to update backend code?**
→ SSH to EC2 and run `sudo systemctl restart lpr-backend`

**Want to tear down everything?**
→ See "Cleanup / Teardown" section in README.md

## 📊 File Count Comparison

**Before cleanup:** 25+ deployment scripts and docs
**After cleanup:** 3 deployment scripts + 1 README

**Result:** Much cleaner, easier to understand! 🎉


