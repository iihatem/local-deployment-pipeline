variable "docker_host" {
  description = "Docker daemon endpoint. Inside the Jenkins container this is the bind-mounted host socket."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "image_name" {
  description = "Tag of the image Jenkins just built, e.g. pipeline-demo:42"
  type        = string
  default     = "pipeline-demo:latest"
}

variable "container_name" {
  description = "Name of the deployed application container."
  type        = string
  default     = "pipeline-demo"
}

variable "app_port" {
  description = "Host port the application is published on."
  type        = number
  default     = 8090
}

variable "app_name" {
  description = "Display name rendered by the application."
  type        = string
  default     = "pipeline-demo"
}

variable "build_number" {
  description = "Jenkins build number, surfaced in the app and as a container label."
  type        = string
  default     = "dev"
}

variable "git_commit" {
  description = "Commit SHA that produced the image."
  type        = string
  default     = "unknown"
}
