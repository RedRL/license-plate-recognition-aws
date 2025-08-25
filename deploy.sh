#!/bin/bash
echo "Deploying License Plate Recognition System..."
aws cloudformation deploy   --template-file infra.yaml   --stack-name LicensePlateStack   --parameter-overrides KeyName=$1
