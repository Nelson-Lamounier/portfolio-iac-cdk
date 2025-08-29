#!/bin/bash

# Setup SSM Parameters for GitHub Actions
# This script stores account information securely in SSM Parameter Store

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find repository root and load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Debug: Script directory: $SCRIPT_DIR"
echo "Debug: Repository root: $REPO_ROOT"
echo "Debug: Looking for .env at: $REPO_ROOT/.env"

if [ -f "$REPO_ROOT/.env" ]; then
    echo "Loading environment variables from $REPO_ROOT/.env"
    set -a  # automatically export all variables
    source "$REPO_ROOT/.env"
    set +a  # stop automatically exporting
    echo "Debug: .env file loaded successfully"
elif [ -f .env ]; then
    echo "Loading environment variables from .env"
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
    echo "Debug: .env file loaded from current directory"
else
    echo "Warning: .env file not found. Using environment variables if available."
    echo "Debug: Checked paths:"
    echo "  - $REPO_ROOT/.env"
    echo "  - $(pwd)/.env"
fi

# Set AWS profile for pipeline account
AWS_PROFILE="pipeline-account"
export AWS_PROFILE

echo "Using AWS Profile: $AWS_PROFILE"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS CLI not configured or no valid credentials${NC}"
    echo "Please ensure your 'pipeline-account' profile is configured and you're logged in:"
    echo "  aws sso login --profile pipeline-account"
    exit 1
fi

echo -e "${GREEN}Setting up SSM Parameters for GitHub Actions...${NC}"

# Validate required environment variables
required_vars=(
    "PIPELINE_ACCOUNT_ID:Pipeline Account ID"
    "DEV_ACCOUNT_ID:Development Account ID"
    "TEST_ACCOUNT_ID:Test Account ID"
    "PROD_ACCOUNT_ID:Production Account ID"
    "AWS_REGION:AWS Region"
    "GITHUB_OWNER:GitHub Repository Owner"
    "GITHUB_REPO:GitHub Repository Name"
    "GITHUB_BRANCH:GitHub Branch"
)

echo "Validating environment variables..."
for var_info in "${required_vars[@]}"; do
    var_name="${var_info%:*}"
    var_description="${var_info#*:}"
    var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        echo -e "${RED}❌ Error: $var_name is not set or empty${NC}"
        echo "   Description: $var_description"
        echo "   Current value: '$var_value'"
        echo "   Please check your .env file"
        exit 1
    else
        echo -e "${GREEN}✅ $var_name: $var_value${NC}"
    fi
done

echo ""
echo -e "${GREEN}All environment variables validated successfully!${NC}"
echo ""

# Function to create or update SSM parameter
create_or_update_parameter() {
    local param_name="$1"
    local param_value="$2"
    local param_description="$3"
    
    echo "Creating/updating parameter: $param_name"
    
    if aws ssm describe-parameters --parameter-filters "Key=Name,Values=$param_name" --query 'Parameters[0].Name' --output text 2>/dev/null | grep -q "$param_name"; then
        echo "  Parameter exists, updating..."
        aws ssm put-parameter --name "$param_name" --value "$param_value" --type "String" --overwrite
    else
        echo "  Creating new parameter..."
        aws ssm put-parameter --name "$param_name" --value "$param_value" --type "String" --description "$param_description" --tags "Key=Project,Value=PortfolioRevampIaC" "Key=ManagedBy,Value=GitHubActions"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✅ Success: $param_name${NC}"
    else
        echo -e "  ${RED}❌ Failed: $param_name${NC}"
        exit 1
    fi
    echo ""
}

# Create or update SSM parameters
create_or_update_parameter "/github-actions/accounts/pipeline" "$PIPELINE_ACCOUNT_ID" "Pipeline Account ID for GitHub Actions"
create_or_update_parameter "/github-actions/accounts/dev" "$DEV_ACCOUNT_ID" "Development Account ID for GitHub Actions"
create_or_update_parameter "/github-actions/accounts/test" "$TEST_ACCOUNT_ID" "Test Account ID for GitHub Actions"
create_or_update_parameter "/github-actions/accounts/prod" "$PROD_ACCOUNT_ID" "Production Account ID for GitHub Actions"
create_or_update_parameter "/github-actions/config/aws-region" "$AWS_REGION" "AWS Region for GitHub Actions"
create_or_update_parameter "/github-actions/github/owner" "$GITHUB_OWNER" "GitHub Repository Owner"
create_or_update_parameter "/github-actions/github/repo" "$GITHUB_REPO" "GitHub Repository Name"
create_or_update_parameter "/github-actions/github/branch" "$GITHUB_BRANCH" "GitHub Branch for Actions"

echo -e "${GREEN}All SSM parameters created successfully!${NC}"
echo -e "${YELLOW}Parameters created:${NC}"
aws ssm describe-parameters \
    --parameter-filters "Key=Name,Option=BeginsWith,Values=/github-actions/" \
    --query 'Parameters[].Name' \
    --output table

echo -e "${GREEN}Setup complete!${NC}"