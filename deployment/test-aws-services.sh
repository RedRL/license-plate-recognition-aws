#!/bin/bash
# Test AWS services connectivity

cd /opt/lpr-app

# Load environment variables
export $(cat .env | xargs)

echo "=== Testing RDS MySQL Connection ==="
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "SHOW TABLES;" 2>&1

if [ $? -eq 0 ]; then
    echo "✓ RDS MySQL connection successful"
    echo ""
    echo "=== Checking table schema ==="
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "DESCRIBE plates;" 2>&1
else
    echo "✗ RDS MySQL connection failed"
    echo ""
    echo "Attempting to initialize database..."
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" < /opt/lpr-app/deployment/init-db.sql 2>&1
fi

echo ""
echo "=== Testing S3 Access ==="
aws s3 ls "s3://$S3_BUCKET" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ S3 bucket accessible"
else
    echo "✗ S3 bucket not accessible"
    echo "Checking if bucket exists..."
    aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION" 2>&1
fi

echo ""
echo "=== Testing complete ==="

