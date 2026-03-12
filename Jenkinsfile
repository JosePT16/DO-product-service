def buildTags() {
    def safeBranch = (env.BRANCH_NAME ?: 'local').replaceAll('[^A-Za-z0-9_.-]', '-')
    def buildNumber = env.BUILD_NUMBER ?: '0'
    def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'manual'
    return [
        localImage: "${env.SERVICE_NAME}:${buildNumber}",
        versionTag: "${safeBranch}-${buildNumber}",
        commitTag: "git-${shortCommit}"
    ]
}

def resolveDeployEnvironment() {
    if (env.BRANCH_NAME == 'develop') {
        return 'dev'
    }
    if (env.BRANCH_NAME?.startsWith('release/')) {
        return 'staging'
    }
    if (env.BRANCH_NAME == 'main') {
        return 'prod'
    }
    return 'build-only'
}

pipeline {
    agent { label 'principal' }

    options {
        timestamps()
    }

    environment {
        SERVICE_NAME = 'do-product-service'
        IMAGE_REPO = 'joseptz/do-product-service'
        DOCKERFILE_PATH = 'Dockerfile'
        K8S_DEPLOYMENT_NAME = 'product-service'
        K8S_GREEN_DEPLOYMENT_NAME = 'product-service-green'
        K8S_CONTAINER_NAME = 'product-service'
        K8S_APP_LABEL = 'product-service'
        K8S_STABLE_SERVICE_NAME = 'product-service'
        K8S_NODEPORT_SERVICE_NAME = 'product-service-nodeport'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                powershell 'npm ci'
            }
        }

        stage('Test') {
            steps {
                powershell 'npm test -- --runInBand --passWithNoTests'
            }
        }

        stage('Container Build') {
            steps {
                powershell 'Write-Host "Workspace diagnostics"; Get-Location; Get-ChildItem -Force'
                powershell 'Write-Host "Docker diagnostics"; whoami; docker version; docker info'
                script {
                    def tags = buildTags()
                    powershell "docker build -f ${env.DOCKERFILE_PATH} -t ${tags.localImage} -t ${env.IMAGE_REPO}:${tags.versionTag} -t ${env.IMAGE_REPO}:${tags.commitTag} ."
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    def tags = buildTags()
                    powershell ".\\scripts\\scan.ps1 -ImageTag ${tags.localImage} -ReportPath reports\\trivy-jenkins.txt"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/*.txt', allowEmptyArchive: true
                }
            }
        }

       stage('Container Push') {
            when {
                allOf {
                    not { changeRequest() }
                    anyOf {
                        branch 'develop'
                        branch 'main'
                        expression { return env.BRANCH_NAME?.startsWith('release/') }
                    }
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat 'docker logout'
                    bat '@echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin docker.io'
                    script {
                        def tags = buildTags()
                        bat "docker tag ${tags.localImage} ${env.IMAGE_REPO}:${tags.versionTag}"
                        bat "docker tag ${tags.localImage} ${env.IMAGE_REPO}:${tags.commitTag}"
                        bat 'docker images'
                        echo "Pushing ${env.IMAGE_REPO}:${tags.versionTag}"
                        echo "Pushing ${env.IMAGE_REPO}:${tags.commitTag}"
                        bat "docker push ${env.IMAGE_REPO}:${tags.versionTag}"
                        bat "docker push ${env.IMAGE_REPO}:${tags.commitTag}"
                        if (env.BRANCH_NAME == 'main') {
                            bat "docker tag ${tags.localImage} ${env.IMAGE_REPO}:latest"
                            bat "docker push ${env.IMAGE_REPO}:latest"
                        }
                    }
                }
            }
        }


        stage('Deploy') {
            when {
                not { changeRequest() }
            }
            steps {
                script {
                    def tags = buildTags()
                    def deployEnv = resolveDeployEnvironment()
                    if (deployEnv == 'prod') {
                        input message: 'Approve production deployment?', ok: 'Deploy'
                    }

                    writeFile file: 'deploy-target.txt', text: "${deployEnv}:${tags.versionTag}\n"

                    if (deployEnv != 'build-only') {
                        powershell """
                        \$namespace = "ecommerce-${deployEnv}"
                        \$selectorPatch = @{ spec = @{ selector = @{ app = "${env.K8S_APP_LABEL}"; version = "green" } } } | ConvertTo-Json -Compress
                        kubectl apply -k ..\\k8s\\overlays\\${deployEnv}
                        kubectl set image deployment/${env.K8S_GREEN_DEPLOYMENT_NAME} ${env.K8S_CONTAINER_NAME}=${env.IMAGE_REPO}:${tags.versionTag} -n \$namespace
                        kubectl rollout status deployment/${env.K8S_GREEN_DEPLOYMENT_NAME} -n \$namespace --timeout=300s
                        kubectl patch service/${env.K8S_STABLE_SERVICE_NAME} -n \$namespace --type merge -p \$selectorPatch
                        kubectl patch service/${env.K8S_NODEPORT_SERVICE_NAME} -n \$namespace --type merge -p \$selectorPatch
                        kubectl get deployment/${env.K8S_GREEN_DEPLOYMENT_NAME} -n \$namespace -o wide | Out-File -FilePath deployment-validation.txt
                        kubectl get service/${env.K8S_STABLE_SERVICE_NAME} -n \$namespace -o wide | Out-File -FilePath deployment-validation.txt -Append
                        kubectl get service/${env.K8S_NODEPORT_SERVICE_NAME} -n \$namespace -o wide | Out-File -FilePath deployment-validation.txt -Append
                        kubectl get pods -n \$namespace -l app=${env.K8S_APP_LABEL},version=green -o wide | Out-File -FilePath deployment-validation.txt -Append
                        """
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'deploy-target.txt,deployment-validation.txt', allowEmptyArchive: true
                }
            }
        }
    }
}
