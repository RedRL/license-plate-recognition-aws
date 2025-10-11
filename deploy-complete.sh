#!/bin/bash
# Complete Local Deployment Script with Full Setup
# Handles everything: IAM user creation, credentials, deployment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STACK_NAME="LicensePlateStack"
REGION="eu-central-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}========================================${NC}\n${BLUE}$1${NC}\n${BLUE}========================================${NC}\n"; }
log_question() { echo -e "${CYAN}[?]${NC} $1"; }

# Welcome
clear
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     License Plate Recognition - Complete AWS Setup           ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

log_info "This script will set up everything needed for deployment"
echo ""

# Step 1: Check AWS CLI
log_step "Step 1: Checking AWS CLI"

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed!"
    echo ""
    echo "To install AWS CLI:"
    echo ""
    echo "  Windows:"
    echo "    1. Download: https://awscli.amazonaws.com/AWSCLIV2.msi"
    echo "    2. Run the installer"
    echo "    3. Restart your terminal"
    echo ""
    echo "  Linux:"
    echo "    curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "    unzip awscliv2.zip"
    echo "    sudo ./aws/install"
    echo ""
    echo "  Mac:"
    echo "    brew install awscli"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

log_info "AWS CLI is installed: $(aws --version)"

# Step 2: Check AWS Credentials
log_step "Step 2: AWS Credentials"

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured!"
    echo ""
    echo "You need to configure AWS credentials. You have two options:"
    echo ""
    echo "Option 1: Use root account credentials (not recommended for production)"
    echo "  1. Login to AWS Console as root"
    echo "  2. Go to: IAM → Users → Create User → 'lpr-admin'"
    echo "  3. Attach policy: AdministratorAccess"
    echo "  4. Create access key"
    echo "  5. Copy Access Key ID and Secret Access Key"
    echo ""
    echo "Option 2: Use existing IAM user with admin permissions"
    echo ""
    log_question "Would you like to configure AWS credentials now? (yes/no)"
    read -p "> " configure_now
    
    if [ "$configure_now" = "yes" ] || [ "$configure_now" = "y" ]; then
        echo ""
        log_info "Running 'aws configure'..."
        echo ""
        echo "You'll need:"
        echo "  - AWS Access Key ID"
        echo "  - AWS Secret Access Key"
        echo "  - Default region: $REGION"
        echo "  - Default output format: json"
        echo ""
        aws configure
        
        if ! aws sts get-caller-identity &> /dev/null; then
            log_error "Credentials still not working. Please check and try again."
            exit 1
        fi
        
        log_info "Credentials configured successfully! ✓"
    else
        echo ""
        log_error "Cannot proceed without AWS credentials."
        echo "Please run 'aws configure' manually, then run this script again."
        exit 1
    fi
fi

# Get current identity
CALLER_IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
CALLER_ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
CURRENT_USER=$(echo "$CALLER_ARN" | awk -F'/' '{print $NF}')

log_info "Currently using AWS credentials:"
log_info "  Account ID: $ACCOUNT_ID"
log_info "  User/Role: $CURRENT_USER"
log_info "  ARN: $CALLER_ARN"

# Step 3: Check if this is an existing IAM user from another project
log_step "Step 3: IAM User Setup"

