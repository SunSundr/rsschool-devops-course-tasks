# Terraform AWS Infrastructure Automation

This repository provides a Terraform configuration designed to deploy and manage AWS infrastructure including a Kubernetes (K3s) cluster using GitHub Actions for continuous integration and continuous deployment (CI/CD).

## Table of Contents

- [Terraform AWS Infrastructure Automation](#terraform-aws-infrastructure-automation)
  - [Table of Contents](#table-of-contents)
  - [Project Overview](#project-overview)
  - [Prerequisites](#prerequisites)
  - [AWS IAM Setup](#aws-iam-setup)
  - [Infrastructure Components](#infrastructure-components)
  - [K3s Kubernetes Cluster](#k3s-kubernetes-cluster)
  - [Terraform Configuration Files](#terraform-configuration-files)
  - [CI/CD Workflow](#cicd-workflow)
  - [Usage](#usage)
    - [Initial Setup (Manual, One-time)](#initial-setup-manual-one-time)
    - [Development Workflow (via GitHub Actions)](#development-workflow-via-github-actions)
  - [Security Considerations](#security-considerations)

## Project Overview

This project utilizes Terraform to define and provision AWS resources as Infrastructure as Code (IaC). A GitHub Actions CI/CD pipeline automates the process of validating, planning, and applying infrastructure changes, ensuring consistent and reliable deployments.

## Prerequisites

Before you begin, ensure you have the following:

*   An active AWS account.
*   AWS CLI configured with appropriate permissions to create initial resources (IAM roles/OIDC).
*   Terraform CLI installed (version >= 1.4).
*   A GitHub repository to host the Terraform code and workflow.

## AWS IAM Setup

To allow GitHub Actions to securely interact with your AWS environment, you need to configure an IAM role and an OpenID Connect (OIDC) provider in AWS.

1.  **IAM Role (`GithubActionsRole`)**: This role grants GitHub Actions the necessary permissions to manage AWS resources. The role includes policies for common AWS services such as EC2, Route53, S3, IAM, VPC, SQS, and EventBridge. It also incorporates an inline policy to enable DynamoDB state locking for Terraform state management.

    The role's trust policy is configured to allow `token.actions.githubusercontent.com` to assume it, with a condition ensuring that the `sub` claim matches the target GitHub repository, enhancing security.

2.  **IAM OIDC Provider**: Configured to trust `https://token.actions.githubusercontent.com`. This enables GitHub Actions to authenticate with AWS using short-lived tokens.

    These resources are defined in `iam.tf` and are provisioned during the initial Terraform apply process.

## Infrastructure Components

The infrastructure created by this project includes:

*   **VPC Architecture**:
    *   A VPC with 4 subnets across 2 different Availability Zones (AZs)
    *   2 public subnets in different AZs
    *   2 private subnets in different AZs
    *   Internet Gateway for public internet access
*   **Network Security**:
    *   Security groups for different instance types (bastion, NAT, public, private)
    *   Network ACLs for public and private subnets
    *   IMDSv2 required on all instances for enhanced security
*   **Compute Resources**:
    *   Bastion host - configured as an access point for instances inside the VPC
    *   NAT instance - enables outbound internet access for private subnet instances
    *   Test instances (optional) - 1 in a public subnet, 2 in different private subnets
*   **Routing Configuration**:
    *   Instances in all subnets can reach each other
    *   Instances in public subnets can reach addresses outside the VPC and vice-versa
    *   Private subnet instances can access the internet through the NAT instance
*   **Storage**:
    *   S3 bucket for Terraform state storage with lockfile-based state locking

## K3s Kubernetes Cluster

The project includes a fully functional K3s Kubernetes cluster deployed in private subnets:

*   **Cluster Architecture**:
    *   K3s master node in private subnet (AZ1)
    *   K3s worker node in private subnet (AZ2)
    *   Both nodes use Amazon Linux 2 for consistency
    *   IMDSv2 enabled for enhanced security

*   **Network Configuration**:
    *   Cluster nodes communicate through private networking
    *   Internet access via custom NAT instance for downloading K3s
    *   Security groups configured for K3s API (6443), Flannel VXLAN (8472), and Kubelet (10250)
    *   Access from bastion host for cluster management

*   **Cluster Features**:
    *   Automatic node joining with token-based authentication
    *   kubectl access configured on bastion host
    *   Ready to deploy workloads and services
    *   Supports standard Kubernetes manifests

*   **Management**:
    *   Access cluster via bastion host: `ssh -i key.pem ec2-user@<bastion-ip>`
    *   Check cluster status: `kubectl get nodes`
    *   Deploy workloads: `kubectl apply -f manifest.yaml`
    *   View all resources: `kubectl get all --all-namespaces`

## Terraform Configuration Files

The Terraform configuration is structured into several key files and modules:

*   **Root Module**:
    *   `main.tf`: Specifies the required Terraform version and module configurations.
    *   `variables.tf`: Declares all configurable variables used throughout the Terraform code.
    *   `providers.tf`: Configures the AWS provider, specifying the region and other settings.
    *   `backend.tf`: Configures the S3 bucket for storing the Terraform state file.
    *   `iam.tf`: Contains the AWS IAM role and OIDC provider resources for GitHub Actions.
    *   `data.tf`: Defines data sources to retrieve information from AWS, such as the current AWS account ID and region.
*   **Infrastructure Modules**:
    *   `modules/vpc`: VPC and Internet Gateway resources
    *   `modules/networking`: Subnets and routing configuration
    *   `modules/security`: Security groups and network ACLs
    *   `modules/compute`: Bastion host and NAT instance
    *   `modules/k3s`: K3s Kubernetes cluster (master and worker nodes)
    *   `modules/tests`: Optional test instances for infrastructure validation

## CI/CD Workflow

The CI/CD pipeline is defined in `.github/workflows/terraform.yml` and comprises the following stages:

*   **`terraform-check`**: Executes `terraform fmt -check -recursive` to enforce consistent code formatting across the project.
*   **`terraform-plan`**: Initializes Terraform and generates a detailed execution plan outlining the proposed infrastructure changes. This job requires the `terraform-check` job to complete successfully.
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

4.  **Deploy K3s Cluster (Optional)**:

    ```bash
    # Deploy the complete infrastructure including K3s cluster
    terraform apply -var="enable_k3s_cluster=true"
    
    # Access the cluster via bastion host
    ssh -i modules/compute/keys/<project>-key.pem ec2-user@<bastion-public-ip>
    
    # Check cluster status
    kubectl get nodes
    
    # Deploy a test workload
    kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
    kubectl get pods
    ```

### Development Workflow (via GitHub Actions)

1.  **Modify Terraform Configuration**: Make any necessary changes to your Terraform `.tf` files, primarily focusing on `variables.tf` to adjust settings.
2.  **Commit and Push**: Commit your changes and push them to a branch in your repository. This will automatically trigger the `terraform-check` and `terraform-plan` jobs in GitHub Actions.
3.  **Create a Pull Request (Recommended)**: Opening a pull request will trigger the `terraform-check` and `terraform-plan` jobs. This allows you to review the proposed infrastructure changes before merging. The plan output will be visible in the pull request, giving you confidence in the changes being applied.
4.  **Merge to `main`**: Pushing or merging changes to the `main` branch will trigger the `terraform-apply` job, automatically applying your infrastructure changes to AWS, provided all previous checks have passed.

## Jenkins CI/CD Setup

This project includes a complete Jenkins setup with Configuration as Code (JCasC) and Kubernetes agents for distributed builds.

### Prerequisites for Jenkins

*   **Minikube** installed and running with Docker driver
*   **kubectl** configured to access your Minikube cluster
*   **Helm** package manager installed
*   **Environment variables** configured (see `.env.example`)

### Jenkins Installation (Minikube)

#### 1. Environment Setup

Copy the example environment file and configure your credentials:

```bash
cp .env.example .env
# Edit .env with your preferred Jenkins admin credentials
```

#### 2. Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --driver=docker --memory=4096 --cpus=2

# Verify Minikube is running
minikube status
```

#### 3. Install Jenkins

```bash
# Run the automated installation script
./install-jenkins.sh minikube

# Wait for Jenkins to be ready (may take 3-5 minutes)
kubectl get pods -n jenkins -w
```

#### 4. Access Jenkins

```bash
# Access Jenkins via Minikube service
minikube service jenkins --namespace jenkins

# Alternative: Use port-forward
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```

**Login Credentials:**
- Username: `admin` (or value from `.env`)
- Password: Value from your `.env` file

### Jenkins Configuration

#### Automated Configuration (JCasC)

Jenkins is automatically configured with:

*   **Security**: Authentication and authorization via JCasC
*   **Plugins**: Kubernetes, Configuration as Code, Job DSL, and Workflow plugins
*   **Kubernetes Cloud**: Configured for distributed builds with agents
*   **RBAC**: Proper permissions for Jenkins to manage Kubernetes pods

#### Manual Kubernetes Cloud Setup (if needed)

If the automated cloud configuration doesn't work, configure manually:

1. **Go to**: Manage Jenkins → Clouds → Add a new cloud → Kubernetes
2. **Configure**:
   - **Name**: `kubernetes`
   - **Kubernetes URL**: `https://kubernetes.default`
   - **Kubernetes Namespace**: `jenkins`
   - **Jenkins URL**: `http://jenkins.jenkins.svc.cluster.local:8080`
   - **Jenkins tunnel**: `jenkins-agent-nodeport.jenkins.svc.cluster.local:50000`

3. **Pod Template**:
   - **Name**: `default`
   - **Namespace**: `jenkins`
   - **Labels**: `jenkins-agent`
   - **Usage**: Use this node as much as possible
   - **Container Template**:
     - **Name**: `jnlp`
     - **Docker Image**: `jenkins/inbound-agent:latest`
     - **Working directory**: `/home/jenkins/agent`

4. **Test Connection** should show "Connected to Kubernetes"

### Jenkins Features

#### Kubernetes Agents

*   **Distributed Builds**: Jobs run on dynamically created agent pods
*   **Resource Isolation**: Each build runs in its own container
*   **Auto-scaling**: Agents are created on-demand and destroyed after use
*   **No Manual Setup**: Agents are managed automatically by Jenkins

#### Persistent Storage

*   **Custom Persistent Volume**: 4Gi persistent volume with custom storage class `jenkins-storage`
*   **Retain Policy**: `persistentVolumeReclaimPolicy: Retain` - data persists even after Jenkins deletion
*   **Minikube Integration**: Uses `/mnt/data/jenkins-data` path inside Minikube container
*   **Automated Setup**: Directory permissions (1000:1000, 775) configured automatically during installation
*   **Data Persistence**: Jenkins configuration, job history, and plugins survive pod restarts and Minikube restarts

#### Security

*   **Authentication**: Local user database with admin account
*   **Authorization**: Logged-in users can perform all actions
*   **RBAC**: Jenkins service account has permissions to manage pods
*   **Secrets Management**: Admin credentials stored in Kubernetes secrets

### Testing Jenkins

#### Automatic Test Job

A `hello-world` job is **automatically created** during Jenkins installation via JCasC configuration. This job demonstrates:

- Kubernetes agent execution
- Basic shell commands
- Build output logging

**To run the automatic job:**
1. Go to Jenkins dashboard
2. Click on `hello-world` job
3. Click **Build Now**
4. Check **Console Output** for results

#### Create Additional Jobs (Manual)

You can create additional jobs manually:

1. **New Item** → **Freestyle project** → Name: `my-custom-job`
2. **Build Steps** → **Execute shell**:
   ```bash
   echo "Hello World from Jenkins!"
   echo "Current date: $(date)"
   echo "Running on: $(hostname)"
   echo "Kubernetes agent working!"
   ```
3. **Save** and **Build Now**

#### Verify Agent Execution

```bash
# Watch agent pods being created
kubectl get pods -n jenkins -w

# Check agent logs
kubectl logs <agent-pod-name> -n jenkins
```

### Troubleshooting

#### Common Issues

**Jenkins Pod Not Starting:**
```bash
# Check pod status
kubectl describe pod jenkins-0 -n jenkins

# Check logs
kubectl logs jenkins-0 -n jenkins -c jenkins
```

**Agent Connection Issues:**
```bash
# Verify services
kubectl get svc -n jenkins

# Check RBAC permissions
kubectl get role,rolebinding -n jenkins

# Test Kubernetes cloud connection in Jenkins UI
```

**Plugin Issues:**
- Update plugins via Jenkins UI: Manage Jenkins → Plugins
- Restart Jenkins: `kubectl rollout restart statefulset/jenkins -n jenkins`

### Cloud Deployment

**Note**: Cloud deployment configuration is included but not tested. The setup includes:

*   **AWS EBS Storage**: Dynamic provisioning with 5Gi volumes
*   **LoadBalancer Service**: For external access in cloud environments
*   **Cloud-specific Values**: Separate configuration files for cloud deployment

**To deploy on cloud** (untested):
```bash
./install-jenkins.sh cloud
```

### File Structure

```
k8s/jenkins/
├── base/
│   ├── values.yaml              # Main Jenkins configuration
│   └── rbac.yaml                # RBAC permissions
├── minikube/
│   ├── values-minikube.yaml     # Minikube-specific overrides
│   ├── pv.yaml                  # Custom persistent volume (4Gi)
│   └── storage-class.yaml       # Custom storage class (jenkins-storage)
└── cloud/
    ├── values-cloud.yaml        # Cloud-specific overrides (untested)
    ├── pv.yaml                  # Cloud persistent volume (untested)
    └── storage-class-cloud.yaml # Cloud storage class (untested)
```

## Security Considerations

*   **No Secrets in Repository**: This repository relies on environment variables and IAM roles for authentication and authorization, avoiding the storage of sensitive credentials within the code.
*   **IAM Least Privilege**: The IAM role provided by GitHub Actions is configured with the minimum number of permissions necessary to perform its tasks, which will reduce the potential impact of a compromised token..
*   **OIDC Trust Configuration**: The OIDC provider trust configuration ensures that only authorized repositories can assume the IAM role..
*   **State File Security**: The S3 bucket used to store the Terraform state file is securely protected with encryption and access controls.
*   **IMDSv2 Required**: All EC2 instances are configured to require IMDSv2, enhancing security against SSRF vulnerabilities.
*   **Jenkins Security**: Admin credentials managed via Kubernetes secrets, RBAC permissions properly configured.
