<!-- @format -->

# Deployment Logs

This directory contains logs from deployment and infrastructure activities.

## Log Types

- `bootstrap.log` - CDK bootstrap operations and account setup
- `pipeline-deploy.log` - CI/CD pipeline deployment activities
- `stack-deploy.log` - Individual stack deployment operations
- `rollback.log` - Stack rollback and recovery operations
- `cross-account.log` - Cross-account role setup and operations

## Security Features

- AWS account IDs are automatically masked as `[ACCOUNT-ID]`
- IAM role ARNs are sanitized to remove account-specific information
- Deployment credentials are filtered out automatically

## Log Rotation

Deployment logs are retained for 30 days and rotated when they exceed 50MB.
