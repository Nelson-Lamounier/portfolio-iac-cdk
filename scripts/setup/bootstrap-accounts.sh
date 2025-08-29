#!/bin/bash
# scripts/bootstrap-accounts.sh

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Color coding for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Use environment variables or parameter store
readonly ORGANIZATION_ID="${AWS_ORGANIZATION_ID}"
readonly BOOTSTRAP_QUALIFIER="${CDK_QUALIFIER:-myorg}"
readonly AWS_REGION="${AWS_REGION:-us-east-1}"
readonly BOOTSTRAP_KMS_KEY_ALIAS="alias/cdk-${BOOTSTRAP_QUALIFIER}-key"

# Account IDs (should be stored in SSM or GitHub Secrets)
readonly PIPELINE_ACCOUNT="${PIPELINE_ACCOUNT_ID}"
readonly DEV_ACCOUNT="${DEV_ACCOUNT_ID}"
readonly TEST_ACCOUNT="${TEST_ACCOUNT_ID}"
readonly PROD_ACCOUNT="${PROD_ACCOUNT_ID}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if bootstrap is needed
check_bootstrap_status() {
    local account=$1
    local region=$2
    
    log_info "Checking bootstrap status for account $account in region $region"
    
    # Assume role in target account (if not pipeline account)
    if [[ "$account" != "$PIPELINE_ACCOUNT" ]]; then
        assume_role_in_account "$account"
    fi
    
    # Check if CDKToolkit stack exists
    if aws cloudformation describe-stacks \
        --stack-name CDKToolkit \
        --region "$region" &>/dev/null; then
        
        # Get bootstrap version
        local version=$(aws cloudformation describe-stacks \
            --stack-name CDKToolkit \
            --region "$region" \
            --query "Stacks[0].Outputs[?OutputKey=='BootstrapVersion'].OutputValue" \
            --output text 2>/dev/null || echo "0")
        
        if [[ "$version" -ge 14 ]]; then
            log_info "Account $account already bootstrapped with version $version"
            return 0
        else
            log_warning "Account $account has outdated bootstrap version $version"
            return 1
        fi
    else
        log_info "Account $account needs bootstrapping"
        return 1
    fi
}

# Function to assume role in target account
assume_role_in_account() {
    local account=$1
    local role_name="OrganizationAccountAccessRole"  # Default AWS Organizations role
    
    log_info "Assuming role in account $account"
    
    local credentials=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account}:role/${role_name}" \
        --role-session-name "CDKBootstrap" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    
    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | awk '{print $1}')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | awk '{print $2}')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | awk '{print $3}')
}

# Function to reset AWS credentials
reset_credentials() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
}

# Bootstrap Pipeline Account
bootstrap_pipeline_account() {
    log_info "Bootstrapping Pipeline Account: $PIPELINE_ACCOUNT"
    
    if ! check_bootstrap_status "$PIPELINE_ACCOUNT" "$AWS_REGION"; then
        cdk bootstrap "aws://${PIPELINE_ACCOUNT}/${AWS_REGION}" \
            --qualifier "$BOOTSTRAP_QUALIFIER" \
            --toolkit-stack-name "CDKToolkit-${BOOTSTRAP_QUALIFIER}" \
            --cloudformation-execution-policies \
                "arn:aws:iam::aws:policy/AdministratorAccess" \
            --bootstrap-kms-key-alias "$BOOTSTRAP_KMS_KEY_ALIAS" \
            --tags "Environment=Pipeline" \
            --tags "ManagedBy=CDK" \
            --tags "Qualifier=${BOOTSTRAP_QUALIFIER}" \
            --tags "BootstrapDate=$(date -u +%Y-%m-%d)" \
            || { log_error "Failed to bootstrap Pipeline account"; return 1; }
    fi
    
    log_info "Pipeline account bootstrap complete"
}

