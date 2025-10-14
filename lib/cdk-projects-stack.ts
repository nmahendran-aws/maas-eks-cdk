import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as blueprints from '@aws-quickstart/eks-blueprints';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';

export interface EksStackProps extends cdk.StackProps {
  vpcId?: string;  // Optional: Use existing VPC by ID
  createNewVpc?: boolean;  // Optional: Force create new VPC
}

export class CdkProjectsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: EksStackProps) {
    super(scope, id, props);

    // Tag all resources created by this stack
    cdk.Tags.of(this).add('Name', 'Maas');

    // EKS Cluster using the provided pattern
    const account = props?.env?.account!;
    const region = props?.env?.region!;
    
    // VPC Configuration
    let vpcProvider: blueprints.VpcProvider | undefined;
    let vpcForEc2: ec2.IVpc | undefined;
    
    if (props?.vpcId) {
      // Use existing VPC
      console.log(`Using existing VPC: ${props.vpcId}`);
      vpcProvider = new blueprints.VpcProvider(props.vpcId);
      // Also resolve VPC for creating additional resources (e.g., private EC2 instance)
      vpcForEc2 = ec2.Vpc.fromLookup(this, 'ExistingVpcForEc2', { vpcId: props.vpcId });
    } else if (props?.createNewVpc !== false) {
      // Create new VPC (default behavior)
      console.log('Creating new VPC for EKS cluster');
    }
    
    // Build EKS Blueprint
    const blueprint = blueprints.EksBlueprint.builder()
      .account(account)
      .region(region)
      .clusterProvider(new blueprints.GenericClusterProvider({
        version: eks.KubernetesVersion.V1_25,
        endpointAccess: eks.EndpointAccess.PRIVATE, // private-only API endpoint
        managedNodeGroups: [
          {
            id: 'mng1',
            instanceTypes: [ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM)],
            minSize: 1,
            maxSize: 5,
            desiredSize: 2,
            nodeGroupSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
          }
        ]
      }))
      .addOns(
        // Core add-ons for a functional cluster
        new blueprints.addons.CoreDnsAddOn(),
        new blueprints.addons.KubeProxyAddOn(),
        new blueprints.addons.VpcCniAddOn(),
        
        // Optional but recommended add-ons
        new blueprints.addons.MetricsServerAddOn(),
        new blueprints.addons.ClusterAutoScalerAddOn(),
        new blueprints.addons.AwsLoadBalancerControllerAddOn(),
        new blueprints.addons.ContainerInsightsAddOn()
      )
      .teams(); // You can add teams here if needed
    
    // Add VPC provider if specified
    if (vpcProvider) {
      blueprint.resourceProvider(blueprints.GlobalResources.Vpc, vpcProvider);
    }
    
    const stackId = id + "-eks-cluster";
    blueprint.build(scope, stackId);

    // Optional: Create a private EC2 instance in the same VPC (when vpcId is provided)
    if (vpcForEc2) {
      // Security group that only allows outbound traffic (no public ingress)
      const instanceSg = new ec2.SecurityGroup(this, 'EKSInstanceSg', {
        vpc: vpcForEc2,
        description: 'Security group for private EC2 instance in EKS VPC',
        allowAllOutbound: true,
      });

      // Instance role with SSM access for Session Manager
      const instanceRole = new iam.Role(this, 'EKSInstanceRole', {
        assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
        description: 'Role for private EC2 instance with SSM access',
      });
      instanceRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'));

      new ec2.Instance(this, 'EKSInstance', {
        vpc: vpcForEc2,
        vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
        securityGroup: instanceSg,
        role: instanceRole,
        instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
        machineImage: ec2.MachineImage.latestAmazonLinux2023(),
      });
    }
  }
}
