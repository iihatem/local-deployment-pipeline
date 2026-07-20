# Local Automated Deployment Pipeline

Git → **Jenkins** → **Docker build** → **Terraform apply** → running container, entirely on a local machine.

Pushing a commit to this repository causes Jenkins (polling every 2 minutes) to check out the
code, run the unit tests, build a new Docker image, and hand it to Terraform, which uses the
`kreuzwerker/docker` provider to replace the running application container with one based on the
new image.

```
  git push
     │
     ▼
  GitHub  ──(SCM polling, H/2 * * * *)──▶  Jenkins controller (container)
                                              │  docker build --target test    → pytest
                                              │  docker build --target runtime → pipeline-demo:<build>
                                              │  terraform init / plan / apply
                                              ▼
                                   host Docker daemon (via /var/run/docker.sock)
                                              │
                                              ▼
                                   pipeline-demo container → http://localhost:8090
```

## Repository layout

| Path                        | Role |
| --------------------------- | ---- |
| `app/`                      | Flask application + unit tests. Renders the build number and commit it was built from. |
| `Dockerfile`                | Multi-stage image for the app. `--target test` runs pytest; `--target runtime` is what ships. |
| `Jenkinsfile`               | The pipeline: checkout → tests → build → terraform init/plan/apply → smoke test. |
| `terraform/`                | The deployer. `kreuzwerker/docker` provider, local state, one network + one container. |
| `jenkins/Dockerfile`        | Jenkins controller image with the Docker CLI and Terraform baked in. |
| `jenkins/casc.yaml`         | Configuration as Code: admin user + the `pipeline-demo` job with its 2-minute SCM poll. |
| `jenkins/docker-compose.yml`| Runs the controller with the host Docker socket mounted. |

## Running it

```bash
# 1. Start the Jenkins controller (builds the image on first run).
docker compose -f jenkins/docker-compose.yml up -d --build

# 2. Open http://localhost:8081  (admin / admin123)
#    The "pipeline-demo" job already exists -- it is created from jenkins/casc.yaml.

# 3. Trigger it, or just push a commit and wait up to 2 minutes for the poll.

# 4. The deployed app:
open http://localhost:8090
```

Ports: Jenkins on **8081**, the application on **8090**.

## How the pieces connect

**Jenkins → Docker.** The controller has the Docker *client* installed but no daemon. The
compose file bind-mounts `/var/run/docker.sock` from the host, so every `docker build` and every
container Terraform creates is executed by the host's daemon. Images and containers therefore
show up in a plain `docker ps` on the host — Jenkins is orchestrating the machine's real Docker,
not a nested one. This is the "docker-outside-of-docker" pattern.

**Jenkins → Terraform.** Terraform is installed in the controller image, so `terraform apply`
runs directly on the controller with no agent hop.

**Terraform state.** State lives at `/var/jenkins_home/terraform-state/pipeline-demo.tfstate`,
passed to `terraform init` via `-backend-config`. Keeping it on the Jenkins volume rather than in
the job workspace means a workspace wipe can never orphan a running container — the next apply
still knows what it owns.

**How a new image actually reaches the container.** Terraform does not pull the image; Jenkins
has already built it on the host daemon. A `data "docker_image"` lookup resolves the tag to a
`sha256` image ID, and that ID is what the container resource consumes. A rebuilt image produces
a different ID, which forces Terraform to replace the container — so a code change becomes a
redeployment, while a no-op build plans zero changes.

**Automatic triggering.** `pollSCM('H/2 * * * *')` in the `Jenkinsfile`, mirrored in
`jenkins/casc.yaml` so polling is armed from the very first boot rather than only after an
initial manual build. Polling is used instead of a webhook because GitHub cannot reach a Jenkins
instance running on `localhost`.

## Verifying a deployment

```bash
curl -s localhost:8090/api/info            # build number + commit of the running container
docker ps --filter name=pipeline-demo      # container, image tag, health status
docker inspect pipeline-demo \
  --format '{{index .Config.Labels "pipeline.build"}} {{index .Config.Labels "pipeline.commit"}}'
```

## Notes on the local-lab shortcuts

A few choices here are deliberately convenient rather than production-grade, and are worth
naming:

- The Jenkins controller runs as **root** so it can use the bind-mounted Docker socket. On
  Docker Desktop for macOS there is no stable host `docker` group GID to add the `jenkins` user
  to. A shared environment should use a socket proxy or rootless Docker instead.
- Handing a container the Docker socket is effectively giving it root on the host. Fine for a
  local lab on your own machine; not something to copy into a shared CI server.
- The `admin` / `admin123` credentials in `jenkins/casc.yaml` are throwaway defaults for a
  Jenkins that only listens on localhost. They are overridable via the `JENKINS_ADMIN_ID` and
  `JENKINS_ADMIN_PASSWORD` environment variables, and should be for anything beyond this.
