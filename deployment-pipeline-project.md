# Local Automated Deployment Pipeline

## Objective

Build a local, automated deployment pipeline that integrates Git/GitHub, Jenkins, Terraform, and Docker, where Docker will serve as your local infrastructure.

## Requirements

- [ ] **Git/GitHub:** Hosts your application code, Dockerfile, Jenkinsfile, and Terraform `.tf` files.
- [ ] **Automated CI Trigger:** Jenkins must automatically execute upon repository updates (for example, use SCM Polling every 2 minutes, to bypass local webhook networking issues).
- [ ] **Jenkins (The Builder):** The pipeline checks out the repository, builds your application's Docker image, and executes `terraform apply`.
- [ ] **Terraform (The Deployer):** Using the `kreuzwerker/docker` provider, Terraform reads the local state and deploys your newly built image as a container.
- [ ] **Docker (The Runtime):** Serves as the environment hosting Jenkins and your final deployed application.

## Submission Guidelines

- **Groups:** You may work solo or in a group of up to around 10 students.
- **Deliverable:** Just to streamline the process, everyone should submit an individual report on Canvas (group members may submit the exact same file).
- **Report Contents:** The report doesn't need to be fancy; it just needs to provide enough information to verify your implementation. On that note, please include the following:
  1. First and last names of all group members.
  2. A link to the GitHub repository you used.
  3. A brief explanation of your local setup (e.g., how Jenkins connects to your local Docker daemon, etc.). Basically, include aspects that wouldn't be clear from the repository files alone for verifying you completed a checkbox.
  4. Provide verification screenshots showing a successful Jenkins build history triggered by a commit, and your final application running successfully in Docker.
