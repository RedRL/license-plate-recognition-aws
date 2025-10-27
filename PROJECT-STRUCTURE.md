# Project Structure

This document describes the project structure and file organization.

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
| `deployment/infra.yaml` | CloudFormation template - defines all AWS resources (EC2, RDS, S3, SQS, IAM) |

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
| `README.md` | **Main documentation** - quick start, deployment, usage |
| `COST_REPORT.md` | **Cost analysis** - AWS cost modeling and scaling analysis |
| `PROJECT-STRUCTURE.md` | This file - explains the project structure |

## 🎯 Simple Decision Tree

**Want to deploy to AWS for the first time?**
→ Run `deployment\deploy-aws.ps1` (Windows) or `deployment/deploy-aws.sh` (Linux/Mac)

**Already deployed and made frontend changes?**
→ Run `deployment\update-frontend.ps1`

**Need to update backend code?**
→ SSH to EC2 and run `sudo systemctl restart lpr-backend`

**Want to tear down everything?**
→ See "Cleanup / Teardown" section in README.md

## 📊 Quick Overview

The project uses a minimal deployment approach with just a few essential scripts:
- 3 deployment scripts for different scenarios
- Infrastructure as Code via CloudFormation
- Clean separation of backend, frontend, and deployment logic


