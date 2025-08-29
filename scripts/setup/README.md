# Setup Scripts

## Purpose

Configure AWS resources, OIDC providers, and project prerequisites

## Description

Scripts for initial project and environment setup

## Scripts in this Category

- **setup-oidc-manual.sh - Configure OIDC provider**
- **setup-ssm-parameters.sh - Setup SSM parameters**
- **setup-cross-account-role.sh - Configure cross-account roles**
- **validate-prerequisites.sh - Validate setup requirements**

## Usage Guidelines

### Prerequisites

- Ensure you have appropriate AWS credentials configured
- Make scripts executable before running: `chmod +x script-name.sh`
- Review script documentation and parameters before execution

### Security Considerations

- Never commit AWS credentials or sensitive data
- Use environment variables or AWS profiles for authentication
- Review scripts for hardcoded values before running in production

### Error Handling

- Scripts use `set -e` for fail-fast behavior
- Check script exit codes and logs for troubleshooting
- Ensure proper cleanup on script failure

## Contributing

When adding new setup scripts:

1. Follow the naming convention: `action-resource.sh`
2. Include proper error handling and logging
3. Add documentation comments at the top of the script
4. Update this README with script descriptions
5. Ensure scripts are executable (`chmod +x`)

## Related Documentation

- [Main Scripts Documentation](../README.md)
- [Project Setup Guide](../../SETUP.md)
- [Security Guidelines](../../SECURITY.md)