if [[ "$CALLER_ARN" == *":user/"* ]]; then
    # It's an IAM user
    
    # Check if current user has AdministratorAccess
    HAS_ADMIN=$(aws iam list-attached-user-policies --user-name "$CURRENT_USER" --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" --output text 2>/dev/null || echo "")
    
    if [ -n "$HAS_ADMIN" ]; then
        log_info "Using IAM user: $CURRENT_USER (has Administrator permissions) ✓"
        log_info "This user has all necessary permissions for deployment"
        IAM_USER="$CURRENT_USER"
    else
        # Current user doesn't have admin - search for one that does
        log_warn "Current user '$CURRENT_USER' lacks Administrator permissions"
        log_info "Searching for users with Administrator access..."
        
        # List all IAM users
        ALL_USERS=$(aws iam list-users --query 'Users[*].UserName' --output text 2>/dev/null || echo "")
        
        ADMIN_USER=""
        if [ -n "$ALL_USERS" ]; then
            for user in $ALL_USERS; do
                USER_HAS_ADMIN=$(aws iam list-attached-user-policies --user-name "$user" --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" --output text 2>/dev/null || echo "")
                if [ -n "$USER_HAS_ADMIN" ]; then
                    ADMIN_USER="$user"
                    break
                fi
            done
        fi
        
        if [ -n "$ADMIN_USER" ]; then
            log_info "Found user with admin permissions: $ADMIN_USER ✓"
            log_warn "Current credentials are for '$CURRENT_USER' which lacks permissions"
            echo ""
            log_question "Would you like to switch to '$ADMIN_USER' automatically? (yes/no)"
            read -p "> " switch_user
            
            if [ "$switch_user" = "yes" ] || [ "$switch_user" = "y" ]; then
                log_info "Switching to '$ADMIN_USER' credentials..."
                echo ""
                log_info "You'll need the Access Key ID and Secret Access Key for: $ADMIN_USER"
                log_info "You can find these in AWS Console → IAM → Users → $ADMIN_USER → Security Credentials"
                echo ""
                
                # Run aws configure
                aws configure
                
                # Verify the new credentials work
                NEW_CALLER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "")
                NEW_USER=$(echo "$NEW_CALLER" | awk -F'/' '{print $NF}')
                
                if [ "$NEW_USER" = "$ADMIN_USER" ]; then
                    log_info "Successfully switched to: $ADMIN_USER ✓"
                    log_info "Continuing with deployment..."
                    IAM_USER="$ADMIN_USER"
                    
                    # Re-check admin permissions
                    HAS_ADMIN=$(aws iam list-attached-user-policies --user-name "$NEW_USER" --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" --output text 2>/dev/null || echo "")
                    
                    if [ -z "$HAS_ADMIN" ]; then
                        log_error "User $NEW_USER doesn't have Administrator permissions!"
                        exit 1
                    fi
                else
                    log_error "Failed to switch to $ADMIN_USER (current user: $NEW_USER)"
                    log_error "Please verify credentials and try again"
                    exit 1
                fi
            else
                log_error "Cannot proceed without Administrator permissions"
                exit 1
            fi
        else
            log_warn "No users with Administrator access found"
            log_question "Would you like to create a new admin user for this project? (yes/no)"
            read -p "> " create_new
            
            if [ "$create_new" != "yes" ] && [ "$create_new" != "y" ]; then
                log_error "Cannot proceed without Administrator permissions"
                exit 1
            fi
            
            # Try to create with current permissions (might work if user has IAM permissions)
            NEW_USER="lpr-deployer"
            log_info "Attempting to create admin user: $NEW_USER"
        fi
    fi
    
    # Only continue with user choice if we didn't handle it above
    if [ -z "$IAM_USER" ]; then
        # It's a different user without admin
        log_warn "You're using an existing IAM user: $CURRENT_USER"
        echo ""
        log_question "This user might be from another project. Would you like to:"
        echo "  1) Continue using this user ($CURRENT_USER)"
        echo "  2) Create a new dedicated IAM user for this project (lpr-deployer)"
        echo "  3) Cancel and configure different credentials"
        read -p "Enter choice [1-3] (default: 1): " user_choice
    
    case $user_choice in
        1)
            log_info "Continuing with existing user: $CURRENT_USER"
            IAM_USER=$CURRENT_USER
            ;;
        3)
            log_info "Please run 'aws configure' to set up different credentials, then run this script again."
            exit 0
            ;;
        *)
            # Option 2 or default: Create new user
            NEW_USER="lpr-deployer"
            log_info "Creating new dedicated IAM user: $NEW_USER"
            
            # Check if user already exists
            if aws iam get-user --user-name "$NEW_USER" &> /dev/null; then
                log_warn "User $NEW_USER already exists."
                log_question "Do you want to use the existing user? (yes/no)"
                read -p "> " use_existing
                
                if [ "$use_existing" != "yes" ] && [ "$use_existing" != "y" ]; then
                    log_error "Please choose a different username or delete the existing user."
                    exit 1
                fi
                
                log_info "Using existing user: $NEW_USER"
            else
                # Create new IAM user
                log_info "Creating IAM user..."
                aws iam create-user --user-name "$NEW_USER" > /dev/null
                
                # Attach necessary policies
                log_info "Attaching policies..."
                
                # AdministratorAccess - full permissions for deployment
                aws iam attach-user-policy --user-name "$NEW_USER" \
                    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
                
                log_info "User created with Administrator permissions ✓"
            fi
            
            # Check if user already has access keys
            EXISTING_KEYS=$(aws iam list-access-keys --user-name "$NEW_USER" --query 'AccessKeyMetadata[*].AccessKeyId' --output text)
            
            if [ -n "$EXISTING_KEYS" ]; then
                log_warn "User $NEW_USER already has access keys."
                log_question "Do you want to create new access keys? (This will require updating credentials) (yes/no)"
                read -p "> " create_new_keys
                
                if [ "$create_new_keys" = "yes" ] || [ "$create_new_keys" = "y" ]; then
                    # Delete old keys
                    for key in $EXISTING_KEYS; do
                        aws iam delete-access-key --user-name "$NEW_USER" --access-key-id "$key"
                    done
                    CREATE_KEYS=true
                else
                    log_info "Using existing access keys for $NEW_USER"
                    log_warn "Make sure these are configured in 'aws configure'"
                    CREATE_KEYS=false
                fi
            else
                CREATE_KEYS=true
            fi
            
            if [ "$CREATE_KEYS" = true ]; then
                # Create access keys
                log_info "Creating access keys..."
                KEY_OUTPUT=$(aws iam create-access-key --user-name "$NEW_USER")
                
                NEW_ACCESS_KEY=$(echo "$KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*"' | cut -d'"' -f4)
                NEW_SECRET_KEY=$(echo "$KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*"' | cut -d'"' -f4)
                
                echo ""
                log_warn "IMPORTANT: Save these credentials!"
                echo ""
                echo "  Access Key ID:     $NEW_ACCESS_KEY"
                echo "  Secret Access Key: $NEW_SECRET_KEY"
                echo ""
                log_question "Would you like to configure these credentials now? (yes/no)"
                read -p "> " configure_new
                
                if [ "$configure_new" = "yes" ] || [ "$configure_new" = "y" ]; then
                    # Save current profile
                    log_info "Configuring new credentials..."
                    
                    # Configure as default
                    aws configure set aws_access_key_id "$NEW_ACCESS_KEY"
                    aws configure set aws_secret_access_key "$NEW_SECRET_KEY"
                    aws configure set region "$REGION"
                    aws configure set output json
                    
                    log_info "New credentials configured! ✓"
                    
                    # Verify new credentials work
                    sleep 2  # Wait for AWS to propagate
                    if aws sts get-caller-identity &> /dev/null; then
                        log_info "New credentials verified! ✓"
                    else
                        log_warn "New credentials might take a few seconds to propagate..."
                        sleep 5
                    fi
                else
                    echo ""
                    log_warn "Please save the credentials above and run:"
                    echo "  aws configure"
                    echo "Then run this script again."
                    exit 0
                fi
            fi
            
            IAM_USER=$NEW_USER
            ;;
    esac
    fi
else
    # Not an IAM user (could be root or role)
    log_warn "You're not using an IAM user (might be root account or role)"
    echo ""
    log_question "Would you like to create a dedicated IAM user for this project? (recommended) (yes/no)"
    read -p "> " create_user
    
    if [ "$create_user" = "yes" ] || [ "$create_user" = "y" ]; then
        NEW_USER="lpr-deployer"
        
        # Same logic as above for creating user
        if aws iam get-user --user-name "$NEW_USER" &> /dev/null; then
            log_info "User $NEW_USER already exists, using it."
        else
            log_info "Creating IAM user: $NEW_USER"
            aws iam create-user --user-name "$NEW_USER" > /dev/null
            aws iam attach-user-policy --user-name "$NEW_USER" \
                --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
            aws iam attach-user-policy --user-name "$NEW_USER" \
                --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess
        fi
        
        log_info "Creating access keys..."
        KEY_OUTPUT=$(aws iam create-access-key --user-name "$NEW_USER")
        
        NEW_ACCESS_KEY=$(echo "$KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*"' | cut -d'"' -f4)
        NEW_SECRET_KEY=$(echo "$KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*"' | cut -d'"' -f4)
        
        echo ""
        echo "  Access Key ID:     $NEW_ACCESS_KEY"
        echo "  Secret Access Key: $NEW_SECRET_KEY"
        echo ""
        echo "Please save these and configure:"
        echo "  aws configure"
        echo ""
        echo "Then run this script again."
        exit 0
    else
        log_info "Continuing with current credentials"
        IAM_USER="current-user"
    fi
fi

# Continue with deployment
log_step "Starting Deployment"

log_info "All prerequisites met! Starting deployment..."
echo ""

# Call the main deployment script
bash "${SCRIPT_DIR}/deploy-interactive.sh"

exit $?

