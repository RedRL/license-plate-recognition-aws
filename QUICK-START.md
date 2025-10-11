# Quick Start Guide - AWS Deployment

## 🚀 Deploy in 3 Steps

### Step 1: Prerequisites

Ensure you have:
- AWS CLI installed and configured (`aws configure`)
- An EC2 key pair created in eu-central-1 region
- jq installed (for JSON processing)

### Step 2: Deploy

Run the deployment script:

```bash
# On Linux/Mac
chmod +x deploy-to-aws.sh
./deploy-to-aws.sh <KeyPairName> <DBPassword> [YourIP]

# On Windows (Git Bash or WSL)
bash deploy-to-aws.sh <KeyPairName> <DBPassword> [YourIP]
```

**Example:**
```bash
./deploy-to-aws.sh my-keypair MySecurePass123 203.0.113.0/32
```

### Step 3: Access Your App

After 15-20 minutes, the script will output:
```
Web Application URL: http://1.2.3.4
```

Open this URL in your browser!

---

## 📖 Full Documentation

See [DEPLOYMENT.md](DEPLOYMENT.md) for:
- Detailed deployment steps
- Architecture overview
- Troubleshooting guide
- Cost estimates
- Security best practices

---

## 🛠️ Helper Scripts

```bash
# Check deployment status
./deployment/check-deployment.sh

# Update application code
./deployment/update-app.sh <KeyPairName>

# Teardown everything
./deployment/teardown.sh
```

---

## 🎯 What Gets Deployed

- ✅ VPC with public/private subnets
- ✅ EC2 instance (t3.medium) with Flask + Angular + OpenALPR
- ✅ RDS MySQL database (db.t3.micro)
- ✅ S3 bucket for image storage
- ✅ Security groups and IAM roles
- ✅ Complete application stack

**Total time:** ~15-20 minutes
**Estimated cost:** ~$47/month

---

## 🔧 Troubleshooting

**Can't SSH?**
```bash
# Check security group allows your IP
aws ec2 describe-security-groups --filters "Name=group-name,Values=LPR-EC2-SG"
```

**App not accessible?**
```bash
# SSH into EC2 and check services
ssh -i ~/.ssh/<key>.pem ubuntu@<EC2-IP>
sudo systemctl status lpr-backend nginx
```

**Need help?**
- Read [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting
- Check CloudFormation console for stack events
- Review application logs on EC2

---

## 🧹 Cleanup

To remove everything:
```bash
./deployment/teardown.sh
```

**Warning:** This deletes all data permanently!

---

That's it! Your complete License Plate Recognition system is now running on AWS! 🎉


