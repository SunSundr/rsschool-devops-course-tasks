pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-agent
    version: v1
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:3309.v27b_9314fd1a_4-6
  - name: python
    image: python:3.13.5-slim
    command: ["cat"]
    tty: true
  - name: docker
    image: docker:28
    command: ["cat"]
    tty: true
    volumeMounts:
      - name: docker-sock
        mountPath: /var/run/docker.sock
  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
        type: Socket
"""
        }
    }
    
    triggers {
        pollSCM('H/5 * * * *') // Poll every 5 minutes
    }
    
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials') //
        IMAGE_NAME = 'flask-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        SONAR_TOKEN = credentials('sonar-token')
        SONAR_ORGANIZATION = 'rss-devops-course-tasks'
        SONAR_PROJECT_KEY = 'rss-devops-course-tasks_flask-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Application') {
            steps {
                container('python') {
                    sh '''
                        apt-get update && apt-get install -y gcc python3-dev
                        pip install -r flask_app/requirements.txt
                        pip install pytest pytest-cov
                    '''
                }
            }
        }
        
        stage('Run Unit Tests') {
            steps {
                container('python') {
                    dir('flask_app') {
                        sh 'python -m pytest --cov=. --cov-report=xml:coverage.xml'
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'flask_app/coverage.xml', allowEmptyArchive: true
                }
            }
        }
        
        stage('Security Check') {
            steps {
                container('python') {
                    sh '''
                        pip install bandit safety
                        mkdir -p reports
                        
                        # Run Bandit security scanner
                        echo "Running Bandit security scan..."
                        cd flask_app && python -m bandit -r . -f txt -o ../reports/bandit-report.txt || true
                        
                        # Run Safety dependency scanner
                        echo "Running Safety dependency scan..."
                        cd flask_app && python -m safety check -r requirements.txt --output text > ../reports/safety-report.txt || true
                    '''
                    
                    // Archive reports
                    archiveArtifacts artifacts: 'reports/*-report.txt', allowEmptyArchive: true
                }
            }
        }
        
        stage('SonarCloud Analysis') {
            steps {
                container('python') {
                    sh 'echo "Starting SonarCloud Analysis stage"'
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh 'echo "Credentials loaded successfully"'
                        sh '''
                            apt-get update -qq && apt-get install -y --no-install-recommends unzip wget openjdk-17-jre-headless
                            # Download and install SonarScanner
                            wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
                            unzip -q sonar-scanner-cli-*.zip

                            # Run SonarCloud scan
                            cd flask_app
                            ../sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner \\
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \\
                              -Dsonar.organization=${SONAR_ORGANIZATION} \\
                              -Dsonar.sources=. \\
                              -Dsonar.host.url=https://sonarcloud.io \\
                              -Dsonar.login=${SONAR_TOKEN} \\
                              -Dsonar.python.coverage.reportPaths=coverage.xml
                        '''
                    }
                }
            }
        }
        
        stage('Docker Build and Push') {
            steps {
                container('docker') {
                    dir('flask_app') {
                        sh '''
                            # Login to DockerHub
                            echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin
                            
                            # Build Docker image
                            docker build -t ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG} .
                            docker tag ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG} ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:latest
                            
                            # Push Docker image
                            docker push ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG}
                            docker push ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }
        
        stage('Install Helm') {
            steps {
                sh '''
                    curl -LO https://get.helm.sh/helm-v3.18.4-linux-amd64.tar.gz
                    tar -zxvf helm-v3.18.4-linux-amd64.tar.gz
                    mv linux-amd64/helm ./helm
                    chmod +x ./helm
                '''
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    # Create namespace if it doesn't exist
                    ./helm upgrade --install flask-app ./flask_app/helm-chart/flask-app \\
                        --create-namespace \\
                        --namespace flask-app \\
                        -f ./flask_app/helm-chart/flask-app/values-minikube.yaml \\
                        --set image.repository=${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME} \\
                        --set image.tag=${IMAGE_TAG} \\
                        --set image.pullPolicy=IfNotPresent \\
                        --timeout=300s
                """
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    # Install kubectl if needed
                    if ! command -v kubectl &> /dev/null; then
                        curl -LO "https://dl.k8s.io/release/stable.txt"
                        KUBECTL_VERSION=$(cat stable.txt)
                        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        mkdir -p $HOME/bin
                        mv kubectl $HOME/bin/
                        export PATH=$HOME/bin:$PATH
                    fi
                    
                    # Wait for pods to be ready
                    echo "\nWaiting for pods to be ready..."
                    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flask-app -n flask-app --timeout=120s
                    
                    # Check deployment status
                    echo "\nChecking deployment status:"
                    ./helm status flask-app -n flask-app
                    kubectl get pods -n flask-app
                    
                    # Test application and metrics
                    echo "\nTesting application and metrics..."
                    kubectl port-forward svc/flask-app 8080:8080 -n flask-app &
                    PORT_FORWARD_PID=$!
                    sleep 5
                    
                    # Test main endpoint
                    echo "Testing main endpoint:"
                    curl -s http://localhost:8080/ | head -5
                    
                    # Test metrics endpoint
                    echo "\nTesting metrics endpoint:"
                    curl -s http://localhost:8080/metrics | head -10
                    
                    # Generate requests and check metrics
                    echo "\nGenerating requests..."
                    curl -s http://localhost:8080/health > /dev/null
                    curl -s http://localhost:8080/info > /dev/null
                    
                    echo "\nUpdated metrics:"
                    curl -s http://localhost:8080/metrics | grep flask_requests_total || echo "No flask metrics found yet"
                    
                    # Clean up
                    kill $PORT_FORWARD_PID || echo "Could not kill port-forward process"
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed'
        }
        success {
            echo 'Pipeline succeeded'
            emailext (
                to: 'art.dizigner@gmail.com',
                subject: "✅ SUCCESS: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                body: """<html>
                    <body>
                        <h2>✅ Build Successful!</h2>
                        <p>Job: <b>${env.JOB_NAME}</b></p>
                        <p>Build Number: <b>#${env.BUILD_NUMBER}</b></p>
                        <p>Build URL: <a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>
                        <p>Deployed Image: <b>${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG}</b></p>
                        <hr>
                        <p>Check the <a href='${env.BUILD_URL}console'>Console Output</a> for more details.</p>
                    </body>
                </html>""",
                mimeType: 'text/html'
            )
        }
        failure {
            echo 'Pipeline failed'
            
            // Clean up failed deployments
            sh '''
                # Install kubectl if needed
                if ! command -v kubectl &> /dev/null; then
                    curl -LO "https://dl.k8s.io/release/stable.txt"
                    KUBECTL_VERSION=$(cat stable.txt)
                    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mkdir -p $HOME/bin
                    mv kubectl $HOME/bin/
                    export PATH=$HOME/bin:$PATH
                fi
                
                # Check if namespace exists and clean up
                if ./helm status flask-app -n flask-app &>/dev/null; then
                    echo "Cleaning up failed deployment..."
                    ./helm uninstall flask-app -n flask-app
                    echo "Deployment cleaned up."
                else
                    echo "No deployment to clean up."
                fi
            '''
            
            emailext (
                to: 'art.dizigner@gmail.com',
                subject: "❌ FAILED: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                body: """<html>
                    <body>
                        <h2>❌ Build Failed!</h2>
                        <p>Job: <b>${env.JOB_NAME}</b></p>
                        <p>Build Number: <b>#${env.BUILD_NUMBER}</b></p>
                        <p>Build URL: <a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>
                        <hr>
                        <p>Check the <a href='${env.BUILD_URL}console'>Console Output</a> for more details.</p>
                    </body>
                </html>""",
                mimeType: 'text/html'
            )
        }
    }
}
