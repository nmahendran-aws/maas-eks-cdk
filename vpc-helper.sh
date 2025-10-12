#!/bin/bash

# VPC Helper Script for EKS Blueprints
# This script helps you find existing VPCs and configure your EKS cluster

echo "=== VPC Helper for EKS Blueprints ==="
echo

# Function to list VPCs
list_vpcs() {
    echo "📋 Available VPCs in your account:"
    echo
    aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock,State]' --output table
    echo
}

# Function to get VPC details
get_vpc_details() {
    local vpc_id=$1
    if [ -z "$vpc_id" ]; then
        echo "❌ VPC ID is required"
        return 1
    fi
    
    echo "🔍 VPC Details for $vpc_id:"
    echo
    
    # VPC info
    aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock,State]' --output table
    echo
    
    # Subnets
    echo "📡 Subnets in this VPC:"
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' --output table
    echo
    
    # Internet Gateway
    echo "🌐 Internet Gateway:"
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].[InternetGatewayId,Tags[?Key==`Name`].Value|[0]]' --output table
    echo
    
    # NAT Gateways
    echo "🔀 NAT Gateways:"
    aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[*].[NatGatewayId,SubnetId,State]' --output table
    echo
}

# Function to check VPC requirements for EKS
check_vpc_for_eks() {
    local vpc_id=$1
    if [ -z "$vpc_id" ]; then
        echo "❌ VPC ID is required"
        return 1
    fi
    
    echo "✅ EKS Requirements Check for VPC: $vpc_id"
    echo
    
    # Check subnets
    local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text)
    local subnet_count=$(echo $subnets | wc -w)
    
    echo "📊 Subnet Analysis:"
    echo "   Total Subnets: $subnet_count"
    
    if [ $subnet_count -lt 2 ]; then
        echo "   ⚠️  WARNING: EKS requires at least 2 subnets in different AZs"
    else
        echo "   ✅ Subnet count OK"
    fi
    
    # Check AZs
    local azs=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].AvailabilityZone' --output text | sort -u)
    local az_count=$(echo $azs | wc -w)
    
    echo "   Availability Zones: $az_count ($azs)"
    
    if [ $az_count -lt 2 ]; then
        echo "   ⚠️  WARNING: EKS requires subnets in at least 2 different AZs"
    else
        echo "   ✅ AZ distribution OK"
    fi
    
    # Check for public subnets
    local public_subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=map-public-ip-on-launch,Values=true" --query 'Subnets[*].SubnetId' --output text)
    
    if [ -n "$public_subnets" ]; then
        echo "   ✅ Public subnets found: $public_subnets"
    else
        echo "   ⚠️  No public subnets found (will need NAT Gateway for internet access)"
    fi
    
    echo
}

# Main menu
case "${1:-menu}" in
    "list")
        list_vpcs
        ;;
    "details")
        if [ -z "$2" ]; then
            echo "Usage: $0 details <vpc-id>"
            echo "Example: $0 details vpc-12345678"
            exit 1
        fi
        get_vpc_details $2
        ;;
    "check")
        if [ -z "$2" ]; then
            echo "Usage: $0 check <vpc-id>"
            echo "Example: $0 check vpc-12345678"
            exit 1
        fi
        check_vpc_for_eks $2
        ;;
    "menu"|*)
        echo "🔧 VPC Helper Commands:"
        echo
        echo "1. List all VPCs:"
        echo "   $0 list"
        echo
        echo "2. Get VPC details:"
        echo "   $0 details <vpc-id>"
        echo "   Example: $0 details vpc-12345678"
        echo
        echo "3. Check VPC for EKS compatibility:"
        echo "   $0 check <vpc-id>"
        echo "   Example: $0 check vpc-12345678"
        echo
        echo "4. Update your CDK app to use existing VPC:"
        echo "   Edit bin/cdk-projects.ts and uncomment Option 1"
        echo "   Replace 'vpc-12345678' with your actual VPC ID"
        echo
        ;;
esac


