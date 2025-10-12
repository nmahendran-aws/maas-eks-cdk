#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CdkProjectsStack } from '../lib/cdk-projects-stack';

const app = new cdk.App();
new CdkProjectsStack(app, 'CdkProjectsStack', {
  env: { account: process.env.ACC_ID, region: 'us-east-1' },
  // Provide your VPC ID here or via environment variable VPC_ID
  vpcId: process.env.VPC_ID,
});
