# ---------------------------------------------------------------------------
# Terraform is the *deployer* in this pipeline. Jenkins builds and tags the
# image; Terraform reads its local state, notices the image ID changed, and
# replaces the running container with one based on the new image.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # Local state. Jenkins points this at a path under /var/jenkins_home via
  # `terraform init -backend-config=path=...` so the state survives both
  # workspace cleanups and Jenkins restarts.
  backend "local" {}
}

provider "docker" {
  host = var.docker_host
}

# Dedicated bridge network so the deployed app is isolated from the default
# bridge and from Jenkins' own network.
resource "docker_network" "app" {
  name = "${var.container_name}-net"
}

# The image is built by Jenkins on the host daemon *before* terraform runs, so
# we look it up rather than pulling it. Using the resolved image ID (a sha256)
# means a rebuilt image produces a new ID, which forces the container to be
# replaced on the next apply.
data "docker_image" "app" {
  name = var.image_name
}

resource "docker_container" "app" {
  name    = var.container_name
  image   = data.docker_image.app.id
  restart = "unless-stopped"

  ports {
    internal = 5000
    external = var.app_port
  }

  env = [
    "BUILD_NUMBER=${var.build_number}",
    "GIT_COMMIT=${var.git_commit}",
    "APP_NAME=${var.app_name}",
  ]

  networks_advanced {
    name = docker_network.app.name
  }

  healthcheck {
    test         = ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health').status==200 else 1)"]
    interval     = "15s"
    timeout      = "3s"
    retries      = 3
    start_period = "5s"
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }

  labels {
    label = "pipeline.build"
    value = var.build_number
  }

  labels {
    label = "pipeline.commit"
    value = var.git_commit
  }
}
