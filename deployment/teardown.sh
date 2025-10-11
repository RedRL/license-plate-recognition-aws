#!/bin/bash
# Helper script to tear down the AWS deployment

STACK_NAME="LicensePlateStack"
REGION="eu-central-1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "AWS Deployment Teardown"
echo "=========================================="
echo ""
echo -e "${YELLOW}WARNING: This will delete all AWS resources!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled"
    exit 0
fi

echo ""
echo "Step 1: Getting S3 bucket name..."
S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text 2>/dev/null)

if [ -n "$S3_BUCKET" ]; then
    echo "Step 2: Emptying S3 bucket ($S3_BUCKET)..."
    aws s3 rm s3://${S3_BUCKET} --recursive --region "$REGION"
    echo -e "${GREEN}✓${NC} S3 bucket emptied"
else
    echo "S3 bucket not found, skipping..."
fi

echo ""
echo "Step 3: Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Stack deleted successfully"
    echo ""
    echo "=========================================="
    echo "Teardown Complete"
    echo "=========================================="
else
    echo -e "${RED}✗${NC} Stack deletion failed"
    echo "Check the CloudFormation console for details"
    exit 1
fi


