# Jenkins CI/CD Pipeline for Flask Application

This repository contains a complete CI/CD pipeline for a Flask application using Jenkins, Docker, SonarCloud, and Kubernetes (Minikube).

## Prerequisites

- Minikube installed
- kubectl installed
- Docker installed
- Git installed
- SonarCloud account (free)
- DockerHub account

## Setup Instructions

### 1. Start Minikube

Start Minikube with sufficient resources:

```bash
minikube start --driver=docker --memory=4096 --cpus=2
```

### 2. Install Jenkins

Run the setup script to install Jenkins on Minikube:

```bash
./setup-pipeline.sh
```

### 3. Access Jenkins

Open Jenkins in your browser:

```bash
minikube service jenkins --namespace jenkins
```

The default credentials are:
- Username: admin
- Password: (check your .env file or Jenkins logs)

### 4. Configure Jenkins

#### 4.1 Add DockerHub Credentials

1. Navigate to **Manage Jenkins** → **Credentials** → **System** → **Global credentials** → **Add Credentials**
2. Select **Username with password**
3. Enter your DockerHub username and password
4. Set ID to `dockerhub-credentials`
5. Click **OK**

#### 4.2 Add SonarCloud Token

1. Generate a token in SonarCloud (User → My Account → Security → Generate Tokens)
2. In Jenkins, go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials** → **Add Credentials**
3. Select **Secret text**
4. Enter your SonarCloud token
5. Set ID to `sonar-token`
6. Click **OK**

#### 4.3 Configure Email Notifications

1. Go to **Manage Jenkins** → **System**
2. Scroll to **E-mail Notification**
3. Configure the following:
   - SMTP server: `smtp.gmail.com`
   - Default user e-mail suffix: `@gmail.com`
   - Use SMTP Authentication: ✓
   - Username: your full email
   - Password: App Password (not your main Gmail password)
   - Use SSL: ✓
   - SMTP Port: 465
4. Test the configuration by sending a test email

### 5. Create a New Pipeline Job

1. Click **New Item** on the Jenkins dashboard
2. Enter a name for your pipeline (e.g., `flask-app-pipeline`)
3. Select **Pipeline** and click **OK**

### 6. Configure Pipeline

1. In the pipeline configuration page, scroll to the **Pipeline** section
2. Select **Pipeline script from SCM**
3. Select **Git** as the SCM
4. Enter your repository URL
5. Specify the branch to build (e.g., `*/main` or `*/master`)
6. Set the **Script Path** to `Jenkinsfile`
7. Under **Build Triggers**, check **Poll SCM** and enter `H/5 * * * *` (polls every 5 minutes)
8. Click **Save**

### 7. Run the Pipeline

1. Click **Build Now** to start the pipeline manually for the first time
2. After the initial run, the pipeline will automatically trigger when changes are pushed to the repository

### 8. Pipeline Stages

The pipeline includes the following stages:

1. **Checkout**: Clones the repository
2. **Build Application**: Installs Python dependencies
3. **Run Unit Tests**: Executes tests and generates coverage reports
4. **Security Check**: Runs Bandit and Safety security scanners
5. **SonarCloud Analysis**: Performs code quality analysis
6. **Docker Build and Push**: Builds and pushes the Docker image to DockerHub
7. **Install Helm**: Downloads and installs Helm
8. **Deploy to Kubernetes**: Deploys the application to Minikube using Helm
9. **Verify Deployment**: Verifies the deployment status

### 9. Accessing the Application

After successful deployment, access the Flask application:

```bash
# Port forward the service
kubectl port-forward svc/flask-app 8080:8080 -n flask-app

# Access in browser
http://localhost:8080
```

## CI/CD Pipeline Implementation Details

### Jenkins Pipeline Architecture

The CI/CD pipeline is implemented using a declarative Jenkins pipeline defined in the Jenkinsfile. It uses a Kubernetes pod template to dynamically provision agent pods with the necessary tools for each stage of the pipeline.

### Key Components

#### Kubernetes Pod Template
The pipeline uses a custom Kubernetes pod with the following containers:
- **jnlp**: Jenkins agent container
- **python**: For running Python-based tasks (tests, security scans)
- **docker**: For building and pushing Docker images

#### SCM Polling
The pipeline is configured to poll the SCM repository every 5 minutes using the `pollSCM` trigger. This allows the pipeline to automatically detect and build changes pushed to the repository.

#### Credentials Management
The pipeline securely manages credentials using Jenkins' credentials binding:
- DockerHub credentials for image pushing
- SonarCloud token for code quality analysis

#### Helm Deployment
The application is deployed to Kubernetes using Helm charts with environment-specific values:
- `values-minikube.yaml` for local Minikube deployment
- Custom image repository and tag based on the build number

#### Error Handling
The pipeline includes error handling in the post-failure section to clean up failed deployments, ensuring the Kubernetes cluster remains in a clean state even when builds fail.

## Troubleshooting

### Pipeline Not Finding Jenkinsfile

- Verify the repository URL and branch name
- Check if the Jenkinsfile is in the root directory
- Ensure the Script Path is correctly set to `Jenkinsfile`

### Git Repository Access Issues

- Check if Jenkins has access to your Git repository
- For private repositories, add appropriate credentials in Jenkins

### Docker Build Failures

- Verify Docker socket is properly mounted in the Jenkins pod
- Check DockerHub credentials are correctly configured
- Ensure the Docker daemon is running in Minikube

### Kubernetes Deployment Issues

- Check RBAC permissions with `kubectl auth can-i` commands
- Verify Helm chart structure and values
- Check pod logs with `kubectl logs -n flask-app <pod-name>`

### SonarCloud Integration Problems

- Verify SonarCloud token is correctly configured
- Check organization and project key settings
- Ensure coverage reports are being generated correctly

## Cleanup

To clean up resources:

```bash
# Uninstall the Flask application
helm uninstall flask-app -n flask-app

# Delete the namespace
kubectl delete namespace flask-app

# Stop Minikube
minikube stop
```
