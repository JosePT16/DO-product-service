pipeline {
    agent any

    options {
        timestamps()
    }

    environment {
        SERVICE_NAME = 'do-product-service'
        IMAGE_REPO = 'joseptz/do-product-service'
        DOCKERFILE_PATH = 'Dockerfile'
        LOCAL_IMAGE = ''
        VERSION_TAG = ''
        COMMIT_TAG = ''
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    def safeBranch = env.BRANCH_NAME.replaceAll('[^A-Za-z0-9_.-]', '-')
                    def shortCommit = powershell(script: '(git rev-parse --short HEAD).Trim()', returnStdout: true).trim()
                    env.LOCAL_IMAGE = "${env.SERVICE_NAME}:${env.BUILD_NUMBER}"
                    env.VERSION_TAG = "${safeBranch}-${env.BUILD_NUMBER}"
                    env.COMMIT_TAG = "git-${shortCommit}"
                }
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
                powershell "docker build -f ${env.DOCKERFILE_PATH} -t ${env.LOCAL_IMAGE} -t ${env.IMAGE_REPO}:${env.VERSION_TAG} -t ${env.IMAGE_REPO}:${env.COMMIT_TAG} ."
            }
        }

        stage('Security Scan') {
            steps {
                powershell ".\\scripts\\scan.ps1 -ImageTag ${env.LOCAL_IMAGE} -ReportPath reports\\trivy-jenkins.txt"
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
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    powershell 'echo $env:DOCKER_PASS | docker login -u $env:DOCKER_USER --password-stdin'
                    powershell "docker push ${env.IMAGE_REPO}:${env.VERSION_TAG}"
                    powershell "docker push ${env.IMAGE_REPO}:${env.COMMIT_TAG}"
                    script {
                        if (env.BRANCH_NAME == 'main') {
                            powershell "docker tag ${env.LOCAL_IMAGE} ${env.IMAGE_REPO}:latest"
                            powershell "docker push ${env.IMAGE_REPO}:latest"
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
                    if (env.BRANCH_NAME == 'develop') {
                        writeFile file: 'deploy-target.txt', text: "dev:${env.VERSION_TAG}\n"
                    } else if (env.BRANCH_NAME?.startsWith('release/')) {
                        writeFile file: 'deploy-target.txt', text: "staging:${env.VERSION_TAG}\n"
                    } else if (env.BRANCH_NAME == 'main') {
                        input message: 'Approve production deployment?', ok: 'Deploy'
                        writeFile file: 'deploy-target.txt', text: "prod:${env.VERSION_TAG}\n"
                    } else {
                        writeFile file: 'deploy-target.txt', text: "build-only:${env.VERSION_TAG}\n"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'deploy-target.txt', allowEmptyArchive: true
                }
            }
        }
    }
}
