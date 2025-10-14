#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CdkProjectsStack } from '../lib/cdk-projects-stack';

const app = new cdk.App();
new CdkProjectsStack(app, 'CdkProjectsStack', {
  env: { account: '471727841202', region: 'us-east-1' },
  // Using specified VPC ID
  vpcId: 'vpc-00e9c2080fc3a870f',
});
