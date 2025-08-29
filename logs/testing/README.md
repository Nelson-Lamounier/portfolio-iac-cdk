<!-- @format -->

# Testing Logs

This directory contains logs from test execution and quality assurance activities.

## Log Types

- `unit-tests.log` - Unit test execution results and coverage reports
- `integration-tests.log` - Integration test results and API testing
- `security-scans.log` - Security scanning and vulnerability assessment
- `e2e-tests.log` - End-to-end test execution and results
- `performance-tests.log` - Performance and load testing results

## Test Data Security

- Test data containing mock credentials is automatically sanitized
- Real AWS resources used in integration tests have identifiers masked
- Test database connections and credentials are filtered out

## Log Rotation

Testing logs are rotated weekly and retained for 14 days.
