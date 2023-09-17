resource "aws_ecr_repository" "repository" {
  name = "${var.app_name}/${var.environment}/${var.image_name_to_push}"
  force_delete = true
  lifecycle { ignore_changes = [tags] }
}

locals {
  ecr_image_url = aws_ecr_repository.repository.repository_url
}

resource "null_resource" "pull_and_push_docker_image" {
  triggers = { image_version = sha1("${var.image_name_to_pull}:${var.image_tag_to_pull}") }
  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --profile ${var.aws_profile}| docker login --username AWS --password-stdin ${local.ecr_image_url}
      docker pull ${var.image_name_to_pull}:${var.image_tag_to_pull}
      docker tag ${var.image_name_to_pull}:${var.image_tag_to_pull} ${local.ecr_image_url}:${var.image_tag_to_push}
      docker push ${local.ecr_image_url}:${var.image_tag_to_push}
    EOF
  }
}