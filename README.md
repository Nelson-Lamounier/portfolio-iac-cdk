<!-- @format -->

# 🚀 AWS CDK Portfolio Blog - Multi-Account Infrastructure

A fully automated CDK multi-account infrastructure setup for a portfolio blog application with CI/CD pipeline.

## ✨ Features

- **🔄 Fully Automated**: Just commit/push and GitHub Actions handles everything
- **🏗️ Multi-Account**: Separate AWS accounts for dev, test, and production
- **🔐 Secure**: OIDC authentication with least privilege IAM roles
- **📦 CDK Bootstrap**: Automated CDK bootstrap across all accounts
- **🔍 Validation**: Comprehensive validation of all prerequisites
- **📋 Self-Healing**: Auto-detects and creates missing infrastructure

## 🎯 Quick Start

### 1. Configure Your Accounts

Update the `.env` file with your AWS account IDs:

```bash
# AWS Account IDs
PIPELINE_ACCOUNT_ID=123456789012  # Your pipeline/CI account
DEV_ACCOUNT_ID=111122223333       # Your development account
TEST_ACCOUNT_ID=444455556666      # Your test/staging account
PROD_ACCOUNT_ID=999999999999      # Your production account

# AWS Region
AWS_REGION=eu-west-1

# GitHub Repository
GITHUB_OWNER=Nelson-Lamounier
GITHUB_REPO=aws-cdk-portfolio-blog
GITHUB_BRANCH=main
```

### 2. Choose Your Bootstrap Method

**Setup OIDC Provider (One-Time)**

Before running the workflow, create the GitHub OIDC provider **once**:

```bash
# Configure AWS CLI with admin access to pipeline account
aws configure --profile pipeline-admin

# Create OIDC provider and role (one-time setup)
# Run from repository root directory
AWS_PROFILE=pipeline-admin ./scripts/setup-oidc-manual.sh
```

This creates:

- ✅ GitHub OIDC Provider
- ✅ GitHub Actions IAM Role with least privilege
- ✅ Proper trust relationships

**No GitHub Secrets needed!** The workflow uses OIDC authentication.

### 3. Run the Workflow

1. **Commit and push** your changes:

   ```bash
   git add .
   git commit -m "feat: configure multi-account setup"
   git push origin main
   ```

2. **Go to GitHub Actions**:

   - Navigate to your repository → **Actions**
   - Find "CDK Bootstrap Multi-Account"
   - Click **"Run workflow"**
   - Leave all inputs as default and click **"Run workflow"**

3. **The workflow will**:
   - ✅ Setup SSM parameters for configuration
   - ✅ Deploy cross-account roles where possible
   - ✅ Bootstrap CDK in all accounts
   - ✅ Validate the complete setup

### 4. Handle Manual Steps (If Any)

If the workflow can't access some accounts automatically, it will:

- Create manual deployment instructions (e.g., `manual-deployment-dev.md`)
- Show you exactly what to run in each account
- Allow you to re-run the workflow after manual steps

## 📊 What Gets Created

### AWS Infrastructure

- **GitHub OIDC Provider**: Secure authentication for GitHub Actions
- **IAM Roles**: Least privilege roles for CDK operations
- **SSM Parameters**: Secure configuration storage
- **Cross-Account Roles**: Roles for accessing target accounts
- **CDK Bootstrap**: CDK Toolkit stacks in all accounts

### Repository Structure

```
├── .github/workflows/
│   └── cdk-bootstrap.yml          # Fully automated workflow
├── scripts/
│   ├── setup-oidc-manual.sh       # OIDC provider setup (run once locally)
│   ├── setup-ssm-parameters.sh    # SSM parameters setup
│   ├── bootstrap-cdk-accounts.sh  # CDK bootstrap automation
│   └── validate-prerequisites.sh  # Comprehensive validation
├── cloudformation/                # Generated CloudFormation templates
├── bin/                          # CDK application entry points
├── lib/                          # CDK stack definitions
├── test/                         # Tests
├── .env                          # Configuration (update this!)
└── SETUP.md                      # Detailed setup guide
```

## 🔐 Security Features

- **Least Privilege**: All IAM roles follow AWS security best practices
- **OIDC Authentication**: No long-term AWS credentials in GitHub
- **Repository Restrictions**: Roles can only be assumed by your specific repository
- **Branch Restrictions**: Limited to main and feature branches
- **Regional Restrictions**: All operations limited to your specified region
- **IP Restrictions**: GitHub Actions IP ranges enforced where possible

## 🔧 Advanced Usage

### Force Bootstrap

To force re-bootstrap all accounts:

```bash
# In GitHub Actions workflow
bootstrap_method: "aws-credentials"
force_bootstrap: true
```

### Validate Only

To only validate the current setup without making changes:

```bash
# In GitHub Actions workflow
bootstrap_method: "existing-oidc"
force_bootstrap: false
```

### Local Development

You can also run the scripts locally:

```bash
# Validate current setup
./scripts/validate-prerequisites.sh

# Bootstrap CDK accounts
./scripts/bootstrap-cdk-accounts.sh

# Full setup (requires AWS credentials)
./scripts/setup-prerequisites.sh
```

## 🔍 Troubleshooting

### Common Issues

1. **"No AWS credentials available"**

   - Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets
   - Or manually create OIDC provider first

2. **"Cannot assume cross-account role"**

   - Follow the manual deployment instructions generated by the workflow
   - Ensure OrganizationAccountAccessRole exists in target accounts

3. **"CDK bootstrap failed"**
   - Verify cross-account roles are deployed correctly
   - Check trust relationships between accounts

### Getting Help

- Check the [detailed setup guide](SETUP.md)
- Review the [scripts documentation](scripts/README.md)
- Look at workflow logs in GitHub Actions
- Run validation: `./scripts/validate-prerequisites.sh`

## 📚 Documentation

- **[SETUP.md](SETUP.md)**: Comprehensive setup guide
- **[scripts/README.md](scripts/README.md)**: Scripts documentation
- **[AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)**
- **[GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)**

## 🎉 What's Next?

After successful bootstrap:

1. **Deploy your CDK applications** using the established pipeline
2. **Set up application-specific workflows** for continuous deployment
3. **Add monitoring and alerting** for your infrastructure
4. **Scale to additional accounts or regions** as needed

---

**🚀 Ready to get started?** Just update the `.env` file and push to main!

## Development Tools

This project now uses CDK Toolkit CLI for development utilities:

```bash
# Validate project structure
npx @your-org/cdk-toolkit validate

# Organize project files
npx @your-org/cdk-toolkit organize

# Run security scans
npx @your-org/cdk-toolkit security

# Migrate project structure
npx @your-org/cdk-toolkit migrate
```

For more information, see the [CDK Toolkit CLI documentation](./cdk-toolkit-cli/README.md).
