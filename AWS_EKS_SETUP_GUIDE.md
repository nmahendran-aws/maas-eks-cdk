# AWS Account Connection & EKS Cluster Setup Guide

This guide will walk you through connecting to your AWS account and deploying an EKS cluster using AWS CDK with EKS Blueprints.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Node.js and npm installed
- Docker (for container builds if needed)

## Step 1: AWS Account Setup & Credentials

### 1.1 Install AWS CLI (if not already installed)

```bash
# macOS
brew install awscli

# Or download from AWS website
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 1.2 Configure AWS CLI

```bash
# Configure with your AWS credentials
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your access key from AWS IAM
- **AWS Secret Access Key**: Your secret key from AWS IAM  
- **Default region name**: e.g., `us-east-1`, `us-west-2`, `eu-west-1`
- **Default output format**: `json` (recommended)

### 1.3 Verify AWS Configuration

```bash
# Check your current configuration
aws sts get-caller-identity

# This should return your account ID, user ARN, and user ID
```

### 1.4 Set CDK Environment Variables

```bash
# Set environment variables for CDK
export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CDK_DEFAULT_REGION=$(aws configure get region)

# Verify the variables are set
echo "Account: $CDK_DEFAULT_ACCOUNT"
echo "Region: $CDK_DEFAULT_REGION"
```

## Step 2: Required AWS Permissions

Your AWS user/role needs the following permissions for EKS cluster creation:

### Minimum Required Policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonElasticLoadBalancingFullAccess`
- `AmazonRoute53FullAccess`
- `IAMFullAccess`

### IAM Permissions for CDK:
- `CloudFormationFullAccess`
- `IAMFullAccess`
- `AmazonEC2FullAccess`
- `AmazonVPCFullAccess`
- `AmazonEKSFullAccess`

## Step 3: Bootstrap CDK (First Time Only)

```bash
# Bootstrap CDK in your AWS account and region
cdk bootstrap

# This creates the necessary S3 bucket and IAM roles for CDK deployments
```

## Step 4: Understanding the EKS Blueprint Code

### Your Current Implementation:

```typescript
// lib/cdk-projects-stack.ts
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as blueprints from '@aws-quickstart/eks-blueprints';

export class CdkProjectsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Extract account and region from stack properties
    const account = props?.env?.account!;
    const region = props?.env?.region!;
    
    // Create EKS Blueprint with common add-ons
    blueprints.EksBlueprint.builder()
      .account(account)                    // Your AWS Account ID
      .region(region)                      // Your AWS Region
      .clusterProvider(new blueprints.GenericClusterProvider({ 
        version: 'auto'                    // Use latest EKS version
      }))
      .addOns(
        // Core add-ons (required for basic functionality)
        new blueprints.addons.CoreDnsAddOn(),
        new blueprints.addons.KubeProxyAddOn(),
        new blueprints.addons.VpcCniAddOn(),
        
        // Optional but recommended add-ons
        new blueprints.addons.MetricsServerAddOn(),
        new blueprints.addons.ClusterAutoScalerAddOn(),
        new blueprints.addons.AwsLoadBalancerControllerAddOn(),
        new blueprints.addons.ContainerInsightsAddOn()
      )
      .teams() // You can add teams here if needed
      .build(scope, id + "-eks-cluster");
  }
}
```

### Key Components Explained:

1. **EksBlueprint.builder()**: Creates the main blueprint builder
2. **account() & region()**: Specifies where to deploy
3. **clusterProvider()**: Defines cluster configuration (version, node groups, etc.)
4. **addOns()**: Adds Kubernetes add-ons to your cluster
5. **teams()**: Defines user teams with different access levels
6. **build()**: Creates the actual CDK stack

## Step 5: Deploy Your EKS Cluster

### 5.1 Synthesize the Template (Optional)

```bash
# Generate CloudFormation template without deploying
npm run build
cdk synth
```

### 5.2 Deploy the Stack

```bash
# Deploy the EKS cluster
cdk deploy

# This will:
# 1. Create VPC and networking components
# 2. Create EKS cluster
# 3. Create node groups
# 4. Install configured add-ons
# 5. Set up RBAC and permissions
```

### 5.3 Monitor Deployment

```bash
# Watch CloudFormation events
aws cloudformation describe-stack-events --stack-name CdkProjectsStack-eks-cluster

# Check EKS cluster status
aws eks describe-cluster --name CdkProjectsStack-eks-cluster
```

## Step 6: Connect to Your EKS Cluster

### 6.1 Update kubeconfig

```bash
# Add cluster to your kubeconfig
aws eks update-kubeconfig --region <your-region> --name CdkProjectsStack-eks-cluster

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### 6.2 Test Your Cluster

```bash
# Deploy a test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check the service
kubectl get services
```

## Step 7: Common Customizations

### 7.1 Add More Add-ons

```typescript
.addOns(
  // Existing add-ons...
  new blueprints.addons.ArgoCDAddOn(),           // GitOps tool
  new blueprints.addons.CalicoAddOn(),           // Network policy
  new blueprints.addons.XrayAddOn(),             // Distributed tracing
  new blueprints.addons.IngressNginxAddOn(),     // Ingress controller
)
```

### 7.2 Configure Teams

```typescript
.teams(
  new blueprints.PlatformTeam({
    name: 'platform-team',
    users: [
      { username: 'admin', role: blueprints.KubectlAccessRole.CLUSTER_ADMIN }
    ]
  }),
  new blueprints.ApplicationTeam({
    name: 'app-team',
    users: [
      { username: 'developer', role: blueprints.KubectlAccessRole.EDIT }
    ]
  })
)
```

### 7.3 Custom Node Groups

```typescript
.clusterProvider(
  new blueprints.GenericClusterProvider({
    version: 'auto',
    managedNodeGroups: [
      {
        id: 'general',
        instanceTypes: ['t3.medium'],
        minSize: 2,
        maxSize: 10,
        desiredSize: 3,
      }
    ]
  })
)
```

## Step 8: Clean Up (When Done)

```bash
# Delete the stack and all resources
cdk destroy

# Confirm deletion when prompted
```

## Troubleshooting

### Common Issues:

1. **Permission Denied**: Ensure your AWS user has sufficient IAM permissions
2. **Bootstrap Required**: Run `cdk bootstrap` if you get bootstrap errors
3. **Region Issues**: Verify your AWS region is supported for EKS
4. **Resource Limits**: Check AWS service limits for EKS clusters

### Useful Commands:

```bash
# Check CDK version
cdk --version

# List all stacks
cdk list

# Check differences before deployment
cdk diff

# View stack outputs
cdk outputs
```

## Next Steps

Once your cluster is running, you can:
- Deploy applications using `kubectl`
- Set up CI/CD pipelines
- Configure monitoring and logging
- Implement security policies
- Scale your applications

For more advanced configurations, refer to the [EKS Blueprints documentation](https://github.com/awslabs/cdk-eks-blueprints).


