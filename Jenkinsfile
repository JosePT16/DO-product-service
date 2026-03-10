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

pipeline {
    agent any

    options {
        timestamps()
    }

    environment {
        SERVICE_NAME = 'do-product-service'
        IMAGE_REPO = 'joseptz/do-product-service'
        DOCKERFILE_PATH = 'Dockerfile'
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
                    if (env.BRANCH_NAME == 'develop') {
                        writeFile file: 'deploy-target.txt', text: "dev:${tags.versionTag}\n"
                    } else if (env.BRANCH_NAME?.startsWith('release/')) {
                        writeFile file: 'deploy-target.txt', text: "staging:${tags.versionTag}\n"
                    } else if (env.BRANCH_NAME == 'main') {
                        input message: 'Approve production deployment?', ok: 'Deploy'
                        writeFile file: 'deploy-target.txt', text: "prod:${tags.versionTag}\n"
                    } else {
                        writeFile file: 'deploy-target.txt', text: "build-only:${tags.versionTag}\n"
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
