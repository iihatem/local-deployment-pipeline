// ---------------------------------------------------------------------------
// Local automated deployment pipeline.
//
//   SCM poll (every 2 min) -> checkout -> unit tests -> docker build
//   -> terraform init/plan/apply -> smoke test against the published port
//
// The controller runs the Docker CLI and Terraform against the *host* daemon
// through the bind-mounted docker.sock, so everything it creates is visible
// with a plain `docker ps` on the Mac.
// ---------------------------------------------------------------------------
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '25'))
        timeout(time: 20, unit: 'MINUTES')
    }

    // Requirement: Jenkins must trigger automatically on repository updates.
    // SCM polling avoids needing a public webhook endpoint for a local setup.
    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        IMAGE_NAME     = 'pipeline-demo'
        CONTAINER_NAME = 'pipeline-demo'
        APP_PORT       = '8090'

        TF_DIR         = 'terraform'
        TF_STATE_PATH  = '/var/jenkins_home/terraform-state/pipeline-demo.tfstate'
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA       = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.GIT_SHA_SHORT = env.GIT_SHA.take(7)
                    env.IMAGE_TAG     = "${env.BUILD_NUMBER}"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} · ${env.GIT_SHA_SHORT}"
                }
                sh 'echo "Building commit ${GIT_SHA} as ${IMAGE_NAME}:${IMAGE_TAG}"'
            }
        }

        stage('Verify toolchain') {
            steps {
                sh '''
                    set -eu
                    docker version --format 'docker client {{.Client.Version}} / daemon {{.Server.Version}}'
                    terraform version
                '''
            }
        }

        stage('Unit tests') {
            steps {
                // The test stage of the Dockerfile runs pytest against the same
                // dependency set that ships in the runtime image. A failing test
                // fails the build here, before anything is deployed.
                sh '''
                    set -eu
                    docker build --target test -t "${IMAGE_NAME}:test-${BUILD_NUMBER}" .
                '''
            }
            post {
                always {
                    sh 'docker image rm -f "${IMAGE_NAME}:test-${BUILD_NUMBER}" >/dev/null 2>&1 || true'
                }
            }
        }

        stage('Build image') {
            steps {
                sh '''
                    set -eu
                    docker build \
                        --target runtime \
                        --build-arg BUILD_NUMBER="${BUILD_NUMBER}" \
                        --build-arg GIT_COMMIT="${GIT_SHA}" \
                        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
                        -t "${IMAGE_NAME}:latest" \
                        .
                    docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format 'built image {{.Id}}'
                '''
            }
        }

        stage('Terraform init') {
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform init -input=false -reconfigure \
                            -backend-config="path=${TF_STATE_PATH}"
                        terraform fmt -check -recursive
                        terraform validate
                    '''
                }
            }
        }

        stage('Terraform plan') {
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform plan -input=false -out=tfplan \
                            -var="image_name=${IMAGE_NAME}:${IMAGE_TAG}" \
                            -var="container_name=${CONTAINER_NAME}" \
                            -var="app_port=${APP_PORT}" \
                            -var="build_number=${BUILD_NUMBER}" \
                            -var="git_commit=${GIT_SHA}"
                    '''
                }
            }
        }

        stage('Terraform apply') {
            steps {
                dir("${TF_DIR}") {
                    sh '''
                        set -eu
                        terraform apply -input=false -auto-approve tfplan
                        echo "--- terraform outputs ---"
                        terraform output
                    '''
                }
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    set -eu
                    echo "Waiting for ${CONTAINER_NAME} to answer on host port ${APP_PORT}..."
                    for attempt in $(seq 1 30); do
                        if curl -fsS "http://host.docker.internal:${APP_PORT}/health" >/dev/null 2>&1; then
                            echo "Health check passed on attempt ${attempt}."
                            curl -fsS "http://host.docker.internal:${APP_PORT}/api/info"
                            echo
                            exit 0
                        fi
                        sleep 2
                    done

                    echo "Health check never succeeded. Container state:"
                    docker ps -a --filter "name=${CONTAINER_NAME}"
                    docker logs --tail 50 "${CONTAINER_NAME}" || true
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            sh '''
                echo "=========================================================="
                echo " Deployed ${IMAGE_NAME}:${IMAGE_TAG} (commit ${GIT_SHA_SHORT})"
                echo " App is live at http://localhost:${APP_PORT}"
                echo "=========================================================="
                docker ps --filter "name=${CONTAINER_NAME}" \
                    --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
            '''
        }
        failure {
            sh '''
                echo "Build failed. Recent container state for diagnostics:"
                docker ps -a --filter "name=${CONTAINER_NAME}" || true
                docker logs --tail 100 "${CONTAINER_NAME}" 2>/dev/null || true
            '''
        }
        always {
            // Keep the local image cache from growing without bound, but never
            // remove the image the running container is based on.
            sh 'docker image prune -f --filter "until=72h" >/dev/null 2>&1 || true'
        }
    }
}
