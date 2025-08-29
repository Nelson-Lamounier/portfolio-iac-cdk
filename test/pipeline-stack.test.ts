import { App, Stack } from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { PipelineStack, PipelineStackProps } from '../lib/pipeline-stack';

describe('PipelineStack', () => {
  let app: App;
  let stack: PipelineStack;
  let template: Template;

  const defaultProps: PipelineStackProps = {
    githubOrg: 'test-org',
    githubRepo: 'test-repo',
    githubBranch: 'main',
    devAccountId: '111111111111',
    testAccountId: '222222222222',
    prodAccountId: '333333333333',
    env: {
      account: '123456789012',
      region: 'us-east-1',
    },
  };

  beforeEach(() => {
    app = new App();
    stack = new PipelineStack(app, 'TestPipelineStack', defaultProps);
    template = Template.fromStack(stack);
  });

  describe('GitHub OIDC Provider', () => {
    test('creates OIDC provider with correct configuration', () => {
      template.hasResourceProperties('AWS::IAM::OIDCProvider', {
        Url: 'https://token.actions.githubusercontent.com',
        ClientIdList: ['sts.amazonaws.com'],
        ThumbprintList: ['6938fd4d98bab03faadb97b34396831e3780aea1']
      });
    });

    test('creates GitHub Actions role with federated principal', () => {
      template.hasResourceProperties('AWS::IAM::Role', {
        RoleName: 'GitHubActionsRole',
        AssumeRolePolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Effect: 'Allow',
              Principal: {
                Federated: Match.anyValue()
              },
              Action: 'sts:AssumeRoleWithWebIdentity',
              Condition: {
                StringEquals: {
                  'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com'
                },
                StringLike: {
                  'token.actions.githubusercontent.com:sub': 'repo:test-org/test-repo:*'
                }
              }
            })
          ])
        }
      });
    });

    test('attaches AdministratorAccess policy to GitHub Actions role', () => {
      template.hasResourceProperties('AWS::IAM::Role', {
        ManagedPolicyArns: Match.arrayWith([
          'arn:aws:iam::aws:policy/AdministratorAccess'
        ])
      });
    });
  });

  describe('SSM Parameters', () => {
    test('creates account ID parameters', () => {
      const expectedParameters = [
        { name: '/cdk/accounts/dev', value: '111111111111' },
        { name: '/cdk/accounts/test', value: '222222222222' },
        { name: '/cdk/accounts/prod', value: '333333333333' }
      ];

      expectedParameters.forEach(param => {
        template.hasResourceProperties('AWS::SSM::Parameter', {
          Name: param.name,
          Value: param.value,
          Type: 'String'
        });
      });
    });

    test('creates GitHub configuration parameters', () => {
      template.hasResourceProperties('AWS::SSM::Parameter', {
        Name: '/cdk/github/org',
        Value: 'test-org'
      });

      template.hasResourceProperties('AWS::SSM::Parameter', {
        Name: '/cdk/github/repo',
        Value: 'test-repo'
      });

      template.hasResourceProperties('AWS::SSM::Parameter', {
        Name: '/cdk/github/branch',
        Value: 'main'
      });
    });

    test('creates secure GitHub token parameter', () => {
      template.hasResourceProperties('AWS::SSM::Parameter', {
        Name: '/cdk/github/token',
        Type: 'SecureString'
      });
    });
  });

  describe('CodePipeline', () => {
    test('creates pipeline with correct name', () => {
      template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
        Name: 'test-repo-pipeline'
      });
    });

    test('enables cross-account keys', () => {
      template.hasResourceProperties('AWS::KMS::Key', {
        KeyPolicy: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Effect: 'Allow',
              Principal: { AWS: Match.anyValue() },
              Action: 'kms:*',
              Resource: '*'
            })
          ])
        }
      });
    });

    test('creates source stage with GitHub connection', () => {
      template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
        Stages: Match.arrayWith([
          Match.objectLike({
            Name: 'Source',
            Actions: Match.arrayWith([
              Match.objectLike({
                ActionTypeId: {
                  Category: 'Source',
                  Owner: 'ThirdParty',
                  Provider: 'GitHub'
                }
              })
            ])
          })
        ])
      });
    });
  });

  describe('Deployment Stages', () => {
    test('creates development stage', () => {
      // Check for Dev stage resources
      template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
        Stages: Match.arrayWith([
          Match.objectLike({
            Name: Match.stringLikeRegexp('.*Dev.*')
          })
        ])
      });
    });

    test('creates test stage with manual approval', () => {
      template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
        Stages: Match.arrayWith([
          Match.objectLike({
            Name: Match.stringLikeRegexp('.*Test.*'),
            Actions: Match.arrayWith([
              Match.objectLike({
                ActionTypeId: {
                  Category: 'Approval',
                  Owner: 'AWS',
                  Provider: 'Manual'
                }
              })
            ])
          })
        ])
      });
    });

    test('creates production stage with manual approval', () => {
      template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
        Stages: Match.arrayWith([
          Match.objectLike({
            Name: Match.stringLikeRegexp('.*Prod.*'),
            Actions: Match.arrayWith([
              Match.objectLike({
                ActionTypeId: {
                  Category: 'Approval',
                  Owner: 'AWS',
                  Provider: 'Manual'
                }
              })
            ])
          })
        ])
      });
    });
  });

  describe('Outputs', () => {
    test('exports GitHub OIDC Provider ARN', () => {
      template.hasOutput('GitHubOIDCProviderArn', {
        Description: 'ARN of the GitHub OIDC Provider',
        Export: {
          Name: 'GitHubOIDCProviderArn'
        }
      });
    });
  });

  describe('Resource Counts', () => {
    test('creates expected number of SSM parameters', () => {
      const parameters = template.findResources('AWS::SSM::Parameter');
      expect(Object.keys(parameters)).toHaveLength(8); // 7 config + 1 secure token
    });

    test('creates single OIDC provider', () => {
      const providers = template.findResources('AWS::IAM::OIDCProvider');
      expect(Object.keys(providers)).toHaveLength(1);
    });

    test('creates single pipeline', () => {
      const pipelines = template.findResources('AWS::CodePipeline::Pipeline');
      expect(Object.keys(pipelines)).toHaveLength(1);
    });
  });

  describe('Error Cases', () => {
    test('handles missing required props', () => {
      expect(() => {
        new PipelineStack(app, 'InvalidStack', {
          ...defaultProps,
          githubOrg: '',
        });
      }).toThrow();
    });
  });

  describe('Tags', () => {
    test('applies tags to GitHub Actions role', () => {
      template.hasResourceProperties('AWS::IAM::Role', {
        Tags: Match.arrayWith([
          { Key: 'ManagedBy', Value: 'CDK' },
          { Key: 'Purpose', Value: 'GitHubActions-CICD' }
        ])
      });
    });
  });
});