# Bootstrap Target Account (Dev/Test/Prod)
bootstrap_target_account() {
    local account=$1
    local environment=$2
    
    log_info "Bootstrapping $environment Account: $account"
    
    if ! check_bootstrap_status "$account" "$AWS_REGION"; then
        # For target accounts, we need to trust the pipeline account
        cdk bootstrap "aws://${account}/${AWS_REGION}" \
            --qualifier "$BOOTSTRAP_QUALIFIER" \
            --toolkit-stack-name "CDKToolkit-${BOOTSTRAP_QUALIFIER}" \
            --cloudformation-execution-policies \
                "arn:aws:iam::aws:policy/AdministratorAccess" \
            --trust "$PIPELINE_ACCOUNT" \
            --trust-for-lookup "$PIPELINE_ACCOUNT" \
            --bootstrap-kms-key-alias "$BOOTSTRAP_KMS_KEY_ALIAS" \
            --tags "Environment=${environment}" \
            --tags "ManagedBy=CDK" \
            --tags "Qualifier=${BOOTSTRAP_QUALIFIER}" \
            --tags "PipelineAccount=${PIPELINE_ACCOUNT}" \
            --tags "BootstrapDate=$(date -u +%Y-%m-%d)" \
            || { log_error "Failed to bootstrap $environment account"; return 1; }
    fi
    
    log_info "$environment account bootstrap complete"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check CDK CLI
    if ! command -v cdk &> /dev/null; then
        log_error "AWS CDK is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Validate account IDs
    for account in "$PIPELINE_ACCOUNT" "$DEV_ACCOUNT" "$TEST_ACCOUNT" "$PROD_ACCOUNT"; do
        if [[ ! "$account" =~ ^[0-9]{12}$ ]]; then
            log_error "Invalid AWS account ID: $account"
            exit 1
        fi
    done
    
    log_info "Prerequisites validated successfully"
}

# Main execution
main() {
    log_info "Starting multi-account CDK bootstrap process"
    log_info "Region: $AWS_REGION"
    log_info "Qualifier: $BOOTSTRAP_QUALIFIER"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Store original credentials
    local original_access_key="${AWS_ACCESS_KEY_ID:-}"
    local original_secret_key="${AWS_SECRET_ACCESS_KEY:-}"
    local original_session_token="${AWS_SESSION_TOKEN:-}"
    
    # Bootstrap Pipeline Account first
    bootstrap_pipeline_account
    
    # Bootstrap target accounts
    declare -A accounts=(
        ["$DEV_ACCOUNT"]="Development"
        ["$TEST_ACCOUNT"]="Testing"
        ["$PROD_ACCOUNT"]="Production"
    )
    
    for account in "${!accounts[@]}"; do
        reset_credentials
        # Restore original credentials for assuming role
        export AWS_ACCESS_KEY_ID="$original_access_key"
        export AWS_SECRET_ACCESS_KEY="$original_secret_key"
        export AWS_SESSION_TOKEN="$original_session_token"
        
        bootstrap_target_account "$account" "${accounts[$account]}"
    done
    
    # Restore original credentials
    reset_credentials
    export AWS_ACCESS_KEY_ID="$original_access_key"
    export AWS_SECRET_ACCESS_KEY="$original_secret_key"
    export AWS_SESSION_TOKEN="$original_session_token"
    
    log_info "All accounts bootstrapped successfully!"
    
    # Output summary
    echo -e "\n${GREEN}Bootstrap Summary:${NC}"
    echo "Pipeline Account: $PIPELINE_ACCOUNT"
    echo "Dev Account: $DEV_ACCOUNT"
    echo "Test Account: $TEST_ACCOUNT"
    echo "Prod Account: $PROD_ACCOUNT"
    echo "Region: $AWS_REGION"
    echo "Qualifier: $BOOTSTRAP_QUALIFIER"
}

# Trap errors and cleanup
trap 'log_error "Script failed on line $LINENO"' ERR

# Run main function
main "$@"