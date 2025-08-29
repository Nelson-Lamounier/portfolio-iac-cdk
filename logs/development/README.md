<!-- @format -->

# Development Logs

This directory contains logs from local development and workflow activities.

## Log Types

- `local-dev.log` - Local development server and hot-reload activities
- `workflow-tests.log` - Local workflow testing and validation
- `debug.log` - Debug output and troubleshooting information
- `git-hooks.log` - Pre-commit hooks and Git workflow activities
- `ide-integration.log` - IDE and editor integration activities

## Development Security

- Local environment variables are filtered to prevent credential exposure
- Database connection strings are sanitized
- API endpoints and keys used in development are masked

## Log Rotation

Development logs are rotated daily and retained for 7 days to keep disk usage minimal.
