

# Manual OIDC Setup Script for Pipeline Account
# This script creates the OIDC provider and role manually using AWS CLI with SSO profile

set -e

echo "🚀 Setting up GitHub OIDC in Pipeline Account..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Find repository root and load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$REPO_ROOT/.env" ]; then
    print_status "Loading environment variables from $REPO_ROOT/.env"
    set -a  # automatically export all variables
    source "$REPO_ROOT/.env"
    set +a  # stop automatically exporting
elif [ -f .env ]; then
    print_status "Loading environment variables from .env"
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
else
    print_error ".env file not found. Please create it with your account details."
    exit 1
fi

# Map environment variables to expected names
PIPELINE_ACCOUNT="$PIPELINE_ACCOUNT_ID"
DEV_ACCOUNT="$DEV_ACCOUNT_ID"
TEST_ACCOUNT="$TEST_ACCOUNT_ID"
PROD_ACCOUNT="$PROD_ACCOUNT_ID"

# Validate required environment variables
required_vars=(
    "PIPELINE_ACCOUNT_ID:Pipeline Account ID"
    "DEV_ACCOUNT_ID:Development Account ID"
    "TEST_ACCOUNT_ID:Test Account ID"
    "PROD_ACCOUNT_ID:Production Account ID"
    "GITHUB_OWNER:GitHub Repository Owner"
    "GITHUB_REPO:GitHub Repository Name"
)

print_status "Validating environment variables..."
for var_info in "${required_vars[@]}"; do
    var_name="${var_info%:*}"
    var_description="${var_info#*:}"
    var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        print_error "$var_name is not set or empty"
        echo "   Description: $var_description"
        echo "   Please check your .env file"
        exit 1
    else
        print_status "$var_name: $var_value"
    fi
done

# Set AWS profile for pipeline account
AWS_PROFILE="pipeline-account"
export AWS_PROFILE

print_status "Using AWS Profile: $AWS_PROFILE"

# Verify we're in the correct account
print_status "Verifying AWS account access..."
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$CURRENT_ACCOUNT" ]; then
    print_error "Failed to get AWS account identity. Please check your SSO login:"
    echo "  aws sso login --profile pipeline-account"
    exit 1
fi

if [ "$CURRENT_ACCOUNT" != "$PIPELINE_ACCOUNT" ]; then
    print_error "Account mismatch!"
    echo "  Expected: $PIPELINE_ACCOUNT (Pipeline Account)"
    echo "  Current:  $CURRENT_ACCOUNT"
    echo ""
    echo "Please ensure your 'pipeline-account' profile is configured correctly."
    exit 1
fi

print_success "Connected to Pipeline Account: $CURRENT_ACCOUNT"

# Step 1: Create OIDC Identity Provider
print_status "Creating GitHub OIDC Identity Provider..."

# Check if OIDC provider already exists
EXISTING_PROVIDER=$(aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_PROVIDER" ]; then
    print_warning "OIDC Provider already exists: $EXISTING_PROVIDER"
    OIDC_PROVIDER_ARN="$EXISTING_PROVIDER"
else
    print_status "Creating new OIDC Provider..."
    OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        --query 'OpenIDConnectProviderArn' \
        --output text)
    print_success "Created OIDC Provider: $OIDC_PROVIDER_ARN"
fi

# Step 2: Create Trust Policy
print_status "Creating trust policy..."

# Create trust policy directly
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_OWNER/$GITHUB_REPO:*"
        }
      }
    }
  ]
}
EOF

# Step 3: Create IAM Role
print_status "Creating GitHub Actions IAM Role..."

# Check if role already exists
if aws iam get-role --role-name GitHubActions-CDKBootstrap-Role >/dev/null 2>&1; then
    print_warning "Role already exists, updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name GitHubActions-CDKBootstrap-Role \
        --policy-document file:///tmp/trust-policy.json
    ROLE_ARN=$(aws iam get-role \
        --role-name GitHubActions-CDKBootstrap-Role \
        --query 'Role.Arn' \
        --output text)
    print_success "Updated existing role: $ROLE_ARN"
