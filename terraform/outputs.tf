output "container_name" {
  description = "Name of the container Terraform is managing."
  value       = docker_container.app.name
}

output "container_id" {
  description = "Docker container ID of the current deployment."
  value       = docker_container.app.id
}

output "image_id" {
  description = "Image ID the container was created from."
  value       = data.docker_image.app.id
}

output "app_url" {
  description = "Where the deployed application is reachable from the host."
  value       = "http://localhost:${var.app_port}"
}
