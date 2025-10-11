# Windows Deployment Guide

## 🪟 Three Ways to Deploy on Windows

Choose the method that works best for you:

---

## ✨ Method 1: PowerShell (Recommended)

Right-click `deploy-windows.ps1` → **Run with PowerShell**

Or from PowerShell:
```powershell
.\deploy-windows.ps1
```

**If you get "execution policy" error:**
```powershell
# Run this first (one-time only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then run the deployment
.\deploy-windows.ps1
```

---

## 🖱️ Method 2: Batch File

Double-click `deploy.bat` in Windows Explorer

**Note:** If this gives a WSL error, use Method 1 or 3 instead.

---

## 💻 Method 3: Git Bash Directly

1. Right-click in the project folder
2. Select **"Git Bash Here"**
3. Run:
   ```bash
   bash deploy-interactive.sh
   ```

Or from Git Bash:
```bash
cd /c/Users/YourName/path/to/license-plate-recognition-aws
bash deploy-interactive.sh
```

---

## 🔧 Troubleshooting

### "bash.exe not found" or WSL errors

**Problem:** The batch file is finding WSL bash instead of Git Bash

**Solutions:**
1. ✅ **Use Method 1** (PowerShell) - Recommended!
2. ✅ **Use Method 3** (Git Bash directly)
3. Install Git for Windows: https://git-scm.com/download/win

---

### "Execution policy" error (PowerShell)

**Problem:** PowerShell won't run scripts by default

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run `.\deploy-windows.ps1` again.

---

### "Git Bash not found"

**Problem:** Git for Windows is not installed

**Solution:**
1. Download from: https://git-scm.com/download/win
2. Install with default options
3. Run the deployment script again

---

## 📋 What Happens Next

After running any method, the script will:

1. ✅ Check AWS CLI is configured
2. ✅ Ask which region to deploy to
3. ✅ Help you create or select EC2 key pair
4. ✅ Ask for database password
5. ✅ Auto-detect your IP for security
6. ✅ Show deployment summary
7. ✅ Deploy everything to AWS!

**Time:** 15-20 minutes  
**Cost:** ~$47/month

---

## 🎯 Quick Comparison

| Method | Ease | Requirements |
|--------|------|--------------|
| **PowerShell** ✅ | Easiest | Git Bash installed |
| **Batch File** | Easy | Git Bash installed, no WSL conflicts |
| **Git Bash** | Easy | Git Bash installed |

**Recommendation:** Use PowerShell (Method 1) - most reliable on Windows!

---

## 📖 After Deployment

You'll see:
```
==========================================
Web Application URL: http://3.123.45.67
==========================================
```

Open this in your browser and start using your License Plate Recognition system! 🚗🔍

---

## 🆘 Still Having Issues?

1. **Check Prerequisites:**
   ```powershell
   # AWS CLI installed?
   aws --version
   
   # AWS configured?
   aws sts get-caller-identity
   ```

2. **Manual Deployment:**
   If all else fails, open Git Bash manually and run:
   ```bash
   bash deploy-interactive.sh
   ```

3. **Get Help:**
   - Read `DEPLOYMENT.md` for detailed guide
   - Check `INTERACTIVE-DEPLOYMENT.md` for script details
   - Review AWS CLI setup: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

---

## ✅ Summary

**Easiest way on Windows:**
1. Right-click `deploy-windows.ps1`
2. Select "Run with PowerShell"
3. Answer the questions
4. Done! 🎉

If you get an execution policy error, run this first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then try again!


