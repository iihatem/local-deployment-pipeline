# ---------------------------------------------------------------------------
# Jenkins controller image for the local pipeline.
#
# Stock jenkins/jenkins:lts has neither the Docker CLI nor Terraform, and this
# pipeline needs both: it builds images and runs `terraform apply` directly on
# the controller. The Docker *daemon* is not installed here -- the container
# talks to the host's daemon through the bind-mounted /var/run/docker.sock
# (docker-outside-of-docker), so images and containers live on the host.
# ---------------------------------------------------------------------------
FROM jenkins/jenkins:lts-jdk17

USER root

ARG TERRAFORM_VERSION=1.9.8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release unzip jq \
 && install -m 0755 -d /etc/apt/keyrings \
 # --- Docker CLI (client only; no daemon) ---------------------------------
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 # --- Terraform ------------------------------------------------------------
 && ARCH="$(dpkg --print-architecture)" \
 && curl -fsSL -o /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
 && unzip -q /tmp/terraform.zip -d /usr/local/bin \
 && chmod +x /usr/local/bin/terraform \
 && rm -f /tmp/terraform.zip \
 && rm -rf /var/lib/apt/lists/*

# Persistent home for Terraform state and the provider plugin cache, kept
# outside the job workspace so a workspace wipe never orphans real containers.
RUN mkdir -p /var/jenkins_home/terraform-state /var/jenkins_home/.terraform.d/plugin-cache

# Install plugins at build time so the controller boots ready to run.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt --latest true

# Configuration as Code: admin user, security realm, and the seed pipeline job.
COPY casc.yaml /var/jenkins_home/casc/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml

# Skip the setup wizard -- the admin account comes from casc.yaml instead.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.model.DownloadService.noSignatureCheck=true"
ENV TF_PLUGIN_CACHE_DIR=/var/jenkins_home/.terraform.d/plugin-cache

# NOTE: deliberately staying as root. On Docker Desktop for macOS the
# bind-mounted docker.sock is root-owned inside the container, and there is no
# stable host "docker" GID to add the jenkins user to. Running the controller
# as root is the pragmatic choice for a local lab; a shared environment should
# instead use a socket proxy or rootless Docker.
USER root