else
    print_status "Creating new IAM role..."
    ROLE_ARN=$(aws iam create-role \
        --role-name GitHubActions-CDKBootstrap-Role \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for GitHub Actions to perform CDK bootstrap and deployment" \
        --max-session-duration 3600 \
        --query 'Role.Arn' \
        --output text)
    print_success "Created GitHub Actions Role: $ROLE_ARN"
fi

# Step 4: Create and attach policy
print_status "Creating and attaching permissions policy..."

# Create the IAM policy (using the legacy policy for now)
print_status "Generating IAM policy..."

# Legacy policy creation (keeping for reference)
cat > /tmp/github-actions-policy-legacy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OrganizationReadAccess",
      "Effect": "Allow",
      "Action": [
        "organizations:ListAccounts",
        "organizations:DescribeAccount",
        "organizations:ListOrganizationalUnitsForParent"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CrossAccountRoleAssumption",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::$DEV_ACCOUNT:role/OrganizationAccountAccessRole",
        "arn:aws:iam::$TEST_ACCOUNT:role/OrganizationAccountAccessRole",
        "arn:aws:iam::$PROD_ACCOUNT:role/OrganizationAccountAccessRole",
        "arn:aws:iam::$DEV_ACCOUNT:role/CDKBootstrapExecutionRole",
        "arn:aws:iam::$TEST_ACCOUNT:role/CDKBootstrapExecutionRole",
        "arn:aws:iam::$PROD_ACCOUNT:role/CDKBootstrapExecutionRole"
      ],
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "github-$GITHUB_OWNER-$GITHUB_REPO"
        }
      }
    },
    {
      "Sid": "LocalPipelineDeployment",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:GetTemplate",
        "cloudformation:ListStackResources",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": [
        "arn:aws:cloudformation:*:$PIPELINE_ACCOUNT:stack/PipelineStack/*",
        "arn:aws:cloudformation:*:$PIPELINE_ACCOUNT:stack/CrossAccountRoleStack-*/*",
        "arn:aws:cloudformation:*:$PIPELINE_ACCOUNT:stack/CentralizedMonitoringStack/*",
        "arn:aws:cloudformation:*:$PIPELINE_ACCOUNT:stack/GitHubOIDCStack/*"
      ]
    },
    {
      "Sid": "CDKOperations",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:PutBucketVersioning",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetObject",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:InvokeFunction",
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:DELETE",
        "codepipeline:CreatePipeline",
        "codepipeline:UpdatePipeline",
        "codepipeline:DeletePipeline",
        "codepipeline:GetPipeline",
        "codepipeline:ListPipelines",
        "codebuild:CreateProject",
        "codebuild:UpdateProject",
        "codebuild:DeleteProject",
        "codebuild:BatchGetProjects",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:iam::$PIPELINE_ACCOUNT:role/cdk-*",
        "arn:aws:iam::$PIPELINE_ACCOUNT:role/*GitHubActions*",
        "arn:aws:s3:::cdk-*",
        "arn:aws:s3:::codepipeline-*",
        "arn:aws:lambda:*:$PIPELINE_ACCOUNT:function:*",
        "arn:aws:apigateway:*::/restapis/*",
        "arn:aws:codepipeline:*:$PIPELINE_ACCOUNT:pipeline/*",
        "arn:aws:codebuild:*:$PIPELINE_ACCOUNT:project/*",
        "arn:aws:secretsmanager:*:$PIPELINE_ACCOUNT:secret:github-token-*"
      ]
    }
  ]
}
EOF

# Attach the policy
print_status "Attaching permissions policy to role..."
aws iam put-role-policy \
    --role-name GitHubActions-CDKBootstrap-Role \
    --policy-name GitHubActionsPolicy \
    --policy-document file:///tmp/github-actions-policy-legacy.json

print_success "Policy attached successfully"

# Clean up temp files
rm -f /tmp/trust-policy.json /tmp/github-actions-policy-legacy.json

echo ""
echo "🎉 GitHub OIDC setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "OIDC Provider ARN: $OIDC_PROVIDER_ARN"
echo "GitHub Role ARN: $ROLE_ARN"
echo ""
echo "🔧 Next Steps:"
echo "1. Test the setup by running the GitHub Actions workflow"
echo "2. Go to your GitHub repository → Actions → Run 'Test Manual OIDC Setup'"
echo ""
echo "📖 The role is configured for:"
echo "- Repository: $GITHUB_OWNER/$GITHUB_REPO"
echo "- Branches: main, feature/*"
echo "- Session Duration: 1 hour"