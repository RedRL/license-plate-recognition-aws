#!/bin/bash
# Helper script to check deployment status

STACK_NAME="LicensePlateStack"
REGION="eu-central-1"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Checking Deployment Status"
echo "=========================================="
echo ""

# Check if stack exists
echo "Checking CloudFormation stack..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null)

if [ -z "$STACK_STATUS" ]; then
    echo -e "${RED}✗${NC} Stack not found"
    exit 1
else
    echo -e "${GREEN}✓${NC} Stack status: $STACK_STATUS"
fi

# Get EC2 IP
EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" \
    --output text)

echo -e "${GREEN}✓${NC} EC2 Public IP: $EC2_IP"

# Check if EC2 is reachable
echo ""
echo "Testing connectivity..."
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://${EC2_IP}/ | grep -q "200"; then
    echo -e "${GREEN}✓${NC} Web application is accessible"
else
    echo -e "${YELLOW}⚠${NC} Web application is not responding"
fi

# Get other outputs
S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text)

DB_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
    --output text)

echo ""
echo "=========================================="
echo "Deployment Information"
echo "=========================================="
echo ""
echo "Web App URL: http://${EC2_IP}"
echo "S3 Bucket: ${S3_BUCKET}"
echo "DB Endpoint: ${DB_ENDPOINT}"
echo ""


