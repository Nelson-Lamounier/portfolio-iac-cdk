<!-- @format -->

# Logs Directory

This directory contains development and deployment logs organized by activity type. All log files are automatically excluded from version control to prevent sensitive data exposure.

## Directory Structure

- `build/` - Build and compilation logs (CDK synthesis, TypeScript compilation, dependency installation)
- `deployment/` - Deployment activity logs (bootstrap, pipeline deployment, stack deployment)
- `testing/` - Test execution logs (unit tests, integration tests, security scans)
- `development/` - Development workflow logs (local development, workflow tests)

## Security Features

- **Automatic Sanitization**: All logs are processed to remove credentials, API keys, and sensitive data
- **Account ID Masking**: AWS account IDs are replaced with placeholder values
- **Retention Policy**: Logs are automatically rotated and cleaned up after 30 days
- **Git Exclusion**: All log files are excluded from version control

## Log Management

Logs are managed through the logging utilities in `scripts/utilities/`. Key features include:

- Automatic log rotation when files exceed size limits
- Sensitive data filtering and sanitization
- Structured logging with timestamps and context
- Retention policy enforcement

## Usage

Logs are automatically generated during development and deployment activities. To view recent logs:

```bash
# View recent build logs
tail -f logs/build/cdk-synth.log

# View deployment logs
tail -f logs/deployment/stack-deploy.log

# View test execution logs
tail -f logs/testing/unit-tests.log
```

## Security Considerations

- Never manually add sensitive information to log files
- Log files are automatically sanitized but should not be shared externally
- Account IDs and other identifiers are masked for security
- Credentials and API keys are automatically filtered out
