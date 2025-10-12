#!/bin/bash

# AWS Environment Setup Script
# This script helps you set up AWS account and region environment variables

echo "=== AWS Environment Setup ==="
echo

# Method 1: Get account from AWS CLI
echo "1. Getting AWS Account ID from AWS CLI..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$AWS_ACCOUNT_ID" ]; then
    echo "✅ Found AWS Account ID: $AWS_ACCOUNT_ID"
else
    echo "❌ Could not get AWS Account ID. Make sure AWS CLI is configured."
    echo "Run: aws configure"
    read -p "Enter your AWS Account ID manually: " AWS_ACCOUNT_ID
fi

# Method 2: Get region from AWS CLI
echo
echo "2. Getting AWS Region from AWS CLI..."
AWS_REGION=$(aws configure get region 2>/dev/null)

if [ ! -z "$AWS_REGION" ]; then
    echo "✅ Found AWS Region: $AWS_REGION"
else
    echo "❌ Could not get AWS Region. Make sure AWS CLI is configured."
    read -p "Enter your AWS Region (e.g., us-east-1): " AWS_REGION
fi

echo
echo "3. Setting environment variables..."

# Set environment variables for current session
export CDK_DEFAULT_ACCOUNT=$AWS_ACCOUNT_ID
export CDK_DEFAULT_REGION=$AWS_REGION

echo "✅ Environment variables set for current session:"
echo "   CDK_DEFAULT_ACCOUNT=$CDK_DEFAULT_ACCOUNT"
echo "   CDK_DEFAULT_REGION=$CDK_DEFAULT_REGION"

echo
echo "4. Creating .env file..."
cat > .env << EOF
# AWS Configuration
CDK_DEFAULT_ACCOUNT=$AWS_ACCOUNT_ID
CDK_DEFAULT_REGION=$AWS_REGION

# Alternative names (also supported)
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_DEFAULT_REGION=$AWS_REGION
EOF

echo "✅ Created .env file with your AWS configuration"

echo
echo "5. To use these variables in your shell:"
echo "   source .env"
echo "   # or"
echo "   export CDK_DEFAULT_ACCOUNT=$AWS_ACCOUNT_ID"
echo "   export CDK_DEFAULT_REGION=$AWS_REGION"

echo
echo "6. To verify your setup:"
echo "   aws sts get-caller-identity"
echo "   cdk list"
