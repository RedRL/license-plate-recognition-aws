# License Plate Recognition System - AWS Deployment

A complete license plate recognition system deployed on AWS, featuring automatic plate detection using OpenALPR, vehicle attribute recognition, and a modern Angular frontend.

## 🚀 Quick Start

### Prerequisites
- AWS Account
- AWS CLI installed and configured (`aws configure`)
- Git Bash (Windows) or Bash shell (Linux/Mac)

### Deploy to AWS

**Windows:**
```powershell
.\deployment\deploy-aws.ps1
```

**Linux/Mac:**
```bash
chmod +x deployment/deploy-aws.sh
./deployment/deploy-aws.sh
```

That's it! The script will:
- ✅ Create all AWS infrastructure (EC2, RDS, S3)
- ✅ Install and configure OpenALPR
- ✅ Deploy backend (Flask API)
- ✅ Build and deploy frontend (Angular)
- ✅ Initialize database
- ✅ Configure nginx
- ✅ Set up systemd services

**Deployment time:** ~10-15 minutes

After deployment, your application will be live at: `http://[EC2-IP-ADDRESS]`

---

## 📁 Project Structure

```
license-plate-recognition-aws/
├── backend/
│   ├── app.py                 # Flask API server
│   ├── plate_service.py       # OpenALPR integration
│   ├── vehicle_attributes_service.py  # Vehicle color detection
│   └── requirements.txt       # Python dependencies
├── frontend/
│   ├── src/                   # Angular application
│   ├── package.json           # Node dependencies
│   └── angular.json           # Angular configuration
└── deployment/
    ├── deploy-aws.sh          # Main deployment script (Bash)
    ├── deploy-aws.ps1         # Windows wrapper (PowerShell)
    ├── update-frontend.ps1    # Quick frontend update script
    ├── infra.yaml             # CloudFormation template
    ├── provision-ec2.sh       # EC2 setup (OpenALPR, Python, Node)
    └── init-db.sql            # Database schema
```

---

## 🏗️ AWS Infrastructure

The deployment creates:

### **EC2 Instance (t3.micro - Free Tier)**
- Ubuntu 22.04 LTS
- OpenALPR for license plate recognition
- Flask backend API
- Angular frontend served by nginx
- Automatic startup via systemd

### **RDS MySQL (db.t3.micro - Free Tier)**
- Stores license plate data
- Automatic backups disabled (free tier)
- Database: `license_plates_db`
- Table: `plates`

### **S3 Bucket**
- Stores uploaded images
- Automatic cleanup not configured

### **Security Groups**
- SSH access restricted to your IP
- HTTP (port 80) open to world
- RDS accessible only from EC2

### **IAM Role**
- EC2 instance role with S3 and RDS access

---

## 💻 Using the Application

### Upload Images
1. Navigate to "Upload Image" in the menu
2. Drag & drop or click to select an image
3. System automatically:
   - Detects license plate using OpenALPR
   - Identifies vehicle color
   - Saves to RDS database
   - Stores image in S3

### Query Database
1. Navigate to "Query Database" in the menu
2. Filter by:
   - License plate number
   - Color
   - Make
   - Model
   - Date/time
3. Edit records inline by clicking the edit icon
4. Changes save automatically to RDS

---

## 🔄 Updating After Deployment

### Update Frontend Only (Faster)
After making frontend changes:

```powershell
.\deployment\update-frontend.ps1
```

This builds locally and deploys to EC2 (takes ~2 minutes).

### Update Backend
SSH into EC2 and restart:

```bash
ssh -i lpr-keypair.pem ubuntu@[EC2-IP]
cd /opt/lpr-app/backend
sudo systemctl restart lpr-backend
```

### Full Redeployment
Re-run the deployment script. It will update the existing stack.

---

## 🔧 Configuration

### Environment Variables
Located at `/opt/lpr-app/.env` on EC2:

```bash
AWS_REGION=eu-central-1
S3_BUCKET=[auto-generated]
DB_HOST=[rds-endpoint]
DB_USER=admin
DB_PASSWORD=[auto-generated]
LOCAL_MODE=false          # Set to true for local SQLite instead of RDS
ALPR_COUNTRY=eu           # OpenALPR country code (us, eu, au, etc.)
```

### Database Access
Connection details saved in `aws-credentials.txt` after deployment.

To connect from EC2:
```bash
mysql -h [DB_ENDPOINT] -u admin -p[PASSWORD] license_plates_db
```

---

## 🧹 Cleanup / Teardown

To delete all AWS resources:

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name LicensePlateStack --region eu-central-1

# Delete S3 bucket (must be empty first)
aws s3 rm s3://[BUCKET-NAME] --recursive
aws s3 rb s3://[BUCKET-NAME]

# Delete EC2 key pair
aws ec2 delete-key-pair --key-name lpr-keypair --region eu-central-1
rm lpr-keypair.pem
```

---

## 💰 Cost Estimate

Using AWS Free Tier:
- **EC2 t3.micro**: Free for first 12 months (750 hours/month)
- **RDS db.t3.micro**: Free for first 12 months (750 hours/month)
- **S3 Storage**: First 5GB free
- **Data Transfer**: First 100GB free

**After free tier expires:** ~$15-20/month if running 24/7

**Cost saving tip:** Stop EC2 and RDS when not in use (no charges when stopped).

---

## 🐛 Troubleshooting

### Deployment fails with "Stack in ROLLBACK_COMPLETE"
The script automatically handles this. If it persists, manually delete the stack:
```bash
aws cloudformation delete-stack --stack-name LicensePlateStack --region eu-central-1
```

### Cannot connect to EC2
- Check security group allows your IP
- Verify key pair file permissions: `chmod 400 lpr-keypair.pem`
- Your IP might have changed (update security group)

### Frontend returns 500 errors
Check backend logs on EC2:
```bash
ssh -i lpr-keypair.pem ubuntu@[EC2-IP]
tail -50 /opt/lpr-app/backend/logs/app.log
```

### Database connection errors
- Verify RDS is running in AWS Console
- Check password in `/opt/lpr-app/.env`
- Ensure security group allows EC2 -> RDS connection

### OpenALPR not detecting plates
- Works best with clear, front-facing plate images
- Supports multiple countries (set `ALPR_COUNTRY` in `.env`)
- Detection accuracy varies by image quality

---

## 🔐 Security Notes

- **SSH Key**: Stored as `lpr-keypair.pem` - **Keep this secure!**
- **DB Password**: Auto-generated, saved in `aws-credentials.txt`
- **S3 Bucket**: Not publicly accessible (IAM role-based access)
- **RDS**: Not publicly accessible (VPC-only)
- **HTTP Only**: Consider adding HTTPS with Let's Encrypt for production

---

## 📚 Technologies Used

- **Backend**: Python 3, Flask, OpenALPR, PyMySQL, Boto3
- **Frontend**: Angular 19, Angular Material, TypeScript
- **Database**: MySQL 8.0 (RDS)
- **Storage**: Amazon S3
- **Compute**: EC2 Ubuntu 22.04
- **Web Server**: nginx
- **Infrastructure**: AWS CloudFormation

---

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

## 🤝 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudFormation stack events in AWS Console
3. Check application logs on EC2

---

**Enjoy your AWS-powered License Plate Recognition system!** 🚗📸
