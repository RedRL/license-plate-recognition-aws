#!/bin/bash
# CloudShell Deployment Script - Zero Local Setup Required!
# Just open AWS CloudShell and run this script!

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   License Plate Recognition - CloudShell Deployment          ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${GREEN}[INFO]${NC} Running in AWS CloudShell - Zero setup required!"
echo -e "${GREEN}[INFO]${NC} All AWS credentials and tools are pre-configured ✓"
echo ""

# Detect CloudShell
if [ -n "$AWS_EXECUTION_ENV" ] || [ -d "/home/cloudshell-user" ]; then
    echo -e "${GREEN}[INFO]${NC} AWS CloudShell detected ✓"
    IS_CLOUDSHELL=true
else
    echo -e "${CYAN}[INFO]${NC} Not running in CloudShell, but that's OK!"
    IS_CLOUDSHELL=false
fi

# Call the interactive script (which is now fully automated)
echo -e "${GREEN}[INFO]${NC} Starting automated deployment..."
echo ""

bash "$(dirname "$0")/deploy-interactive.sh"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║              🎉 Deployment Successful! 🎉                     ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}[INFO]${NC} Your License Plate Recognition app is now live!"
    echo -e "${GREEN}[INFO]${NC} Check the output above for the application URL"
    echo ""
    
    if [ "$IS_CLOUDSHELL" = true ]; then
        echo -e "${CYAN}[TIP]${NC} You can close CloudShell now - everything is running on AWS!"
        echo -e "${CYAN}[TIP]${NC} Your app will keep running even if you close your browser"
    fi
else
    echo ""
    echo -e "\033[0;31m[ERROR]\033[0m Deployment failed. Check the errors above."
    exit 1
fi


