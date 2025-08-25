Write-Host "Deploying License Plate Recognition System..."

# Define the key name to be used
$keyName = "LicensePlateKey"
$keyFile = "$keyName.pem"
$stackName = "LicensePlateStack"

# Check if key pair exists
Write-Host "Checking if key pair '$keyName' exists..."
$keyExists = $false
try {
    aws ec2 describe-key-pairs --key-names $keyName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $keyExists = $true
        Write-Host "Key pair '$keyName' already exists."
    }
}
catch {
    Write-Host "Key pair '$keyName' does not exist."
}

# Create key pair if it doesn't exist
if (-not $keyExists) {
    Write-Host "Creating new EC2 Key Pair: $keyName"
    aws ec2 create-key-pair --key-name $keyName --query 'KeyMaterial' --output text > $keyFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Key pair '$keyName' created successfully."
        Write-Host "Key saved to $keyFile"
    } else {
        Write-Host "Failed to create key pair. Exiting."
        exit 1
    }
}

# Check CloudFormation stack status
$stackStatus = ""
$stackExists = $false
try {
    $stackStatus = aws cloudformation describe-stacks --stack-name $stackName --query "Stacks[0].StackStatus" --output text 2>$null
    if ($stackStatus -and $stackStatus -ne "None" -and $stackStatus -ne "NONE") {
        $stackExists = $true
    } else {
        $stackExists = $false
    }
} catch {
    $stackStatus = "NONE"
    $stackExists = $false
    # Suppress error output
}

if ($stackExists -and $stackStatus -ne "NONE") {
    Write-Host "Stack '$stackName' already exists. Current status: $stackStatus."
    $response = Read-Host "Do you want to delete the stack and redeploy? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "Deleting stack '$stackName'..."
        aws cloudformation delete-stack --stack-name $stackName
        Write-Host "Waiting for stack deletion to complete..."
        while ($true) {
            Start-Sleep -Seconds 10
            try {
                $currentStatus = aws cloudformation describe-stacks --stack-name $stackName --query "Stacks[0].StackStatus" --output text
                Write-Host "Current stack status: $currentStatus (still deleting...)"
            } catch {
                Write-Host "Stack deleted. Proceeding with deployment."
                break
            }
        }
    } else {
        Write-Host "Aborting deployment. Please resolve the stack status manually."
        exit 1
    }
}

# Deploy the CloudFormation stack
Write-Host "Deploying CloudFormation stack..."
aws cloudformation deploy `
    --template-file infra.yaml `
    --stack-name $stackName `
    --parameter-overrides KeyName=$keyName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully!"
    
    # Get the EC2 public IP
    $publicIP = aws cloudformation describe-stacks --stack-name $stackName --query "Stacks[0].Outputs[?OutputKey=='EC2PublicIP'].OutputValue" --output text
    Write-Host "EC2 Public IP: $publicIP"
    
    Write-Host "`nWaiting for applications to start (this may take 5-10 minutes)..."
    Write-Host "Checking application status..."
    
    # Wait and check if applications are ready
    $maxAttempts = 30
    $attempt = 0
    $ready = $false
    
    while ($attempt -lt $maxAttempts -and -not $ready) {
        $attempt++
        Write-Host "Attempt $attempt/$maxAttempts - Checking if applications are ready..."
        
        try {
            # Check if frontend is responding
            $response = Invoke-WebRequest -Uri "http://$publicIP:4200" -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ Frontend is ready!"
                $ready = $true
            }
        }
        catch {
            Write-Host "⏳ Applications still starting... (attempt $attempt/$maxAttempts)"
            Start-Sleep -Seconds 20
        }
    }
    
    if ($ready) {
        Write-Host "`n🎉 Your License Plate Recognition System is ready!"
        Write-Host "Frontend: http://$publicIP:4200"
        Write-Host "Backend API: http://$publicIP:5000"
        Write-Host "`nYou can now upload images and test license plate recognition!"
    } else {
        Write-Host "`n⚠️  Applications may still be starting. Please wait a few more minutes and try:"
        Write-Host "Frontend: http://$publicIP:4200"
        Write-Host "Backend API: http://$publicIP:5000"
    }
} else {
    Write-Host "Deployment failed. Check the error messages above."
} 