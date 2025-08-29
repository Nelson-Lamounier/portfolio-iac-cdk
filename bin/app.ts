/** @format */

// bin/cdk-app.ts
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { SSM } from "@aws-sdk/client-ssm";
import { PipelineStack } from "../lib/pipeline-stack";

async function getSSMParameter(name: string): Promise<string> {
  const ssm = new SSM({ region: process.env.AWS_REGION || "us-east-1" });
  const result = await ssm.getParameter({ Name: name });
  return result.Parameter?.Value || "";
}

async function main() {
  const app = new cdk.App();

  // Check if we should use SSM config
  const useSSMConfig = app.node.tryGetContext("useSSMConfig") === "true";

  let config;

  if (useSSMConfig) {
    // Read from SSM Parameter Store
    console.log("Loading configuration from SSM Parameter Store...");
    config = {
      githubOrg: await getSSMParameter("/cdk/github/org"),
      githubRepo: await getSSMParameter("/cdk/github/repo"),
      githubBranch: await getSSMParameter("/cdk/github/branch"),
      devAccountId: await getSSMParameter("/cdk/accounts/dev"),
      testAccountId: await getSSMParameter("/cdk/accounts/test"),
      prodAccountId: await getSSMParameter("/cdk/accounts/prod"),
      pipelineAccountId: await getSSMParameter("/cdk/accounts/pipeline"),
    };
  } else {
    // Fallback to environment variables or context
    config = {
      githubOrg: app.node.tryGetContext("githubOrg") || process.env.GITHUB_ORG,
      githubRepo:
        app.node.tryGetContext("githubRepo") || process.env.GITHUB_REPO,
      githubBranch: app.node.tryGetContext("githubBranch") || "main",
      devAccountId:
        app.node.tryGetContext("devAccount") || process.env.DEV_ACCOUNT_ID,
      testAccountId:
        app.node.tryGetContext("testAccount") || process.env.TEST_ACCOUNT_ID,
      prodAccountId:
        app.node.tryGetContext("prodAccount") || process.env.PROD_ACCOUNT_ID,
      pipelineAccountId:
        app.node.tryGetContext("pipelineAccount") ||
        process.env.PIPELINE_ACCOUNT_ID,
    };
  }

  new PipelineStack(app, "CDKPipelineStack", {
    env: {
      account: config.pipelineAccountId,
      region: process.env.AWS_REGION || "us-east-1",
    },
    ...config,
  });

  app.synth();
}

main().catch(console.error);
