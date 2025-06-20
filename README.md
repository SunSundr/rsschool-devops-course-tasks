# Terraform AWS Infrastructure Automation

This repository provides a Terraform configuration designed to deploy and manage AWS infrastructure using GitHub Actions for continuous integration and continuous deployment (CI/CD).

## Table of Contents

- [Terraform AWS Infrastructure Automation](#terraform-aws-infrastructure-automation)
  - [Table of Contents](#table-of-contents)
  - [Project Overview](#project-overview)
  - [Prerequisites](#prerequisites)
  - [AWS IAM Setup](#aws-iam-setup)
  - [Terraform Configuration Files](#terraform-configuration-files)
  - [CI/CD Workflow](#cicd-workflow)
  - [Usage](#usage)
    - [Initial Setup (Manual, One-time)](#initial-setup-manual-one-time)
    - [Development Workflow (via GitHub Actions)](#development-workflow-via-github-actions)
  - [Security Considerations](#security-considerations)

## Project Overview

This project utilizes Terraform to define and provision AWS resources as Infrastructure as Code (IaC). A GitHub Actions CI/CD pipeline automates the process of validating, planning, and applying infrastructure changes, ensuring consistent and reliable deployments.  The focus is on modularity and maintainability. Configuration is driven through `variables.tf`, promoting reusability and reducing hardcoded values.

## Prerequisites

Before you begin, ensure you have the following:

*   An active AWS account.
*   AWS CLI configured with appropriate permissions to create initial resources (IAM roles/OIDC).
*   Terraform CLI installed (version >= 1.4).
*   A GitHub repository to host the Terraform code and workflow.

## AWS IAM Setup

To allow GitHub Actions to securely interact with your AWS environment, you need to configure an IAM role and an OpenID Connect (OIDC) provider in AWS.

1.  **IAM Role (`GithubActionsRole`)**:  This role grants GitHub Actions the necessary permissions to manage AWS resources. The role includes policies for common AWS services such as EC2, Route53, S3, IAM, VPC, SQS, and EventBridge. It also incorporates an inline policy to enable DynamoDB state locking for Terraform state management.

    The role's trust policy is configured to allow `token.actions.githubusercontent.com` to assume it, with a condition ensuring that the `sub` claim matches the target GitHub repository, enhancing security.

2.  **IAM OIDC Provider**:  Configured to trust `https://token.actions.githubusercontent.com`. This enables GitHub Actions to authenticate with AWS using short-lived tokens.

    These resources are defined in `iam.tf` and are provisioned during the initial Terraform apply process.

## Terraform Configuration Files

The Terraform configuration is structured into several key files:

*   `main.tf`: Specifies the required Terraform version and any necessary provider dependencies.
*   `variables.tf`: Declares all configurable variables used throughout the Terraform code. This promotes reuse and simplifies configuration changes.  This is the primary file for adjusting infrastructure settings.
*   `providers.tf`: Configures the AWS provider, specifying the region and potentially other provider-specific settings.
*   `backend.tf`:  Configures the S3 bucket for storing the Terraform state file and DynamoDB for state locking, ensuring collaborative access and preventing conflicts.
*   `data.tf`: Defines data sources to retrieve information from AWS, such as the current AWS account ID and region.
*   `iam.tf`: Contains the AWS IAM role and OIDC provider resources necessary for GitHub Actions authentication.

## CI/CD Workflow

The CI/CD pipeline is defined in `.github/workflows/terraform.yml` and comprises the following stages:

*   **`terraform-check`**: Executes `terraform fmt -check -recursive` to enforce consistent code formatting across the project.
*   **`terraform-plan`**: Initializes Terraform and generates a detailed execution plan outlining the proposed infrastructure changes.  This job requires the `terraform-check` job to complete successfully.
*   **`terraform-apply`**: Applies the Terraform changes to your AWS environment. This job is triggered by `push` events to the `main` branch, only after `terraform-plan` has succeeded, and may require manual approval depending on your configuration.

To minimize redundancy, a reusable composite action located at `.github/actions/terraform-setup/action.yml` encapsulates common setup steps, including checking out the code, configuring AWS credentials, and setting up the Terraform CLI.

## Usage

### Initial Setup (Manual, One-time)

1.  **Clone the repository**:

    ```bash
    git clone rsschool-devops-course-tasks
    cd rsschool-devops-course-tasks
    ```

2.  **Initialize Terraform**: This step downloads the necessary providers and configures the S3 backend. Ensure your AWS CLI is properly configured before running this command.

    ```bash
    terraform init
    ```

3.  **Apply Initial IAM Resources**: The `iam.tf` file contains the IAM role and OIDC provider that GitHub Actions will use. This typically needs to be applied manually the first time, or outside the CI/CD pipeline, unless you already have infrastructure in place to provision these:

    ```bash
    terraform apply -target=aws_iam_role.github_actions -target=aws_iam_openid_connect_provider.github_actions
    # Or, if applying everything for the first time:
    # terraform apply
    ```

### Development Workflow (via GitHub Actions)

1.  **Modify Terraform Configuration**:  Make any necessary changes to your Terraform `.tf` files, primarily focusing on `variables.tf` to adjust settings.
2.  **Commit and Push**: Commit your changes and push them to a branch in your repository.  This will automatically trigger the `terraform-check` and `terraform-plan` jobs in GitHub Actions.
3.  **Create a Pull Request (Recommended)**:  Opening a pull request will trigger the `terraform-check` and `terraform-plan` jobs. This allows you to review the proposed infrastructure changes before merging. The plan output will be visible in the pull request, giving you confidence in the changes being applied.
4.  **Merge to `main`**:  Pushing or merging changes to the `main` branch will trigger the `terraform-apply` job, automatically applying your infrastructure changes to AWS, provided all previous checks have passed.

## Security Considerations

*   **No Secrets in Repository**: This repository relies on environment variables and IAM roles for authentication and authorization, avoiding the storage of sensitive credentials within the code.
*   **IAM Least Privilege**:  The IAM role granted to GitHub Actions should be configured with the least amount of permissions necessary to perform its tasks, reducing the potential impact of a compromised token.
*   **OIDC Trust Configuration**: The OIDC provider trust configuration should be carefully reviewed to ensure that only authorized repositories can assume the IAM role.
*   **State File Security**:  The S3 bucket used for storing the Terraform state file should be properly secured with encryption and access controls to prevent unauthorized access.  Enforce encryption at rest and in transit.
*   **Review Terraform Plans**: Always carefully review the Terraform execution plan before applying changes to your infrastructure to identify any unexpected or potentially harmful actions.
*   **Variable Security**: Never store secret values directly in `variables.tf`. Use mechanisms like AWS Secrets Manager or environment variables passed through GitHub Actions to provide sensitive data to Terraform.  This repository does not demonstrate this, but it is crucial for secure deployments.
